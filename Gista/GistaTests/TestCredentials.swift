//
//  TestCredentials.swift
//  GistaTests
//
//  Created by Tony Nlemadim on 2/16/25.
//

import Foundation

/// Stores test credentials for integration testing.
/// IMPORTANT: Do not commit real credentials to source control.
/// Use environment variables or a local configuration file instead.
enum TestCredentials {
    // MARK: - Test User Credentials
    
    /// Test user email - replace with a real test account or use environment variables
    static var email: String {
        ProcessInfo.processInfo.environment["TEST_EMAIL"] ?? "test@example.com"
    }
    
    /// Test user password - replace with a real test account or use environment variables
    static var password: String {
        ProcessInfo.processInfo.environment["TEST_PASSWORD"] ?? "TestPassword123!"
    }
    
    /// Test username - replace with a real test account or use environment variables
    static var username: String {
        ProcessInfo.processInfo.environment["TEST_USERNAME"] ?? "testuser"
    }
    
    /// Auth token for authenticated requests - only needed for certain operations
    static var authToken: String? {
        ProcessInfo.processInfo.environment["TEST_AUTH_TOKEN"]
    }
} 