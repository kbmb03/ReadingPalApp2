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
import SwiftUI

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

        guard self.userSession != nil else {
            print("No user is signed in. Skipping fetchUser() on init.")
            self.loadingComplete = true
            return
        }
        Task {
            await fetchUser()
        }
    }
    
    
    func signIn(withEmail email: String, password: String) async throws {
        print("signIn called")
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            
            let userRef = Firestore.firestore().collection("users").document(result.user.uid)
                    let snapshot = try await userRef.getDocument()
                    
                    if !snapshot.exists {
                        print("No user data found in Firestore. Blocking sign-in.")
                        
                        try Auth.auth().signOut()
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
        clearCoreData()
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
        KeychainHelper.delete("fullName")
        KeychainHelper.delete("email")
        UserDefaults.standard.removeObject(forKey: "library")
        UserDefaults.standard.removeObject(forKey: "sessionCounters")
        UserDefaults.standard.synchronize()
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
        print("CoreData deleted")
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
        print("FETCH USER CALLED!!!!!")
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No user signed in. ProfileView will not show.")
            self.loadingComplete = true
            return
        }
        
        
        self.loadingComplete = false
        if let fullName = KeychainHelper.get("fullName"),
           let email = KeychainHelper.get("email") {
            self.currentUser = User(id: uid, fullName: fullName, email: email)
            print("Loaded user info for \(fullName) from keychain")
            
            self.books = UserDefaults.standard.stringArray(forKey: "library") ?? []
            for book in self.books {
                sessionsManager.fetchSessionsFromCoreData(for: book)
            }
            self.loadingComplete = true
            return
        } else {
            print("fetching user down here")
            let userRef = Firestore.firestore().collection("users").document(uid)
            
            do {
                let snapshot = try await userRef.getDocument()
                
                if let userData = snapshot.data() {
                    let fullName = userData["fullName"] as? String ?? "Unknown"
                    let email = userData["email"] as? String ?? "No Email"
                    self.currentUser = User(id: uid, fullName: fullName, email: email)
                    
                    KeychainHelper.set(fullName, forKey: "fullName")
                    KeychainHelper.set(email, forKey: "email")
                    print("Saved user data to Keychain.")
                    
                    if let library = userData["library"] as? [String] {
                        for book in library.reversed() {
                            print("looping though \(book)")
                            self.addBook(title: book)
                            await sessionsManager.fetchAndStoreSessions(for: book)
                        }
                        UserDefaults.standard.set(library, forKey: "library")
                    } else {
                        self.books = []
                        UserDefaults.standard.removeObject(forKey: "library")
                    }
                } else {
                    self.books = []
                    print("No user data found in firestore")
                }
            } catch {
                print("Error fetching user data: \(error.localizedDescription)")
            }
        }
        self.loadingComplete = true
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
        let context = PersistenceController.shared.container.viewContext

        // Delete Sessions first
        let sessionFetchRequest: NSFetchRequest<Sessions> = Sessions.fetchRequest()
        sessionFetchRequest.predicate = NSPredicate(format: "book.title == %@", title)

        do {
            let sessionsToDelete = try context.fetch(sessionFetchRequest)
            for session in sessionsToDelete {
                if let sessionID = session.id {
                    DeletionQueue.shared.addSessionToDelete(sessionID)
                }
                context.delete(session)
            }
            print("Deleted all sessions for book: \(title)")

            // Now delete the Book
            let bookFetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
            bookFetchRequest.predicate = NSPredicate(format: "title == %@", title)

            let booksToDelete = try context.fetch(bookFetchRequest)
            for book in booksToDelete {
                context.delete(book)
            }
            print("Book deleted from Core Data: \(title)")

            try context.save()  // Save all deletions at once

            // Add book to deletion queue for Firestore sync
            DeletionQueue.shared.addBookToDelete(title)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    self.books.remove(at: index)
                    UserDefaults.standard.set(self.books, forKey: "library")
                    self.sessionsManager.sessions[title] = nil
                }
            }

        } catch {
            print("Error deleting book or sessions: \(error.localizedDescription)")
        }
    }



    
    func addBook(title: String) {
        guard !title.isEmpty && !self.books.contains(title) else {
            print("Not adding empty/existing book title")
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
                UserDefaults.standard.set(self.books, forKey: "library")
                print("Updated books list in addBook: \(self.books)")
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
            for title in bookTitles {
                print("titles in loop are: \(title)")
            }
            if !bookTitles.isEmpty && self.books == [] {
                DispatchQueue.main.async {
                    self.books = bookTitles
                    print("updated books list in fetchBookFromCoreData: \(self.books)")
                }
            }
        } catch {
            print("Error fetching books: \(error.localizedDescription)")
        }
    }
    

    func moveBook(from source: IndexSet, to destination: Int) {
        self.books.move(fromOffsets: source, toOffset: destination)
        UserDefaults.standard.set(self.books, forKey: "library")
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
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No user ID found, aborting sync.")
            return
        }

        let booksToDelete = DeletionQueue.shared.getBooksToDelete()
        
        if !NetworkMonitor.shared.isConnected {
            print("No internet connection. Sync postponed.")
            return
        }

        print("🔄 Syncing data with Firestore...")

        let userRef = Firestore.firestore().collection("users").document(userId)
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()

        do {
            // Fetch books from Core Data
            var localBooks = try context.fetch(fetchRequest)

            // 🔹 Ensure `localBooks` is not empty by using `self.books`
            if localBooks.isEmpty {
                print("No books found in Core Data. Using `self.books` instead.")
                for bookTitle in self.books {
                    let newBook = Book(context: context)
                    newBook.title = bookTitle
                    newBook.lastUpdated = Date()
                    newBook.needsSync = true
                    localBooks.append(newBook)
                }
                try context.save()
                print("✅ Created missing books in Core Data from `self.books`.")
            }

            var latestBooks: [[String: Any]] = []

            for book in localBooks {
                let bookTitle = book.title ?? ""
                let bookData: [String: Any] = [
                    "title": bookTitle,
                    "lastUpdated": book.lastUpdated ?? Date(),
                    "orderIndex": book.orderIndex
                ]
                latestBooks.append(bookData)

                let bookRef = userRef.collection("books").document(bookTitle)

                print("Calling syncSessions for book: \(bookTitle)")
                await sessionsManager.syncSessions(for: bookTitle)

                let firestoreBook = try await bookRef.getDocument()
                if let firestoreData = firestoreBook.data(),
                   let firestoreTimestamp = firestoreData["lastUpdated"] as? Timestamp {

                    if book.lastUpdated ?? Date() > firestoreTimestamp.dateValue() {
                        try await bookRef.setData(bookData, merge: true)
                        print("Updated Firestore book: \(bookTitle)")
                    }
                } else {
                    try await bookRef.setData(bookData)
                    print("New book added to Firestore: \(bookTitle)")
                }
            }

            try await userRef.setData(["library": self.books], merge: true)
            await processDeletionQueue(userRef: userRef)

            try context.save()
            fetchBooksFromCoreData()
            print("Sync complete: Data merged with Firestore.")

        } catch {
            print("Error syncing: \(error.localizedDescription)")
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
        Timer.scheduledTimer(withTimeInterval: 604800, repeats: true) { _ in
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
