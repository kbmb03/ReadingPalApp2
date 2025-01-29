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

    init() {
    }

    var body: some Scene {
        WindowGroup {
            SignInView()
            //BookListView()
                .environmentObject(sessionsManager)
        }
    }

}
