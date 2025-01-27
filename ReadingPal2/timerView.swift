//
//  timerView.swift
//  ReadingPal
//
//  Created by Kaleb Davis on 11/10/24.
//

import Foundation

import SwiftUI

struct StopwatchView: View {
    @Binding var isRunning: Bool
    @Binding var timeElapsed: TimeInterval
    @State private var timer: Timer? = nil

    var body: some View {
        VStack {
            Text(timeString(from: timeElapsed))
                .font(.largeTitle)
                .padding()
            
            HStack {
                Button(action: toggleTimer) {
                    Text(isRunning ? "Pause" : "Start")
                        .font(.title2)
                        .padding()
                        .background(isRunning ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Button(action: resetTimer) {
                    Text("Reset")
                        .font(.title2)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
    }

    private func toggleTimer() {
        isRunning.toggle()
        if isRunning {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                timeElapsed += 1
            }
        } else {
            timer?.invalidate()
        }
    }

    private func resetTimer() {
        timeElapsed = 0
        isRunning = false
        timer?.invalidate()
    }

    private func timeString(from time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
