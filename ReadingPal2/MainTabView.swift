//
//  MainTabView.swift
//  ReadingPal2
//
//  Created by Kaleb Davis on 1/30/25.
//

import Foundation
import SwiftUI

struct MainTabView: View {
    var body: some View {
        NavigationStack {
            TabView {
                BookListView()
                    .tabItem {
                        Image(systemName: "book.fill")
                        Text("Books")
                    }
                
                ProfileView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
            }
        }
    }
}
