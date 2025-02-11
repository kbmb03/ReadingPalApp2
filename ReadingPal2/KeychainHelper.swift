//
//  KeychainHelper.swift
//  ReadingPal2
//
//  Created by Kaleb Davis on 2/10/25.
//


import Security
import Foundation

class KeychainHelper {
    
    static func set(_ value: String, forKey key: String) {
        let data = value.data(using: .utf8)!
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ] as [CFString : Any]
        
        SecItemDelete(query as CFDictionary) // Ensure no duplicates
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            print("Keychain save error for \(key): \(status)")
        }
    }

    static func get(_ key: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [CFString : Any]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        } else {
            return nil
        }
    }

    static func delete(_ key: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ] as [CFString : Any]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess {
            print("Keychain delete error for \(key): \(status)")
        }
    }
}
