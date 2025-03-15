//
//  User.swift
//  Shared
//
//  Created by Tony Nlemadim on 5/1/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - User Class
public class User: ObservableObject, Codable {
    @Published public var userId: String
    @Published public var message: String
    @Published public var username: String
    @Published public var email: String
    @Published public var isAuthenticated: Bool
    @Published public var lastLoginDate: Date?
    
    public enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case message
        case username
        case email
        case isAuthenticated
        case lastLoginDate
    }
    
    public init(userId: String, message: String = "User operation completed", username: String = "", email: String = "", isAuthenticated: Bool = false, lastLoginDate: Date? = nil) {
        self.userId = userId
        self.message = message
        self.username = username
        self.email = email
        self.isAuthenticated = isAuthenticated
        self.lastLoginDate = lastLoginDate
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode userId, which should always be present
        userId = try container.decode(String.self, forKey: .userId)
        
        // Try to decode message, but use a default if missing
        if let decodedMessage = try? container.decode(String.self, forKey: .message) {
            message = decodedMessage
        } else {
            message = "User operation completed"
        }
        
        // Try to decode username, but use a default if missing
        if let decodedUsername = try? container.decode(String.self, forKey: .username) {
            username = decodedUsername
        } else {
            username = ""
        }
        
        // Try to decode email, but use a default if missing
        if let decodedEmail = try? container.decode(String.self, forKey: .email) {
            email = decodedEmail
        } else {
            email = ""
        }
        
        // Try to decode isAuthenticated, but use a default if missing
        if let decodedIsAuthenticated = try? container.decode(Bool.self, forKey: .isAuthenticated) {
            isAuthenticated = decodedIsAuthenticated
        } else {
            isAuthenticated = false
        }
        
        // Try to decode lastLoginDate, but use a default if missing
        lastLoginDate = try? container.decode(Date.self, forKey: .lastLoginDate)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(message, forKey: .message)
        try container.encode(username, forKey: .username)
        try container.encode(email, forKey: .email)
        try container.encode(isAuthenticated, forKey: .isAuthenticated)
        if let lastLoginDate = lastLoginDate {
            try container.encode(lastLoginDate, forKey: .lastLoginDate)
        }
    }
}

