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
        Task {
            await fetchUser()
        }
    }
    
    
    func signIn(withEmail email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            await fetchUser()
        } catch let error as NSError {
            DispatchQueue.main.async {
                self.authErrorMessage = self.handleSignInError(error)
            }
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

    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
        } catch {
            print("Failed to sign out with error \(error.localizedDescription)")
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
        guard let uid = Auth.auth().currentUser?.uid else { return }
        self.loadingComplete = false
        let userRef = Firestore.firestore().collection("users").document(uid)

        do {
            let snapshot = try await userRef.getDocument()

            // Decode user profile
            self.currentUser = try? snapshot.data(as: User.self)

            // Fetch books from `library`
            if let library = snapshot.data()?["library"] as? [String] {
                print("successfully pulled user library: \(library)")
                self.books = library
                print("In fetchUser library is:  \(library)")
                self.loadingComplete = true
            } else {
                print("error getting library")
            }
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
    
    func removeBook(at offsets: IndexSet) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let userRef = db.collection("users").document(userId)
        
        var updatedBooks = self.books
        let removedBooks = offsets.map { updatedBooks[$0] }
        
        let batch = db.batch()
        for book in removedBooks {
            let bookRef = db.collection("users").document(userId).collection("books").document(book)
            batch.deleteDocument(bookRef) // Delete book document
        }
        
        updatedBooks.remove(atOffsets: offsets)
        batch.updateData(["library": updatedBooks], forDocument: userRef) // Update Firestore
        
        batch.commit { error in
            if let error = error {
                print("Error updating book list: \(error.localizedDescription)")
            }
        }
        DispatchQueue.main.async {
            self.books = updatedBooks
        }
    }
    
    func addBook(_ bookTitle: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let userRef = db.collection("users").document(userId)
        let bookRef = userRef.collection("books").document(bookTitle)

        if self.books.contains(bookTitle) { return } // Avoid duplicates

        self.books.insert(bookTitle, at: 0) // Add to top of local list

        let batch = db.batch()
        batch.setData(["library": books], forDocument: userRef, merge: true)
        batch.setData(["title": bookTitle], forDocument: bookRef)
        batch.commit { error in
            if let error = error {
                print("Error adding book: \(error.localizedDescription)")
            }
        }
    }
    
    func moveBook(from source: IndexSet, to destination: Int) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let userRef = db.collection("users").document(userId)
        
        books.move(fromOffsets: source, toOffset: destination)
        
        userRef.updateData(["library": books]) { error in
            if let error = error {
                print("Error updating book order: \(error.localizedDescription)")
            }
        }
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
    
}
