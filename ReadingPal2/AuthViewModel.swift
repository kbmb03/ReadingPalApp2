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
            self.loadingComplete = true
            return
        }
        Task {
            await fetchUser()
        }
    }
    
    
    func signIn(withEmail email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            
            let userRef = Firestore.firestore().collection("users").document(result.user.uid)
                    let snapshot = try await userRef.getDocument()
                    
                    if !snapshot.exists {
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
        } catch {
            Logger.log("Sign-out error: \(error.localizedDescription)")
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
            Logger.log("error in deleting books: \(error.localizedDescription)")
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
            return false
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        do {
            try await user.reauthenticate(with: credential)

            try await user.delete()

            self.userSession = nil
            self.currentUser = nil

            return true
        } catch {
            return false
        }
    }

    
    func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.loadingComplete = true
            return
        }
        
        
        self.loadingComplete = false
        if let fullName = KeychainHelper.get("fullName"),
           let email = KeychainHelper.get("email") {
            self.currentUser = User(id: uid, fullName: fullName, email: email)
            
            self.books = UserDefaults.standard.stringArray(forKey: "library") ?? []
            for book in self.books {
                sessionsManager.fetchSessionsFromCoreData(for: book)
            }
            self.loadingComplete = true
            return
        } else {
            let userRef = Firestore.firestore().collection("users").document(uid)
            
            do {
                let snapshot = try await userRef.getDocument()
                
                if let userData = snapshot.data() {
                    let fullName = userData["fullName"] as? String ?? "Unknown"
                    let email = userData["email"] as? String ?? "No Email"
                    self.currentUser = User(id: uid, fullName: fullName, email: email)
                    
                    KeychainHelper.set(fullName, forKey: "fullName")
                    KeychainHelper.set(email, forKey: "email")
                    
                    if let library = userData["library"] as? [String] {
                        for book in library.reversed() {
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
                }
            } catch {
                Logger.log("Error fetching user data: \(error.localizedDescription)")
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

            // Now delete the Book
            let bookFetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
            bookFetchRequest.predicate = NSPredicate(format: "title == %@", title)

            let booksToDelete = try context.fetch(bookFetchRequest)
            for book in booksToDelete {
                context.delete(book)
            }

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
            Logger.log("Error deleting book or sessions: \(error.localizedDescription)")
        }
    }



    
    func addBook(title: String) {
        guard !title.isEmpty && !self.books.contains(title) else {
            return
        }

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
            DispatchQueue.main.async {
                self.books.insert(title, at: 0)
                UserDefaults.standard.set(self.books, forKey: "library")
                self.sessionsManager.sessions[title] = []
            }
        } catch {
            Logger.log("error saving book: \(error.localizedDescription)")
        }
    }

    
    func fetchBooksFromCoreData() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: false)]

        do {
            let fetchedBooks = try context.fetch(fetchRequest)
            let bookTitles = fetchedBooks.compactMap { $0.title }
            if !bookTitles.isEmpty && self.books == [] {
                DispatchQueue.main.async {
                    self.books = bookTitles
                }
            }
        } catch {
            Logger.log("error fetching book: \(error.localizedDescription)")
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
            return
        }
        
        if !NetworkMonitor.shared.isConnected {
            return
        }

        let userRef = Firestore.firestore().collection("users").document(userId)
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()

        do {
            // Fetch books from Core Data
            var localBooks = try context.fetch(fetchRequest)

            // Ensure `localBooks` is not empty by using `self.books`
            if localBooks.isEmpty {
                for bookTitle in self.books {
                    let newBook = Book(context: context)
                    newBook.title = bookTitle
                    newBook.lastUpdated = Date()
                    newBook.needsSync = true
                    localBooks.append(newBook)
                }
                try context.save()
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

                await sessionsManager.syncSessions(for: bookTitle)

                let firestoreBook = try await bookRef.getDocument()
                if let firestoreData = firestoreBook.data(),
                   let firestoreTimestamp = firestoreData["lastUpdated"] as? Timestamp {

                    if book.lastUpdated ?? Date() > firestoreTimestamp.dateValue() {
                        try await bookRef.setData(bookData, merge: true)
                    }
                } else {
                    try await bookRef.setData(bookData)
                }
            }

            try await userRef.setData(["library": self.books], merge: true)
            await processDeletionQueue(userRef: userRef)

            try context.save()
            fetchBooksFromCoreData()

        } catch {
            Logger.log("error syncing: \(error.localizedDescription)")
        }
    }




    
    func processDeletionQueue(userRef: DocumentReference) async {
        let context = PersistenceController.shared.container.viewContext

        for bookTitle in DeletionQueue.shared.getBooksToDelete() {
            let bookRef = userRef.collection("books").document(bookTitle)
            
            do {
                try await bookRef.delete()
            } catch {
                Logger.log("Error deleting book from Firestore: \(error.localizedDescription)")
            }
        }

        for sessionId in DeletionQueue.shared.getSessionsToDelete() {
            let fetchRequest: NSFetchRequest<Sessions> = Sessions.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", sessionId)

            if let sessionToDelete = try? context.fetch(fetchRequest).first, let bookTitle = sessionToDelete.book?.title {
                let sessionRef = userRef.collection("books").document(bookTitle).collection("sessions").document(sessionId)

                do {
                    try await sessionRef.delete()
                } catch {
                    Logger.log("error deleting session from Firestore: \(error.localizedDescription)")
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
                    await self.syncWithFirestore()
                } else {
                    Logger.log("Skipping auto-sync: No internet connection.")
                }
            }
        }
    }
}
