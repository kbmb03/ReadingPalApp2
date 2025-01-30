//
//  ReadingPalApp.swift
//  ReadingPal
//
//  Created by Kaleb Davis on 11/10/24.
//

import SwiftUI

@main
struct ReadingPalApp: App {
    @StateObject private var sessionsManager = SessionsManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var viewModel = AuthViewModel()

    init() {
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(sessionsManager)
        }
    }

}
