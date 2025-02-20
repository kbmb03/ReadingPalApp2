//
//  BookSessionView.swift
//  ReadingPal
//
//  Created by Kaleb Davis on 1/13/25.
//

import Foundation
import SwiftUICore
import Foundation
import SwiftUI

struct BookSessionView: View {
    @Binding var session: [String: Any]
    let bookTitle: String
    @EnvironmentObject var sessionsManager: SessionsManager
    @State private var editedSummary: String = ""
    @State private var saveButtonText: String = "Save Summary"
    @State private var isSaveButtonDisabled: Bool = true
    @State private var showErrorAlert: Bool = false

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
            } else {
                Text("Pages Read: N/A")
                    .font(.headline)
            }

            if let duration = session["duration"] as? String {
                Text("Time Read: \(duration)")
                    .font(.headline)
            } else {
                Text("Time Read: NA")
                    .font(.headline)
            }

            Text("Summary:")
                .font(.headline)

            TextEditor(text: $editedSummary)
                .border(Color.gray, width: 1)
                .frame(height: 400)
                .padding(.bottom)
                .onChange(of: editedSummary) { _ in
                    resetSaveButton()
                }

            Button(action: saveSummary) {
                Text(saveButtonText)
                    .frame(maxWidth: .infinity) // Make button wider
                    .padding()
                    .background(isSaveButtonDisabled ? Color.gray.opacity(0.5) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(isSaveButtonDisabled) // Disable button if no edits
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Error Saving"),
                    message: Text("An error occurred while saving. Please restart the app and try again."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .padding()
        .onAppear {
            editedSummary = session["summary"] as? String ?? ""
            resetSaveButton()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func saveSummary() {
        guard let sessionId = session["id"] as? String else { return }

        let success = sessionsManager.updateSessionSummary(
            bookTitle: bookTitle,
            sessionId: sessionId,
            newSummary: editedSummary
        )

        if success {
            saveButtonText = "Successfully saved!"
            isSaveButtonDisabled = true
        } else {
            showErrorAlert = true
        }
    }

    private func resetSaveButton() {
        saveButtonText = "Save Summary"
        isSaveButtonDisabled = editedSummary == session["summary"] as? String
    }
}
