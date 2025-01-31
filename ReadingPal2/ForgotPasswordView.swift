//
//  ForgotPasswordView.swift
//  ReadingPal2
//
//  Created by Kaleb Davis on 1/30/25.
//

import SwiftUI

struct ForgotPasswordView: View {
    @State private var email: String = ""
    @State private var errorMessage: String?
    @EnvironmentObject var viewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                Image("Image")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 120)
                    .padding(.vertical, 32)
                
                VStack(spacing: 24) {
                    InputView(text: $email, title: "Email Adress", placeholder: "name@example.com")
                        .textInputAutocapitalization(.none)
                    
                        .padding(.horizontal)
                        .padding(.top, 12)
                    
                    if let errorMessage = viewModel.authErrorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    
                    Button {
                        Task {
                            //sent forgot password link
                        }
                    } label: {
                        HStack {
                            Text("Reset Password")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(width: UIScreen.main.bounds.width - 32, height: 48)
                    }
                    .background(Color(.systemBlue))
                    .disabled(!formIsValid)
                    .opacity(formIsValid ? 1.0 : 0.5)
                    .cornerRadius(10)
                    .padding(.top, 24)
                    Spacer()
                        .onDisappear {
                            email = ""
                        }
                }
            }
        }
    }
}
    
    extension ForgotPasswordView: AuthenticationFormProtocol {
        var formIsValid: Bool {
            return !email.isEmpty
            && email.contains("@")
        }
    }
