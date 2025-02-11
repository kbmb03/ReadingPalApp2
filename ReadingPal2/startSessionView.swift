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
                                    .frame(minHeight: 200, maxHeight: 300)
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
                        saveSession()
                        dismiss()
                    }
                }
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
        print()
        return !sessionName.isEmpty || !startPage.isEmpty || !endPage.isEmpty || !summary.isEmpty || timeElapsed > 0
    }

    private func saveSession() {
        
        var potentialName : String = sessionName
        let existingSessionNames = Set(sessionsManager.sessions[bookTitle]?.compactMap { $0["name"] as? String } ?? [])

        if !potentialName.isEmpty {
            print("naming session \(sessionName)")
        } else {
            potentialName = "Session \((sessionsManager.sessions[bookTitle]?.count ?? 0) + 1)"
            if existingSessionNames.contains(potentialName) {
                var validName = false
                var increment = 1
                while !validName {
                    print("trying name \(potentialName)")
                    potentialName = "Session \((sessionsManager.sessions[bookTitle]?.count ?? 0) + 1 + increment)"
                    validName = !existingSessionNames.contains(potentialName)
                    increment += 1
                }
            }
        }
        print("potential name == \(potentialName)")
        
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
        print("adding session with the name \(String(describing: session["name"]))")
        sessionsManager.addSession(to: bookTitle, sessionData: session)
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
