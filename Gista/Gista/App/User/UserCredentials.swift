//
//  UserCredentials.swift
//  Gista
//
//  Created by Tony Nlemadim on 5/1/25.
//

import SwiftUI
import Combine

/// A class that manages user credentials using AppStorage
class UserCredentials: ObservableObject {
    // MARK: - Singleton
    static let shared = UserCredentials()
    
    // MARK: - Published Properties with AppStorage
    @AppStorage("isSignedIn") var isSignedIn: Bool = true // Default to true for now
    @AppStorage("userId") var userId: String = ""
    @AppStorage("username") var username: String = ""
    @AppStorage("userEmail") var userEmail: String = ""
    @AppStorage("profilePictureUrl") var profilePictureUrl: String = ""
    
    // MARK: - Computed Properties
    var isAuthenticated: Bool {
        return isSignedIn && !username.isEmpty && !userId.isEmpty
    }
    
    // MARK: - Initialization
    private init() {
        // Private initializer to enforce singleton pattern
        syncWithUserConfiguration()
    }
    
    // MARK: - Public Methods
    
    /// Updates the credentials from a User object
    /// - Parameter user: The user object to update from
    func updateFrom(user: User) {
        isSignedIn = user.isAuthenticated
        userId = user.userId
        username = user.username
        userEmail = user.email
        profilePictureUrl = user.profilePictureUrl ?? ""
    }
    
    /// Clears all user credentials
    func clearCredentials() {
        isSignedIn = false
        userId = ""
        username = ""
        userEmail = ""
        profilePictureUrl = ""
    }
    
    /// Creates a User object from the current credentials
    /// - Returns: A User object with the current credentials
    func toUser() -> User {
        return User(
            userId: userId,
            message: "User created from credentials",
            username: username,
            email: userEmail,
            isAuthenticated: isSignedIn,
            profilePictureUrl: profilePictureUrl.isEmpty ? nil : profilePictureUrl
        )
    }
    
    /// Syncs the credentials with UserConfiguration
    func syncWithUserConfiguration() {
        if let user = UserConfiguration.shared.loadUser() {
            updateFrom(user: user)
        }
    }
    
    /// Saves the current credentials to UserConfiguration
    func saveToUserConfiguration() {
        let user = toUser()
        UserConfiguration.shared.saveUser(user)
    }
} 