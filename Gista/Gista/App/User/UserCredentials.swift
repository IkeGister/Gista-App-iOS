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
    @AppStorage("isSignedIn") var isSignedIn: Bool = false // Changed default to false
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
        // Use DispatchQueue.main.async to avoid publishing changes during view updates
        DispatchQueue.main.async {
            self.isSignedIn = user.isAuthenticated
            self.userId = user.userId
            self.username = user.username
            self.userEmail = user.email
            self.profilePictureUrl = user.profilePictureUrl ?? ""
        }
    }
    
    /// Clears all user credentials
    func clearCredentials() {
        // Use DispatchQueue.main.async to avoid publishing changes during view updates
        DispatchQueue.main.async {
            self.isSignedIn = false
            self.userId = ""
            self.username = ""
            self.userEmail = ""
            self.profilePictureUrl = ""
        }
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
        } else {
            // Ensure we're not authenticated if no user is found
            // Use DispatchQueue.main.async to avoid publishing changes during view updates
            DispatchQueue.main.async {
                self.isSignedIn = false
                self.userId = ""
                self.username = ""
                self.userEmail = ""
                self.profilePictureUrl = ""
            }
        }
    }
    
    /// Saves the current credentials to UserConfiguration
    func saveToUserConfiguration() {
        let user = toUser()
        UserConfiguration.shared.saveUser(user)
    }
} 