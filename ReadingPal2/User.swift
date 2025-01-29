//
//  User.swift
//  ReadingPal2
//
//  Created by Kaleb Davis on 1/29/25.
//

import Foundation

struct User: Identifiable, Codable {
    let id: String
    let fullName: String
    let email: String
    
    var initials: String {
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: fullName) {
            formatter.style = .abbreviated
            return formatter.string(from: components)
        }
        //return blank image view, or make them enter one letter
        return ""
    }
}

extension User {
    static var MOCK_USER = User(id: NSUUID().uuidString, fullName: "John Doe", email: "Lebron@gmail.com")
}
