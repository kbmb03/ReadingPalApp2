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
import CoreData

@MainActor
class SessionsManager: ObservableObject {
    @Published var books: [String] = []
    @Published var sessions: [String: [[String: Any]]] = [:] // Sessions keyed by book title
    @Published var finishedBooks: [String : Date] = [:]
    private var db = Firestore.firestore()

    
    
    func saveFinishedBooks() {
        
    }
    
    func fetchSessionsFromCoreData(for bookTitle: String) {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Sessions> = Sessions.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "book.title == %@", bookTitle)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let fetchedSessions = try context.fetch(fetchRequest)
            let sessionData = fetchedSessions.map { session in
                return [
                    "id": session.id ?? UUID().uuidString,
                    "date": session.date ?? Date(),
                    "lastUpdated": session.lastUpdated ?? Date(),
                    "pagesRead": session.pagesRead,
                    "summary": session.summary ?? "",
                    "needsSync": session.needsSync  // Track sync status
                ]
            }

            DispatchQueue.main.async {
                self.sessions[bookTitle] = sessionData
                print("Sessions updated from Core Data for \(bookTitle): \(sessionData.count) sessions")
            }
        } catch {
            print("Error fetching sessions from Core Data: \(error.localizedDescription)")
        }
    }

    

    // Add a session to a book
    func addSession(to bookTitle: String, sessionData: [String: Any]) {
        let context = PersistenceController.shared.container.viewContext

        // 🔹 Fetch or create the book
        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", bookTitle)

        let book: Book
        if let existingBook = try? context.fetch(fetchRequest).first {
            book = existingBook
        } else {
            book = Book(context: context)
            book.title = bookTitle
            book.lastUpdated = Date()
            book.needsSync = true  // New books need syncing
        }

        // Create the new session
        let newSession = Sessions(context: context)
        newSession.id = UUID().uuidString
        newSession.date = Date()
        newSession.lastUpdated = Date()
        newSession.pagesRead = Int64(sessionData["pagesRead"] as? Int ?? 0)
        newSession.summary = sessionData["summary"] as? String ?? ""
        newSession.needsSync = true  // New sessions need syncing
        newSession.book = book

        // 🔹 Save changes to CoreData
        do {
            try context.save()
            
            DispatchQueue.main.async {
                if self.sessions[bookTitle] == nil {
                    self.sessions[bookTitle] = []
                }
                self.sessions[bookTitle]?.append(sessionData)
                print("Updated sessionsManager.sessions for \(bookTitle)")
            }
            
            print("Session saved to CoreData with needsSync = true")
        } catch {
            print("Error saving session: \(error.localizedDescription)")
        }
    }


    
    func deleteSession(bookTitle: String, sessionId: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let sessionRef = db.collection("users").document(userId)
            .collection("books").document(bookTitle)
            .collection("sessions").document(sessionId)

        sessionRef.delete { error in
            if let error = error {
                print("Error deleting session: \(error.localizedDescription)")
            } else {
                print("Session deleted successfully for book: \(bookTitle)")

                DispatchQueue.main.async {
                    // Remove the session from local storage
                    self.sessions[bookTitle]?.removeAll { session in
                        session["id"] as? String == sessionId
                    }
                }
            }
        }
    }


    // Update sessions for a book
    func updateSessions(for bookTitle: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let sessionsRef = db.collection("users").document(userId)
            .collection("books").document(bookTitle)
            .collection("sessions")

        // ✅ Fetch ALL sessions (even if they don't have "orderIndex")
        sessionsRef.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching sessions: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("⚠️ No sessions found for \(bookTitle)")
                return
            }

            print("📌 Fetched \(documents.count) sessions for \(bookTitle)")

            var fetchedSessions = documents.compactMap { doc -> [String: Any]? in
                var data = doc.data()
                data["id"] = doc.documentID

                // ✅ Convert Timestamp to Date
                if let timestamp = data["date"] as? Timestamp {
                    data["date"] = timestamp.dateValue()
                }

                // ✅ Ensure "orderIndex" exists (set default if missing)
                if data["orderIndex"] == nil {
                    data["orderIndex"] = Int.max  // Push these to the end
                }

                return data
            }

            // ✅ Now Sort by Order Index
            fetchedSessions.sort { ($0["orderIndex"] as? Int ?? Int.max) < ($1["orderIndex"] as? Int ?? Int.max) }

            DispatchQueue.main.async {
                self.sessions[bookTitle] = fetchedSessions
                print("✅ Final sorted session count: \(fetchedSessions.count) for \(bookTitle)")
            }
        }
    }

    
    func updateSessionOrder(for bookTitle: String, newOrder: [[String: Any]]) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let sessionsRef = db.collection("users").document(userId)
            .collection("books").document(bookTitle)
            .collection("sessions")

        let batch = db.batch()
        
        for (index, session) in newOrder.enumerated() {
            guard let sessionId = session["id"] as? String else { continue }
            let sessionDoc = sessionsRef.document(sessionId)

            // 🔹 Store new position index in Firestore
            batch.updateData(["orderIndex": index], forDocument: sessionDoc)
        }

        batch.commit { error in
            if let error = error {
                print("❌ Error saving session order: \(error.localizedDescription)")
            } else {
                print("✅ Session order updated for \(bookTitle)")
            }
        }
        
        DispatchQueue.main.async {
            self.sessions[bookTitle] = newOrder
        }
    }

    
    func updateSessionSummary(bookTitle: String, sessionId: String, newSummary: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let sessionRef = db.collection("users").document(userId)
            .collection("books").document(bookTitle)
            .collection("sessions").document(sessionId)

        sessionRef.updateData(["summary": newSummary]) { error in
            if let error = error {
                print("❌ Error updating session summary: \(error.localizedDescription)")
            } else {
                print("✅ Summary updated successfully for session \(sessionId)")
                
                // Update local state
                DispatchQueue.main.async {
                    if let index = self.sessions[bookTitle]?.firstIndex(where: { $0["id"] as? String == sessionId }) {
                        self.sessions[bookTitle]?[index]["summary"] = newSummary
                    }
                }
            }
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
