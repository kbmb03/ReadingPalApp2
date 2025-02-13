//
//  DeletionQueue.swift
//  ReadingPal2
//
//  Created by Kaleb Davis on 2/5/25.
//

import Foundation

class DeletionQueue {
    static let shared = DeletionQueue()

    private var booksToDelete: [String] = []
    private var sessionsToDelete: [String] = []

    private let booksKey = "BooksToDelete"
    private let sessionsKey = "SessionsToDelete"

    private init() {
        loadFromStorage() // Load any pending deletions when app starts
    }

    //  Add book to deletion queue & save
    func addBookToDelete(_ title: String) {
        if !booksToDelete.contains(title) {
            booksToDelete.append(title)
            saveToStorage()
        }
    }

    //  Add session to deletion queue & save
    func addSessionToDelete(_ sessionId: String) {
        if !sessionsToDelete.contains(sessionId) {
            sessionsToDelete.append(sessionId)
            saveToStorage()
        }
    }

    //  Retrieve books marked for deletion
    func getBooksToDelete() -> [String] {
        return booksToDelete
    }

    //  Retrieve sessions marked for deletion
    func getSessionsToDelete() -> [String] {
        return sessionsToDelete
    }

    //  Clear queue after syncing with Firestore
    func clearQueue() {
        print("DeletionQueue cleared")
        booksToDelete.removeAll()
        sessionsToDelete.removeAll()
        saveToStorage()
    }

    //  Save deletion queue to `UserDefaults`
    private func saveToStorage() {
        let defaults = UserDefaults.standard
        defaults.set(booksToDelete, forKey: booksKey)
        defaults.set(sessionsToDelete, forKey: sessionsKey)
    }

    //  Load deletion queue from `UserDefaults` on app launch
    private func loadFromStorage() {
        let defaults = UserDefaults.standard
        booksToDelete = defaults.stringArray(forKey: booksKey) ?? []
        sessionsToDelete = defaults.stringArray(forKey: sessionsKey) ?? []
    }
}
