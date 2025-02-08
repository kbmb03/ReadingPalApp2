//
//  AuthViewModel.swift
//  ReadingPal2
//
//  Created by Kaleb Davis on 1/29/25.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import CoreData

protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var loadingComplete: Bool = false
    @Published var authErrorMessage: String?
    @Published var books : [String]
    private let sessionsManager: SessionsManager
    private var db = Firestore.firestore()
    
    
    init(sessionManager: SessionsManager) {
        self.sessionsManager = sessionManager
        self.userSession = Auth.auth().currentUser
        self.books = []
        //self.sessionsManager.fetchSessionsFromCoreData()
        Task {
            await fetchUser()
            fetchBooksFromCoreData()
        }
    }
    
    
    func signIn(withEmail email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            
            let userRef = Firestore.firestore().collection("users").document(result.user.uid)
                    let snapshot = try await userRef.getDocument()
                    
                    if !snapshot.exists {
                        print("No user data found in Firestore. Blocking sign-in.")
                        
                        try Auth.auth().signOut() // Immediately sign the user out
                        self.userSession = nil
                        DispatchQueue.main.async {
                            self.authErrorMessage = "Account does not exist. Please sign up."
                        }
                        return
                    }
            clearCoreData()
            await fetchUser()
        } catch let error as NSError {
            DispatchQueue.main.async {
                self.authErrorMessage = self.handleSignInError(error)
            }
        }
    }
    
    func signOut() {
        Task {
            await syncWithFirestore()
    }
        clearCoreData()
        finishSignOut()
    }
    
    func finishSignOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
            print("Successfully signed out.")
        } catch {
            print("Sign-out error: \(error.localizedDescription)")
        }
    }
    
    func clearCoreData() {
        let context = PersistenceController.shared.container.viewContext
            
            // Delete all Books
            let bookFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Book")
            let bookDeleteRequest = NSBatchDeleteRequest(fetchRequest: bookFetchRequest)

            // Delete all Sessions
            let sessionFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Sessions")
            let sessionDeleteRequest = NSBatchDeleteRequest(fetchRequest: sessionFetchRequest)

        do {
            try context.execute(bookDeleteRequest)
            try context.execute(sessionDeleteRequest)
            try context.save()
            self.books = []
        } catch {
            print("error in deleting books")
        }
    }

    
    func createUser(withEmail email: String, password: String, fullname: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            let user = User(id: result.user.uid, fullName: fullname, email: email)
            var encodedUser = try Firestore.Encoder().encode(user)
            encodedUser["library"] = []
            try await Firestore.firestore().collection("users").document(user.id).setData(encodedUser)
            clearCoreData()
            await fetchUser()
        } catch let error as NSError {
            DispatchQueue.main.async {
                self.authErrorMessage = self.handleAuthError(error)
            }

        }
    }
    
    private func handleAuthError(_ error: NSError) -> String {
        switch error.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "This email is already in use. Try signing in or using a different email."
        case AuthErrorCode.invalidEmail.rawValue:
            return "Invalid email format. Please enter a valid email address."
        case AuthErrorCode.weakPassword.rawValue:
            return "Password is too short. Please use at least 6 characters."
        case AuthErrorCode.missingEmail.rawValue:
            return "Please enter an email address."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your connection and try again."
        default:
            return "Registration failed. Please try again later."
        }
    }

    func deleteAccount(password: String) async -> Bool {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            print("No authenticated user found.")
            return false
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        do {
            try await user.reauthenticate(with: credential)
            print("Re-authentication successful. Proceeding with deletion.")

            try await user.delete()
            print("Account successfully deleted.")

            self.userSession = nil
            self.currentUser = nil

            return true
        } catch {
            print("Failed to delete account: \(error.localizedDescription)")
            return false
        }
    }

    
    func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No user signed in. ProfileView will not show.")
            self.loadingComplete = true
            return
        }
        print("fetching User...")
        
        self.loadingComplete = false
        let userRef = Firestore.firestore().collection("users").document(uid)

        do {
            let snapshot = try await userRef.getDocument()

            if let userData = snapshot.data() {
                self.currentUser = User(
                    id: uid,
                    fullName: userData["fullName"] as? String ?? "Unknown",
                    email: userData["email"] as? String ?? "No Email"
                )
                print("snapshot.data()[library] = \(userData["library"] ?? "failure")")
                print("User fetched: \(self.currentUser?.fullName ?? "Unknown")")
                if let library = userData["library"] as? [String] {
                    
                    self.books = library
                    print("successfully set books to \(library)")
                } else {
                    self.books = []
                }
                
            } else {
                self.books = []
                print("No user data found in Firestore.")
            }
            
            self.loadingComplete = true
        } catch {
            print("Error fetching user data: \(error.localizedDescription)")
        }
    }


    func resetPassword(withEmail email: String) async -> Bool {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return true
        } catch let error as NSError {
            DispatchQueue.main.async {
                self.authErrorMessage = self.handlePasswordResetError(error)
            }
            return false
        }
    }
    //interact with BookListView
    
    func removeBook(at index: Int) {
        guard index < books.count else {
            print("Error: Index out of range")
            return
        }

        let title = books[index]

        // 🔹 Remove from books first (to keep UI in sync)
        DispatchQueue.main.async {
            self.books.remove(at: index)
            self.sessionsManager.sessions[title] = nil
            print("Updated books list after deletion: \(self.books)")
        }

        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", title)

        do {
            let booksToDelete = try context.fetch(fetchRequest)

            // 🔹 Remove from CoreData
            for book in booksToDelete {
                context.delete(book)
            }
            try context.save()
            print("Book deleted from CoreData: \(title)")

            // Add to deletionQueue for Firestore sync
            DeletionQueue.shared.addBookToDelete(title)
            print("📌 Book added to deletion queue: \(title)")

        } catch {
            print("❌ Error deleting book: \(error.localizedDescription)")
        }
    }



    
    func addBook(title: String) {
        guard !title.isEmpty else {
            print("Not adding empty book title")
            return
        }

        print("Adding book to CoreData: \(title)")
        let context = PersistenceController.shared.container.viewContext

        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: false)]
        
        let highestOrderIndex = (try? context.fetch(fetchRequest).first?.orderIndex ?? 0) ?? 0

        let newBook = Book(context: context)
        newBook.title = title
        newBook.lastUpdated = Date()
        newBook.orderIndex = highestOrderIndex + 1  // New books go to the top
        newBook.needsSync = true
        do {
            try context.save()
            print("Book successfully saved in CoreData: \(title)")
            DispatchQueue.main.async {
                self.books.insert(title, at: 0)
                print("Updated books list: \(self.books)")
                self.sessionsManager.sessions[title] = []
            }
        } catch {
            print("error saving book: \(error.localizedDescription)")
        }
    }

    
    func fetchBooksFromCoreData() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: false)]

        do {
            let fetchedBooks = try context.fetch(fetchRequest)
            let bookTitles = fetchedBooks.compactMap { $0.title }
            if !bookTitles.isEmpty {
                DispatchQueue.main.async {
                    self.books = bookTitles
                    print("updated books list: \(self.books)")
                }
            }
        } catch {
            print("Error fetching books: \(error.localizedDescription)")
        }
    }




    
    func moveBook(from source: IndexSet, to destination: Int) {
        self.books.move(fromOffsets: source, toOffset: destination)
    }

    
    //Handle errors

    private func handlePasswordResetError(_ error: NSError) -> String {
        switch error.code {
        case AuthErrorCode.invalidEmail.rawValue:
            return "Invalid email format. Please enter a valid email."
        case AuthErrorCode.userNotFound.rawValue:
            return "No account found with this email."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your connection."
        default:
            return "Failed to send reset email. Please try again."
        }
    }
    
    private func handleSignInError(_ error: NSError) -> String {
        switch error.code {
        case AuthErrorCode.wrongPassword.rawValue:
            return "Incorrect password. Please try again."
        case AuthErrorCode.userNotFound.rawValue:
            return "No account found with this email. Please check your email or sign up."
        case AuthErrorCode.invalidEmail.rawValue:
            return "Invalid email format. Please enter a valid email address."
        case AuthErrorCode.missingEmail.rawValue:
            return "Please enter an email address."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your connection and try again."
        default:
            return "Login failed. Please try again later."
        }
    }
    
    //Firestore Syncing:
    func syncWithFirestore() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let booksToDelete = DeletionQueue.shared.getBooksToDelete()
        print("going to delete following from firestore: \(booksToDelete)")
        // 🔹 Check for internet connection before syncing
        if !NetworkMonitor.shared.isConnected {
            print("No internet connection. Sync postponed.")
            return
        } else {
            print("Internet Connection good, syncing...")
        }

        let userRef = Firestore.firestore().collection("users").document(userId)
        print("🔄 Syncing data with Firestore...")

        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()

        do {
            let localBooks = try context.fetch(fetchRequest)
//            if localBooks.isEmpty && booksToDelete.isEmpty {
//                print("local books empty, returning")
//                return
//            }
            var latestBooks: [[String: Any]] = []

            for book in localBooks {
                let bookData: [String: Any] = [
                    "title": book.title ?? "",
                    "lastUpdated": book.lastUpdated ?? Date(),
                    "orderIndex": book.orderIndex
                ]
                latestBooks.append(bookData)

                let bookRef = userRef.collection("books").document(book.title ?? "")

                let firestoreBook = try await bookRef.getDocument()
                if let firestoreData = firestoreBook.data(),
                   let firestoreTimestamp = firestoreData["lastUpdated"] as? Timestamp {

                    if book.lastUpdated ?? Date() > firestoreTimestamp.dateValue() {
                        try await bookRef.setData(bookData, merge: true)
                        print("Updated Firestore book: \(String(describing: book.title))")
                    }
                } else {
                    try await bookRef.setData(bookData)
                    print("New book added to Firestore: \(String(describing: book.title))")
                }

                let fetchSessions: NSFetchRequest<Sessions> = Sessions.fetchRequest()
                fetchSessions.predicate = NSPredicate(format: "book.title == %@", book.title ?? "")
                let sessions = try context.fetch(fetchSessions)

                for session in sessions {
                    let sessionDoc = bookRef.collection("sessions").document(session.id ?? "")
                    let sessionData: [String: Any] = [
                        "name": session.name!,
                        "id": session.id!,
                        "date": session.date ?? Date(),
                        "lastUpdated": session.lastUpdated ?? Date(),
                        "pagesRead": session.pagesRead,
                        "summary": session.summary ?? ""
                    ]

                    let firestoreSession = try await sessionDoc.getDocument()
                    if let firestoreSessionData = firestoreSession.data(),
                       let firestoreTimestamp = firestoreSessionData["lastUpdated"] as? Timestamp {

                        if session.lastUpdated ?? Date() > firestoreTimestamp.dateValue() {
                            try await sessionDoc.setData(sessionData, merge: true)
                            print("Updated Firestore session: \(String(describing: session.id))")
                        }
                    } else {
                        try await sessionDoc.setData(sessionData)
                        print("New session added to Firestore: \(String(describing: session.id))")
                    }
                }

                book.needsSync = false
                for session in sessions {
                    session.needsSync = false
                }
            }
            try await userRef.setData(["library": self.books], merge: true)
            print("✅ Updated Firestore library field. Library set to: \(self.books)")
            try await processDeletionQueue(userRef: userRef)

            try context.save()
            fetchBooksFromCoreData()
            print("✅ Sync complete: Data merged with Firestore.")

        } catch {
            print("❌ Error syncing: \(error.localizedDescription)")
        }
    }

    
    func processDeletionQueue(userRef: DocumentReference) async {
        let context = PersistenceController.shared.container.viewContext

        for bookTitle in DeletionQueue.shared.getBooksToDelete() {
            let bookRef = userRef.collection("books").document(bookTitle)
            
            do {
                try await bookRef.delete()
                print("Deleted book from Firestore: \(bookTitle)")
            } catch {
                print("Error deleting book from Firestore: \(error.localizedDescription)")
            }
        }

        for sessionId in DeletionQueue.shared.getSessionsToDelete() {
            let fetchRequest: NSFetchRequest<Sessions> = Sessions.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", sessionId)

            if let sessionToDelete = try? context.fetch(fetchRequest).first, let bookTitle = sessionToDelete.book?.title {
                let sessionRef = userRef.collection("books").document(bookTitle).collection("sessions").document(sessionId)

                do {
                    try await sessionRef.delete()
                    print("Deleted session from Firestore: \(sessionId)")
                } catch {
                    print("Error deleting session from Firestore: \(error.localizedDescription)")
                }
            }
        }

        // Clear deletion queue after syncing & remove from local storage
        DeletionQueue.shared.clearQueue()
    }

    
    func scheduleAutoSync() {
        Timer.scheduledTimer(withTimeInterval: 604800, repeats: true) { _ in  // 🔹 7 days = 604800 seconds
            Task {
                if NetworkMonitor.shared.isConnected {
                    print("Auto-syncing after 7 days...")
                    await self.syncWithFirestore()
                } else {
                    print("Skipping auto-sync: No internet connection.")
                }
            }
        }
    }



    
}
