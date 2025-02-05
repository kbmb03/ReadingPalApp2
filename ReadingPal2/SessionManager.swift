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
    
    
    func saveFinishedBooks() {
        
    }
    

    // Add a session to a book
    func addSession(to bookTitle: String, session: [String: Any]) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let bookRef = db.collection("users").document(userId).collection("books").document(bookTitle)
        let sessionRef = bookRef.collection("sessions").document()

        var newSession = session
        newSession["id"] = sessionRef.documentID  // Store Firestore-generated session ID

        sessionRef.setData(newSession) { error in
            if let error = error {
                print("❌ Error adding session: \(error.localizedDescription)")
            } else {
                print("✅ Session successfully added for book: \(bookTitle)")
                
                DispatchQueue.main.async {
                    self.sessions[bookTitle, default: []].append(newSession)
                }
            }
        }
    }
    
    func deleteSession(bookTitle: String, sessionId: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let sessionRef = db.collection("users").document(userId)
            .collection("books").document(bookTitle)
            .collection("sessions").document(sessionId)

        sessionRef.delete { error in
            if let error = error {
                print("❌ Error deleting session: \(error.localizedDescription)")
            } else {
                print("✅ Session deleted successfully for book: \(bookTitle)")

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
        let sessionsRef = db.collection("users").document(userId).collection("books").document(bookTitle).collection("sessions")

        sessionsRef.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Error fetching sessions: \(error.localizedDescription)")
                return
            }

            let fetchedSessions = snapshot?.documents.compactMap { doc -> [String: Any]? in
                var data = doc.data()
                data["id"] = doc.documentID  // Store Firestore ID
                return data
            } ?? []

            DispatchQueue.main.async {
                self.sessions[bookTitle] = fetchedSessions
                print("✅ Fetched \(fetchedSessions.count) sessions for \(bookTitle)")
            }
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
