//
//  ReadingPalApp.swift
//  ReadingPal
//
//  Created by Kaleb Davis on 11/10/24.
//

import SwiftUI
import Firebase

@main
struct ReadingPalApp: App {
    @StateObject private var sessionsManager = SessionsManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var viewModel : AuthViewModel

    init() {
        FirebaseApp.configure()
        let sessionManager = SessionsManager()
        _viewModel = StateObject(wrappedValue: AuthViewModel(sessionManager: sessionManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionsManager)
                .environmentObject(viewModel)
        }
    }

}
