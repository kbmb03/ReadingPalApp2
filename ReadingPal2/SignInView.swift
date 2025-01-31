//
//  SignInView.swift
//  ReadingPal2
//
//  Created by Kaleb Davis on 1/28/25.
//

import Foundation
import SwiftUI
import UIKit
import FirebaseAuth

struct SignInView: View {
    //@EnvironmentObject var authManager: AuthManager

    @State private var email: String = ""
    @State private var password: String = ""
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
                    
                    InputView(text: $password, title: "Password", placeholder: "Enter your password", isSecureField: true)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                if let errorMessage = viewModel.authErrorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                HStack {
                    Spacer()
                    NavigationLink(destination: BookListView()) {
                        Text("Forgot Password?")
                            .foregroundColor(.gray)
                            .font(.footnote)
                            .padding(.top, 8)
                    }
                    .padding(.trailing)
                }

                
                Button {
                    Task {
                        try await viewModel.signIn(withEmail: email, password: password)
                    }
                } label: {
                    HStack {
                        Text("SIGN IN")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
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
                
                NavigationLink {
                    RegisterView()
                        .navigationBarBackButtonHidden(true)
                } label: {
                    HStack {
                        Text("Don't have an account?")
                        Text("Sign up")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 14))
                }
            }
            .onAppear() {
                viewModel.authErrorMessage = nil
            }
            .onDisappear {
                email = ""
                password = ""
            }
        }
    }
}

extension SignInView: AuthenticationFormProtocol {
    var formIsValid: Bool {
        return !email.isEmpty
        && email.contains("@")
        && !password.isEmpty
        && password.count > 5
    }
}
