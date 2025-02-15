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

    
    func fetchSessionsFromCoreData(for bookTitle: String) {
        print("Fetching sessions from Core Data for \(bookTitle)")
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Sessions> = Sessions.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "book.title == %@", bookTitle)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let fetchedSessions = try context.fetch(fetchRequest)

            let sessionData = fetchedSessions.compactMap { session -> [String: Any]? in
                guard let sessionId = session.id else {
                    print("Warning: Found session without an ID in Core Data. Skipping...")
                    return nil
                }
                return [
                    "id": sessionId,
                    "date": session.date ?? Date(),
                    "lastUpdated": session.lastUpdated ?? Date(),
                    "pagesRead": session.pagesRead,
                    "summary": session.summary ?? "",
                    "name": session.name ?? "Session",
                    "needsSync": session.needsSync
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

        let fetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "title == %@", bookTitle)

        let book: Book
        if let existingBook = try? context.fetch(fetchRequest).first {
            book = existingBook
        } else {
            book = Book(context: context)
            book.title = bookTitle
            book.lastUpdated = Date()
            book.needsSync = true
        }
        
        let sessionId = sessionData["id"] as? String ?? UUID().uuidString
        print("📌 Assigned session ID: \(sessionId)")

        // Create a new session every time
        let newSession = Sessions(context: context)
        newSession.id = sessionId // Ensure unique session ID
        print("New session created with ID: \(newSession.id ?? "Unknown")")
        newSession.date = Date()
        newSession.lastUpdated = Date()
        newSession.pagesRead = Int64(sessionData["pagesRead"] as? Int ?? 0)
        newSession.summary = sessionData["summary"] as? String ?? ""
        newSession.needsSync = true
        newSession.book = book  // Link session to book
        newSession.name = sessionData["name"] as? String
        
        let sessionFetch : NSFetchRequest<Sessions> = Sessions.fetchRequest()
        sessionFetch.predicate = NSPredicate(format: "book.title == %@", bookTitle)

        do {
            try context.save()
            print("Session successfully saved to CoreData for \(bookTitle)")

            DispatchQueue.main.async {
                if self.sessions[bookTitle] == nil {
                    self.sessions[bookTitle] = []
                }
                self.sessions[bookTitle]?.insert(sessionData, at: 0)
                print("Updated sessionsManager.sessions for \(bookTitle), added at the top.")
            }
        } catch {
            print("Error saving session: \(error.localizedDescription)")
        }
    }

    
    func fetchAndStoreSessions(for bookTitle: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let sessionsRef = db.collection("users").document(userId)
            .collection("books").document(bookTitle)
            .collection("sessions")

        do {
            let snapshot = try await sessionsRef.getDocuments()
            let context = PersistenceController.shared.container.viewContext
            var fetchedSessions: [[String: Any]] = []

            for doc in snapshot.documents {
                var data = doc.data()
                let sessionID = doc.documentID
                data["id"] = sessionID

                if let timestamp = data["date"] as? Timestamp {
                    data["date"] = timestamp.dateValue()
                }
                if let lastUpdated = data["lastUpdated"] as? Timestamp {
                    data["lastUpdated"] = lastUpdated.dateValue()
                }

                fetchedSessions.append(data)

                let fetchRequest: NSFetchRequest<Sessions> = Sessions.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", sessionID)

                let existingSession = try? context.fetch(fetchRequest).first
                let session: Sessions

                if let existing = existingSession {
                    session = existing
                } else {
                    session = Sessions(context: context)
                    session.id = sessionID
                }

                let bookFetch: NSFetchRequest<Book> = Book.fetchRequest()
                bookFetch.predicate = NSPredicate(format: "title == %@", bookTitle)
                if let book = try? context.fetch(bookFetch).first {
                    session.book = book
                }

                session.date = data["date"] as? Date ?? Date()
                session.lastUpdated = data["lastUpdated"] as? Date ?? Date()
                session.pagesRead = Int64(data["pagesRead"] as? Int ?? 0)
                session.summary = data["summary"] as? String ?? ""
                session.name = data["name"] as? String ?? "Unnamed Session"
                session.needsSync = false

                print("Saving session to Core Data: \(session.name ?? "Unknown")")
            }

            try context.save()
            self.sessions[bookTitle] = fetchedSessions
            print("All sessions saved to Core Data for \(bookTitle)")

            DispatchQueue.main.async {
                self.sessions[bookTitle] = fetchedSessions
                print("Updated `sessionsManager.sessions` for \(bookTitle)")
            }
        } catch {
            print("Error fetching or storing sessions: \(error.localizedDescription)")
        }
    }



    // Update sessions for a book
    func updateSessions(for bookTitle: String) {
        
    }

    
    // Functions to assist with book details page///
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
    
    func syncSessions(for bookTitle: String) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No user ID found, skipping session sync.")
            return
        }
        let bookRef = db.collection("users").document(userId).collection("books").document(bookTitle)
        let sessionsRef = bookRef.collection("sessions")
        
        let context = PersistenceController.shared.container.viewContext
        let sessionFetchRequest: NSFetchRequest<Sessions> = Sessions.fetchRequest()
        sessionFetchRequest.predicate = NSPredicate(format: "book.title == %@", bookTitle)

        do {
            let firestoreSnapshot = try await sessionsRef.getDocuments()

            var firestoreSessions: [String: [String: Any]] = [:]

            for document in firestoreSnapshot.documents {
                var sessionData = document.data()
                let sessionID = document.documentID
                sessionData["id"] = sessionID
                
                if let timestamp = sessionData["date"] as? Timestamp {
                    sessionData["date"] = timestamp.dateValue()
                }
                if let lastUpdated = sessionData["lastUpdated"] as? Timestamp {
                    sessionData["lastUpdated"] = lastUpdated.dateValue()
                }
                
                firestoreSessions[sessionID] = sessionData
            }

            let localSessions = try context.fetch(sessionFetchRequest)
            var localSessionMap: [String: Sessions] = [:]

            for session in localSessions {
                if let sessionID = session.id {
                    localSessionMap[sessionID] = session
                }
            }

            for (sessionID, firestoreData) in firestoreSessions {
                let firestoreLastUpdated = firestoreData["lastUpdated"] as? Date ?? Date()

                if let localSession = localSessionMap[sessionID] {
                    if localSession.lastUpdated ?? Date() < firestoreLastUpdated {
                        localSession.date = firestoreData["date"] as? Date ?? Date()
                        localSession.lastUpdated = firestoreLastUpdated
                        localSession.pagesRead = Int64(firestoreData["pagesRead"] as? Int ?? 0)
                        localSession.summary = firestoreData["summary"] as? String ?? ""
                        localSession.name = firestoreData["name"] as? String ?? "Unnamed Session"
                        localSession.needsSync = false
                        print("Updated local session \(sessionID) from Firestore")
                    }
                } else {
                    let newSession = Sessions(context: context)
                    newSession.id = sessionID
                    newSession.date = firestoreData["date"] as? Date ?? Date()
                    newSession.lastUpdated = firestoreLastUpdated
                    newSession.pagesRead = Int64(firestoreData["pagesRead"] as? Int ?? 0)
                    newSession.summary = firestoreData["summary"] as? String ?? ""
                    newSession.name = firestoreData["name"] as? String ?? "Unnamed Session"
                    newSession.needsSync = false

                    let bookFetchRequest: NSFetchRequest<Book> = Book.fetchRequest()
                    bookFetchRequest.predicate = NSPredicate(format: "title == %@", bookTitle)
                    if let book = try? context.fetch(bookFetchRequest).first {
                        newSession.book = book
                    }

                    print("Added session \(sessionID) from Firestore to Core Data")
                }
            }

            for (sessionID, localSession) in localSessionMap {
                if firestoreSessions[sessionID] == nil {
                    let sessionData: [String: Any] = [
                        "id": localSession.id ?? UUID().uuidString,
                        "name": localSession.name ?? "Unnamed Session",
                        "date": localSession.date ?? Date(),
                        "lastUpdated": localSession.lastUpdated ?? Date(),
                        "pagesRead": localSession.pagesRead,
                        "summary": localSession.summary ?? ""
                    ]
                    try await sessionsRef.document(sessionID).setData(sessionData)
                    print("Uploaded local session \(sessionID) to Firestore")
                }
            }

            try context.save()
            print("Sync complete for book \(bookTitle): Core Data and Firestore merged")

            DispatchQueue.main.async {
                self.fetchSessionsFromCoreData(for: bookTitle)  // Refresh UI after sync
            }

        } catch {
            print("Error syncing sessions: \(error.localizedDescription)")
        }
    }
    
    func removeSession(title: String, at index: Int) {
        guard var bookSessions = self.sessions[title], index < bookSessions.count else {
            print("unable to get bookSessions or index out of range, returning")
            return
        }

        let sessionToDelete = bookSessions[index]
        guard let sessionToDeleteID = sessionToDelete["id"] as? String, !sessionToDeleteID.isEmpty else {
            print("Session ID is missing or empty, aborting delete.")
            return
        }

        // Add session to deletion queue
        DeletionQueue.shared.addSessionToDelete(sessionToDeleteID)

        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Sessions> = Sessions.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", sessionToDeleteID)

        do {
            if let session = try context.fetch(fetchRequest).first {
                context.delete(session)
                try context.save()
                print("Session \(sessionToDeleteID) removed from CoreData")
            }
        } catch {
            print("Error deleting session \(sessionToDeleteID): \(error.localizedDescription)")
            return
        }
        DispatchQueue.main.async {
            bookSessions.remove(at: index)
            self.sessions[title] = bookSessions
            print("Session removed from sessionManager for \(title)")
        }
    }

    
    func updateSessionSummary(bookTitle: String, sessionId: String, newSummary: String) -> Bool {
        let context = PersistenceController.shared.container.viewContext

        let fetchRequest: NSFetchRequest<Sessions> = Sessions.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "SELF.id == %@", sessionId)
        
        
        do {
            let fetchedSessions = try context.fetch(fetchRequest)
                    print("Fetched sessions count: \(fetchedSessions.count)")
            if let session = try context.fetch(fetchRequest).first {
                
                session.summary = newSummary
                session.lastUpdated = Date()
                session.needsSync = true
                
                try context.save()
                print("Session \(sessionId) updated in CoreData with new summary.")

                // Update sessionsManager.sessions to reflect the change in UI
                if let index = self.sessions[bookTitle]?.firstIndex(where: { $0["id"] as? String == sessionId }) {
                    DispatchQueue.main.async {
                        self.sessions[bookTitle]?[index]["summary"] = newSummary
                        self.sessions[bookTitle]?[index]["lastUpdated"] = session.lastUpdated
                        self.sessions[bookTitle]?[index]["needsSync"] = true
                    }
                    print("Updated session \(sessionId) in sessionsManager.sessions.")
                    return true
                }
            } else {
                print("Error: Session \(sessionId) not found in CoreData.")
                return false
            }
        } catch {
            print("Error updating session summary: \(error.localizedDescription)")
            return false
        }
        return false
    }
}
