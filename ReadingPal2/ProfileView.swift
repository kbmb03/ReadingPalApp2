//
//  ProfileView.swift
//  ReadingPal2
//
//  Created by Kaleb Davis on 1/29/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var showDeletionConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        if let user = viewModel.currentUser {
            List {
                Section {
                    HStack {
                        Text(user.initials)
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(Color(.systemGray))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.fullName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                            
                            Text(user.email)
                                .font(.footnote)
                                .accentColor(.gray)
                        }
                    }
                }
                
                Section("General") {
                    HStack {
                        SettingsRowView(imageName: "gear", title: "Version", tintColor: Color(.systemGray))
                        
                        Spacer()
                        Text("1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                }
                
                Section("Account") {
                    Button {
                        Task {
                            isLoading = true
                            await viewModel.syncWithFirestore()
                            isLoading = false
                        }
                    } label: {
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text("Syncing...")
                                    .foregroundStyle(.gray)
                            }
                        } else {
                            SettingsRowView(imageName: "arrow.triangle.2.circlepath", title: "Sync Data", tintColor: .gray)
                        }
                    }
                    Button {
                        //viewModel.signOut()
                        showSignOutConfirmation = true
                    } label: {
                        SettingsRowView(imageName: "arrow.left.circle.fill", title: "Sign Out", tintColor: .red)
                    }
                    .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                        Button("Confirm", role: .destructive) {
                            viewModel.signOut()
                        }
                        Button("Cancel", role: .cancel) {
                            showSignOutConfirmation = false
                        }
                    } message: {
                        Text("Are you sure you want to sign out? You can sign back in anytime.")
                    }
                    
                    
                        Button {
                            showDeletionConfirmation = true
                        } label: {
                            SettingsRowView(imageName: "xmark.circle.fill", title: "Delete Account", tintColor: .red)
                        }
                    .alert("Delete Account", isPresented: $showDeletionConfirmation) {
                            SecureField("Enter your password", text: $password)
                            
                            if isLoading {
                                ProgressView()
                            }
                        
                            Button("Delete", role: .destructive) {
                                Task {
                                    isLoading = true
                                    let accountDeleted = await viewModel.deleteAccount(password: password)
                                    isLoading = false
                                
                                if !accountDeleted {
                                    showError = true
                                    errorMessage = "Incorrect password. Please try again"
                                }
                            }
                        }
                        .disabled(isLoading)
                        
                        Button("Cancel", role: .cancel) {
                            password = ""
                        }
                    }
                }
                .alert("Error", isPresented: $showError) {
                    Button("OK", role: .cancel) {
                        password = ""
                    }
                } message: {
                    Text(errorMessage)
                }
            }
        }
    }
}
