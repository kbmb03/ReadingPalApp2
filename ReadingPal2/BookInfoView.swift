//
//  BookInfoView.swift
//  ReadingPal
//
//  Created by Kaleb Davis on 1/23/25.
//

import Foundation
import SwiftUI

struct BookInfoView : View {
    let bookTitle : String
    @EnvironmentObject var sessionsManager: SessionsManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDatePicker = false
    @State private var selectedDate = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Total Pages Read: \(sessionsManager.totalPagesRead(for: bookTitle))")
                .font(.headline)
            Text("Total Time Read: \(sessionsManager.totalReadingDuration(for: bookTitle))")
                .font(.headline)
            Text("Number of Reading Sessions: \(sessionsManager.numberOfSessions(for: bookTitle))")
                .font(.headline)
            if let startedOnDate = sessionsManager.earliestSessionDate(for: bookTitle) {
                Text("Started on: \(formatDate(startedOnDate))")
                    .font(.headline)
            } else {
                Text("Started on: N/A")
                    .font(.headline)
                    .foregroundStyle(.gray)
            }
            if let finishedDate = sessionsManager.finishedDate(for: bookTitle) {
                Text("Date Finished: \(formatDate(finishedDate))")
                    .font(.headline)
                    .onTapGesture {
                        if sessionsManager.isBookFinished(for: bookTitle) {
                            selectedDate = finishedDate // Prepopulate with the existing date
                            showingDatePicker = true
                        }
                    }
            } else {
                Text("Date Finished: N/A")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .onTapGesture {
                        if sessionsManager.isBookFinished(for: bookTitle) {
                            showingDatePicker = true
                        }
                    }
            }
            Button(action: {
                sessionsManager.isBookFinished(for: bookTitle)
                ? sessionsManager.reOpenBook(for: bookTitle)
                : sessionsManager.markBookAsFinished(for: bookTitle)
            }) {
                Text(sessionsManager.isBookFinished(for: bookTitle)
                ? "Mark Book as Unfinished"
                : "Mark Book as Finished")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            Spacer()
        }
        .padding()
        .navigationTitle(bookTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "xmark")
                            .imageScale(.large)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            VStack {
                DatePicker("Select Finished Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()

                Button("Save") {
                    sessionsManager.setFinishedDate(for: bookTitle, to: selectedDate)
                    showingDatePicker = false
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)

                Button("Cancel") {
                    showingDatePicker = false
                }
                .padding()
                .foregroundColor(.red)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
