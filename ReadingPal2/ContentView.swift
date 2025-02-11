//
//  ContentView.swift
//  ReadingPal2
//
//  Created by Kaleb Davis on 1/29/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    var body: some View {
        if !viewModel.loadingComplete {
            ProgressView("Loading books...")
        } else {
            Group {
                if viewModel.userSession != nil {
                    //BookListView()
                    MainTabView()
                } else {
                    //BookListView()
                    SignInView()
                }
            }
        }
    }
}

