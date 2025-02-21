//
//  NetworkMonitor.swift
//  ReadingPal2
//
//  Created by Kaleb Davis on 2/5/25.
//

import Foundation
import Network

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)

    @Published var isConnected: Bool = true

    private init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = (path.status == .satisfied)

            }
        }
        monitor.start(queue: queue)
    }
}
