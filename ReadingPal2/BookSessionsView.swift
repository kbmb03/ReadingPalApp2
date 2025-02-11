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
                .onDelete(perform: { offsets in
                    deleteSession(title: bookTitle, at: offsets)
                })
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

    private func deleteSession(title: String, at offsets: IndexSet) {
        for index in offsets {
            sessionsManager.removeSession(title: title, at: index)
        }
    }

    private func moveSession(from source: IndexSet, to destination: Int) {

    }


    private func sessionRow(for index: Int) -> some View {
        Group {
            if let bookSessions = sessionsManager.sessions[bookTitle], index < bookSessions.count {
                let session = bookSessions[index]
                let sessionName = session["name"] as? String ?? "Session \(index + 1)"

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
