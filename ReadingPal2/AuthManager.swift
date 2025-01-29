//
//  AuthManager.swift
//  ReadingPal2
//
//  Created by Kaleb Davis on 1/28/25.
//

//import Foundation
//import FirebaseAuth
//
//class AuthManager: ObservableObject {
//    @Published var user: User? // Firebase Auth User
//
//    init() {
//        // Monitor authentication state changes
//        Auth.auth().addStateDidChangeListener { _, user in
//            self.user = user
//        }
//    }
//
//    func signIn(email: String, password: String, completion: @escaping (Error?) -> Void) {
//        Auth.auth().signIn(withEmail: email, password: password) { _, error in
//            completion(error)
//        }
//    }
//
//    func signUp(email: String, password: String, completion: @escaping (Error?) -> Void) {
//        Auth.auth().createUser(withEmail: email, password: password) { _, error in
//            completion(error)
//        }
//    }
//
//    func signOut(completion: @escaping (Error?) -> Void) {
//        do {
//            try Auth.auth().signOut()
//            completion(nil)
//        } catch let error {
//            completion(error)
//        }
//    }
//
//    func signInAnonymously(completion: @escaping (Error?) -> Void) {
//        Auth.auth().signInAnonymously { _, error in
//            completion(error)
//        }
//    }
// }
