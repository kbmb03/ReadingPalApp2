//
//  SessionManager.swift
//  ReadingPal
//
//  Created by Kaleb Davis on 1/15/25.
//

import Foundation
import SwiftUI
import UserNotifications
import Firebase
import FirebaseAuth

@MainActor
class SessionsManager: ObservableObject {
    @Published var books: [String] = []
    @Published var sessions: [String: [[String: Any]]] = [:] // Sessions keyed by book title
    @Published var finishedBooks: [String : Date] = [:]
    private var db = Firestore.firestore()
    
    

    func loadFinishedBooks() {
        
    }
    
    func bookList() -> [String] {
        print("returning from bookList(): \(self.books)")
        return self.books
    }
    
    // Save books
    func saveBooks() {
    }
    
    func saveFinishedBooks() {
        
    }
    
    // Add a new book
    func addBook(_ bookTitle: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let userRef = db.collection("users").document(userId)
        let bookRef = userRef.collection("books").document(bookTitle)

        if books.contains(bookTitle) { return } // Avoid duplicates

        books.insert(bookTitle, at: 0) // Add to top of local list

        let batch = db.batch()
        batch.setData(["library": books], forDocument: userRef, merge: true)
        batch.setData(["title": bookTitle], forDocument: bookRef)
        batch.commit { error in
            if let error = error {
                print("Error adding book: \(error.localizedDescription)")
            }
        }
    }
    
    func updateBooks(_ newBooks: [String]) {
        print(" books before update are: \(self.books)")
        self.books = newBooks
        print("new updated books are: \(self.books)")
    }

    // Remove a book and its sessions
    func removeBook(at offsets: IndexSet) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let userRef = db.collection("users").document(userId)
        
        var updatedBooks = books
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
    
    func moveBook(from source: IndexSet, to destination: Int) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let userRef = db.collection("users").document(userId)
        
        books.move(fromOffsets: source, toOffset: destination)
        
        userRef.updateData(["library": books]) { error in
            if let error = error {
                print("Error updating book order: \(error.localizedDescription)")
            }
        }
        DispatchQueue.main.async {
            self.books = self.books
        }
    }


    // Add a session to a book
    func addSession(to bookTitle: String, session: [String: Any]) {

    }


    // Update sessions for a book
    func updateSessions(for bookTitle: String, with updatedSessions: [[String: Any]]) {

    }
    
    func getData() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let userRef = db.collection("users").document(userId)

        do {
            let snapshot = try await userRef.getDocument()
            if let library = snapshot.data()?["library"] as? [String] {
                print("🔄 Refreshing books from Firestore: \(library)")
                await updateBooks(library)
            } else {
                print("⚠️ No books found, setting to empty list.")
                await updateBooks([])
            }
        } catch {
            print("❌ Error fetching books: \(error.localizedDescription)")
        }
    }
    
    
    // Functions to assist with book details page
    func earliestSessionDate(for bookTitle : String) -> Date? {
        guard let sessions = sessions[bookTitle] else {
            return nil
        }
        return sessions.compactMap { $0["date"] as? Date }.min()
}
    func totalPagesRead(for bookTitle : String) -> Int {
        guard let sessions = sessions[bookTitle] else {
            return 0
        }
        return sessions.compactMap { $0["pagesRead"] as? Int }.reduce(0, +)
    }
    
    func totalReadingDuration(for bookTitle: String) -> String {
        guard let sessions = sessions[bookTitle] else { return "0 hours, 0 minutes" }
        let totalDuration = sessions.compactMap { session in
          guard let durationString = session["duration"] as? String else { return nil }
          return parseDuration(from: durationString)
      }.reduce(0, +)

        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        return hours == 0 ? "\(minutes) minutes" : "\(hours) hours, \(minutes) minutes"
      }

      private func parseDuration(from durationString: String) -> TimeInterval? {
          let components = durationString.split(separator: ":").compactMap { Double($0) }
          guard components.count == 2 else { return nil }
          let minutes = components[0]
          let seconds = components[1]
          return (minutes * 60) + seconds
      }
    
    func numberOfSessions(for bookTitle: String) -> Int {
        return sessions[bookTitle]?.count ?? 0
    }
    
    func markBookAsFinished(for bookTitle: String) {
        finishedBooks[bookTitle] = Date()
        saveFinishedBooks()
    }
    
    func finishedDate(for bookTitle: String) -> Date? {
        return finishedBooks[bookTitle]
    }
    
    func reOpenBook(for bookTitle: String) {
        finishedBooks.removeValue(forKey: bookTitle)
        saveFinishedBooks()
    }
    
    func isBookFinished(for bookTitle: String) -> Bool {
        return finishedBooks[bookTitle] != nil
    }
    
    func setFinishedDate(for bookTitle: String, to selectedDate: Date) {
        finishedBooks[bookTitle] = selectedDate
        saveFinishedBooks()
    }
    
}
