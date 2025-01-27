//
//  SessionManager.swift
//  ReadingPal
//
//  Created by Kaleb Davis on 1/15/25.
//

import Foundation
import SwiftUI
import UserNotifications

class SessionsManager: ObservableObject {
    @Published var books: [String] = []
    @Published var sessions: [String: [[String: Any]]] = [:] // Sessions keyed by book title
    @Published var finishedBooks: [String : Date] = [:]

    init() {
        loadBooks()
        loadFinishedBooks()
    }

    // Load books and their sessions
    func loadBooks() {
        books = UserDefaults.standard.stringArray(forKey: "books") ?? []
        for book in books {
            var bookSessions = UserDefaults.standard.array(forKey: "\(book)-sessions") as? [[String: Any]] ?? []
            // Ensure all sessions have an index
            for i in 0..<bookSessions.count {
                if bookSessions[i]["index"] == nil {
                    bookSessions[i]["index"] = i + 1
                }
            }
            sessions[book] = bookSessions
        }
    }
    
    func loadFinishedBooks() {
        if let data = UserDefaults.standard.data(forKey: "finishedBooks") {
            let decoder = JSONDecoder()
            if let savedFinishedBooks = try? decoder.decode([String: Date].self, from: data) {
                finishedBooks = savedFinishedBooks
            }
        }
    }

    // Save books
    func saveBooks() {
        UserDefaults.standard.set(books, forKey: "books")
        for (book, bookSessions) in sessions {
            UserDefaults.standard.set(bookSessions, forKey: "\(book)-sessions")
        }
    }
    
    func saveFinishedBooks() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(finishedBooks) {
            UserDefaults.standard.set(data, forKey: "finishedBooks")
        }
    }

    // Add a new book
    func addBook(_ bookTitle: String) {
        guard !bookTitle.isEmpty else { return }
        books.insert(bookTitle, at: 0)
        sessions[bookTitle] = []
        saveBooks()
    }

    // Remove a book and its sessions
    func removeBook(at offsets: IndexSet) {
        for index in offsets {
            let book = books[index]
            books.remove(at: index)
            sessions[book] = nil
            UserDefaults.standard.removeObject(forKey: "\(book)-sessions")
        }
        saveBooks()
    }
    
    func moveBook(from source: IndexSet, to destination: Int) {
        books.move(fromOffsets: source, toOffset: destination)
        saveBooks() // Ensure the updated order is saved
    }

    // Add a session to a book
    func addSession(to bookTitle: String, session: [String: Any]) {
        var newSession = session
        let currentSessions = sessions[bookTitle] ?? []
        newSession["index"] = currentSessions.count + 1 // Assign index based on creation order
        sessions[bookTitle]?.append(newSession)
        saveBooks()
    }


    // Update sessions for a book
    func updateSessions(for bookTitle: String, with updatedSessions: [[String: Any]]) {
        sessions[bookTitle] = updatedSessions
        saveBooks() // Ensure UserDefaults is updated
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
    
    //Func for notifications
//    func unfinishedBooksNotifyUser() -> [String] {
//        let date = Date()
//        var booksToNotify: [String] = []
//
//        for (bookTitle, finishedDate) in finishedBooks {
//            if let lastSession = sessions[bookTitle]?.last?["date"] as? Date {
//                if let daysSinceLastRead = Calendar.current.dateComponents([.day], from: lastSession, to: date).day {
//                    if daysSinceLastRead > -2 {
//                        print(bookTitle)
//                        booksToNotify.append(bookTitle)
//                    }
//                }
//            }
//        }
//        return booksToNotify
//    }
//    func scheduleNotificationsForUnfinishedBooks() {
//        let booksToNotify = unfinishedBooksNotifyUser()
//        
//        for book in booksToNotify {
//            let content = UNMutableNotificationContent()
//            content.title = "Keep Reading!"
//            content.body = "You haven't read '\(book)' in a while. Jump back into it!"
//            content.sound = .default
//            
//            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
//
//            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
//
//            UNUserNotificationCenter.current().add(request) { error in
//                if let error = error {
//                    print("Error scheduling notification: \(error.localizedDescription)")
//                }
//            }
//        }
//    }
}
