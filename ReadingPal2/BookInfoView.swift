//
//  BookInfoView.swift
//  ReadingPal
//
//  Created by Kaleb Davis on 1/23/25.
//

import Foundation
import SwiftUI

struct BookInfoView: View {
    let bookTitle: String
    @EnvironmentObject var sessionsManager: SessionsManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDatePicker = false
    @State private var selectedDate = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Book Title
                Text(bookTitle)
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Stats in a Card
                VStack(spacing: 15) {
                    statRow(icon: "book.pages", label: "Total Pages Read", value: "\(sessionsManager.totalPagesRead(for: bookTitle))")
                    statRow(icon: "clock", label: "Total Time Read", value: sessionsManager.totalReadingDuration(for: bookTitle))
                    statRow(icon: "list.number", label: "Number of Sessions", value: "\(sessionsManager.numberOfSessions(for: bookTitle))")
                    
                    if let startedOnDate = sessionsManager.earliestSessionDate(for: bookTitle) {
                        statRow(icon: "calendar", label: "Started on", value: formatDate(startedOnDate))
                    } else {
                        statRow(icon: "calendar.badge.exclamationmark", label: "Started on", value: "N/A", isGray: true)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 5)

                Spacer()
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .imageScale(.large)
                        .foregroundStyle(.primary)
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            VStack {
                DatePicker("Select Finished Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                Button("Cancel") {
                    showingDatePicker = false
                }
                .padding()
                .foregroundColor(.red)
            }
            .padding()
        }
    }

    /// Helper function for displaying stats in a nice row format
    private func statRow(icon: String, label: String, value: String, isGray: Bool = false) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isGray ? .gray : .blue)
                .font(.title3)
            VStack(alignment: .leading) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .bold()
                    .foregroundColor(isGray ? .gray : .primary)
            }
            Spacer()
        }
    }

    /// Helper function to format date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
