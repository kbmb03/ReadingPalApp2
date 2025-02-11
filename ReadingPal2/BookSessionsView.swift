//
//  BookDetailView.swift
//  ReadingPal
//
//  Created by Kaleb Davis on 1/13/25.
//

import Foundation
import SwiftUICore
import SwiftUI

struct BookSessionsView: View {
    let bookTitle: String
    @EnvironmentObject var sessionsManager: SessionsManager
    @State private var showStartTimerView = false
    @State private var showBookDetailsView = false
    @Environment(\.editMode) private var editMode

    var body: some View {
        List {
            if let bookSessions = sessionsManager.sessions[bookTitle] {
                ForEach(bookSessions.indices, id: \.self) { index in
                    sessionRow(for: index)
                }
                .onDelete(perform: editMode?.wrappedValue.isEditing == true ? deleteSession : nil)
                .onMove(perform: editMode?.wrappedValue.isEditing == true ? moveSession : nil)
            } else {
                noSessionsView
            }

            Button(action: { showStartTimerView = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    Text("Add New Session")
                }
            }
            .font(.headline)
        }
        .onAppear {
            if sessionsManager.sessions[bookTitle] == nil || sessionsManager.sessions[bookTitle]?.isEmpty == true {
                sessionsManager.fetchSessionsFromCoreData(for: bookTitle)
                print("Fetching sessions from Core Data for \(bookTitle) on view appear.")
            }
        }

        .fullScreenCover(isPresented: $showStartTimerView) {
            startTimerView(bookTitle: bookTitle)
                .environmentObject(sessionsManager)
        }
        .fullScreenCover(isPresented: $showBookDetailsView) {
            NavigationView {
                BookInfoView(bookTitle: bookTitle)
                    .environmentObject(sessionsManager)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        //.toolbarRole(.editor)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Text(bookTitle)
                        .font(.headline)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            showBookDetailsView = true
                        }
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .onTapGesture {
                            showBookDetailsView = true
                        }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }

    private func deleteSession(at offsets: IndexSet) {
//        guard let bookSessions = sessionsManager.sessions[bookTitle] else { return }
//
//        for index in offsets {
//            let sessionId = bookSessions[index]["id"] as? String ?? ""
//            if !sessionId.isEmpty {
//                sessionsManager.deleteSession(bookTitle: bookTitle, sessionId: sessionId)
//            }
//        }
    }

    private func moveSession(from source: IndexSet, to destination: Int) {
//        guard var bookSessions = sessionsManager.sessions[bookTitle] else { return }
//        
//        bookSessions.move(fromOffsets: source, toOffset: destination) // Move in local UI
//        
//        sessionsManager.updateSessionOrder(for: bookTitle, newOrder: bookSessions)
    }


    private func sessionRow(for index: Int) -> some View {
        Group {
            if let bookSessions = sessionsManager.sessions[bookTitle], index < bookSessions.count {
                let session = bookSessions[index]
                let sessionName = session["name"] as? String ?? "Session \(index + 1)"
                let pagesRead = session["pagesRead"] as? Int ?? 0
                let sessionDate = (session["date"] as? Date)?.formatted() ?? "Unknown Date"
                let isSynced = session["needsSync"] as? Bool ?? false

                NavigationLink(destination: BookSessionView(
                    session: Binding(
                        get: { bookSessions[index] },
                        set: { newValue in
                            var updatedSessions = bookSessions
                            updatedSessions[index] = newValue
                        }
                    ),
                    bookTitle: bookTitle
                )) {
                    VStack(alignment: .leading) {
                        Text(sessionName).font(.headline)
                    }
                }
            } else {
                Text("Session not available")  // Ensure a valid return type
                    .foregroundColor(.gray)
                    .font(.subheadline)
            }
        }
    }



    private var noSessionsView: some View {
        Text("No sessions available")
            .foregroundColor(.gray)
            .font(.subheadline)
    }
}
