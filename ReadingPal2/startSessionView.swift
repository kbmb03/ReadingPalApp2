//
//  ContentView.swift
//  ReadingPal
//
//  Created by Kaleb Davis on 11/10/24.
//

import SwiftUI

struct startTimerView: View {
    let bookTitle: String
    @EnvironmentObject var sessionsManager: SessionsManager
    @State private var isTimerRunning = false
    @State private var timeElapsed: TimeInterval = 0
    @State private var startPage = ""
    @State private var endPage = ""
    @State private var summary = ""
    @State private var sessionName = ""
    @State private var showCancelConfirmation = false
    @State private var showErrorInNamingSession = false
    @State private var showInvalidPageInputAlert = false // New alert for page input validation
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                StopwatchView(isRunning: $isTimerRunning, timeElapsed: $timeElapsed)
                    .padding()

                if !isTimerRunning {
                    VStack(spacing: 16) {
                        TextField("Session Name", text: $sessionName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        TextField("Start Page", text: $startPage)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        TextField("End Page", text: $endPage)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)

                        VStack(alignment: .leading) {
                            Text("Summary")
                                .font(.headline)
                            ScrollView {
                                TextEditor(text: $summary)
                                    .frame(minHeight: 300, maxHeight: 350)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray, lineWidth: 1)
                                    )
                            }
                            .frame(height: 300)
                        }
                        .padding(.horizontal)
                    }
                }
                Spacer()
            }
            .onTapGesture {
                hideKeyboard()
            }
            .navigationTitle(bookTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges() {
                            showCancelConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if !isValidPageInput() {
                            showInvalidPageInputAlert = true
                            return
                        }

                        let validName = validSessionName(title: sessionName)
                        if validName {
                            saveSession()
                            dismiss()
                        } else {
                            showErrorInNamingSession = true
                        }
                    }
                }
            }
            .alert("Invalid Name", isPresented: $showErrorInNamingSession) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You already have a session named \(sessionName)")
            }
            .alert("Invalid Page Numbers", isPresented: $showInvalidPageInputAlert) { // New alert
                Button("OK", role: .cancel) {}
            } message: {
                Text("Start and End Page must contain only numbers.")
            }
            .confirmationDialog("You Have Unsaved Changes", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func hasUnsavedChanges() -> Bool {
        return !sessionName.isEmpty || !startPage.isEmpty || !endPage.isEmpty || !summary.isEmpty || timeElapsed > 0
    }

    private func isValidPageInput() -> Bool {
        let numberRegex = "^[0-9]*$"
        let startPageValid = startPage.isEmpty || startPage.range(of: numberRegex, options: .regularExpression) != nil
        let endPageValid = endPage.isEmpty || endPage.range(of: numberRegex, options: .regularExpression) != nil
        return startPageValid && endPageValid
    }

    private func saveSession() {
        var potentialName: String = sessionName
        let existingSessionNames = Set(sessionsManager.sessions[bookTitle]?.compactMap { $0["name"] as? String } ?? [])

        if potentialName.isEmpty {
            potentialName = "Session \((sessionsManager.sessions[bookTitle]?.count ?? 0) + 1)"
            if existingSessionNames.contains(potentialName) {
                var validName = false
                var increment = 1
                while !validName {
                    potentialName = "Session \((sessionsManager.sessions[bookTitle]?.count ?? 0) + 1 + increment)"
                    validName = !existingSessionNames.contains(potentialName)
                    increment += 1
                }
            }
        }

        let start = Int(startPage) ?? 0
        let end = Int(endPage) ?? 0
        let pagesRead = max(end - start, 0)
        let session: [String: Any] = [
            "id": UUID().uuidString,
            "name": potentialName,
            "duration": formatDuration(timeElapsed),
            "date": Date(),
            "startPage": startPage,
            "endPage": endPage,
            "pagesRead": pagesRead,
            "summary": summary,
        ]
        sessionsManager.addSession(to: bookTitle, sessionData: session)
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func validSessionName(title: String) -> Bool {
        let existingSessionNames = Set(sessionsManager.sessions[bookTitle]?.compactMap { $0["name"] as? String } ?? [])
        return !existingSessionNames.contains(title)
    }
}

