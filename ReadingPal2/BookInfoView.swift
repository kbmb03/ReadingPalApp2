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
