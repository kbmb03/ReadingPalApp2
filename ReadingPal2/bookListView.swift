//
//  launchView.swift
//  ReadingPal
//
//  Created by Kaleb Davis on 1/13/25.
//

import Foundation
import SwiftUICore
import SwiftUI

struct BookListView: View {
    @EnvironmentObject var sessionsManager: SessionsManager
    @State private var showAddBookAlert = false
    @State private var newBookName = ""
    @State private var editMode: EditMode = .inactive // Local editMode state
    @State private var showDuplicateAlert = false // State to track duplicate book alert

    var body: some View {
        NavigationView {
            List {
                ForEach(sessionsManager.books, id: \.self) { book in
                    NavigationLink(destination: BookSessionsView(bookTitle: book)) {
                        Text(book)
                    }
                }
                .onDelete(perform: { offsets in
                    sessionsManager.removeBook(at: offsets)
                })
                .onMove(perform: { source, destination in
                    sessionsManager.moveBook(from: source, to: destination)
                })

                // Add new book button
                Button(action: { showAddBookAlert = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Add New Book")
                    }
                }
                .font(.headline)
            }
            .navigationTitle("My Books")
            .toolbar(.visible, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            if editMode == .inactive {
                                editMode = .active
                            } else {
                                editMode = .inactive
                            }
                        }
                    }) {
                        Text(editMode == .active ? "Done" : "Edit")
                    }
                }
            }
            .environment(\.editMode, $editMode) // Provide editMode to the environment
            .alert("Add New Book", isPresented: $showAddBookAlert) {
                TextField("Book Name", text: $newBookName)
                Button("Add", action: validateAndAddBook)
                Button("Cancel", role: .cancel) {}
            }
            .alert("Can't Add Book", isPresented: $showDuplicateAlert, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text("A book with the same name already exists.")
            })
        }
    }

    private func validateAndAddBook() {
        guard !newBookName.isEmpty else { return }

        if sessionsManager.books.contains(newBookName) {
            showDuplicateAlert = true
            newBookName = ""
        } else {
            sessionsManager.addBook(newBookName)
            newBookName = ""
        }
    }
}
