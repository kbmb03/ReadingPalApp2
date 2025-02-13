//
//  BookSessionView.swift
//  ReadingPal
//
//  Created by Kaleb Davis on 1/13/25.
//

import Foundation
import SwiftUICore
import SwiftUI

struct BookSessionView: View {
    @Binding var session: [String: Any]
    let bookTitle: String
    @EnvironmentObject var sessionsManager: SessionsManager
    @State private var editedSummary: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let date = session["date"] as? Date {
                Text("Date: \(formattedDate(date))")
                    .font(.headline)
            }
            
            if let startPage = session["startPage"] as? String,
               let endPage = session["endPage"] as? String {
                Text("Pages Read: \(startPage) - \(endPage)")
                    .font(.headline)
            }
            
            if let duration = session["duration"] as? String {
                Text("Time Read: \(duration)")
                    .font(.headline)
            }
            
            Text("Summary:")
                .font(.headline)
            TextEditor(text: $editedSummary)
                .border(Color.gray, width: 1)
                .frame(height: 400)
                .padding(.bottom)
            
            Button("Save Summary") {
                saveSummary()
            }
            .font(.headline)
            .padding()
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            editedSummary = session["summary"] as? String ?? ""
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func saveSummary() {
        guard let sessionID = session["id"] as? String else {
            print("error: SessionID is missing")
            return
        }
        sessionsManager.updateSessionSummary(bookTitle: bookTitle, sessionId: sessionID, newSummary: editedSummary)
    }
}
