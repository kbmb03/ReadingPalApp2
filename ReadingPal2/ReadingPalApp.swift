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
        //requestNotificationPermissions()
        //sessionsManager.scheduleNotificationsForUnfinishedBooks()
    }

    var body: some Scene {
        WindowGroup {
            BookListView()
                .environmentObject(sessionsManager)
        }
    }

//    private func requestNotificationPermissions() {
//        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
//            if granted {
//                print("Notifications permission granted.")
//            } else if let error = error {
//                print("Notifications permission denied: \(error.localizedDescription)")
//            }
//        }
//    }
}
