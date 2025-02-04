//
//  AddBookView.swift
//  ReadingPal
//
//  Created by Kaleb Davis on 1/15/25.
//

import Foundation
import SwiftUI

struct AddBookView: View {
    @EnvironmentObject var authView: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var newBookTitle: String = ""

    var body: some View {
        VStack {
            TextField("Book Title", text: $newBookTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Add Book") {
                authView.addBook(newBookTitle)
                dismiss()
            }
            .font(.headline)
            .padding()
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Add New Book")
    }
}
