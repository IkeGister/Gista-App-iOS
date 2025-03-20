//
//  UserCredentials.swift
//  Gista
//
//  Created by Tony Nlemadim on 5/1/25.
//

import SwiftUI
import Combine
import Shared

/// A class that manages user credentials using UserDefaults within the app group
class UserCredentials: ObservableObject {
    // MARK: - Singleton
    static let shared = UserCredentials()
    
    // MARK: - Published Properties
    @Published var isSignedIn: Bool = false
    @Published var userId: String = ""
    @Published var username: String = ""
    @Published var userEmail: String = ""
    @Published var profilePictureUrl: String = ""
    
    // MARK: - Private Properties
    private let userDefaults: UserDefaults
    
    // MARK: - Computed Properties
    var isAuthenticated: Bool {
        return isSignedIn && !username.isEmpty && !userId.isEmpty
    }
    
    // MARK: - Initialization
    private init() {
        // Use the shared helper to get app group UserDefaults
        self.userDefaults = AppGroupConstants.getUserDefaults()
        
        // Load values from UserDefaults using the shared keys
        self.isSignedIn = userDefaults.bool(forKey: AppGroupConstants.UserDefaultsKeys.isSignedIn)
        self.userId = userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.userId) ?? ""
        self.username = userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.username) ?? ""
        self.userEmail = userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.userEmail) ?? ""
        self.profilePictureUrl = userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.profilePictureUrl) ?? ""
        
        // Run diagnostics to verify app group access
        let diagnosticMessage = AppGroupConstants.verifyAppGroupAccess(source: "MainApp-UserCredentials")
        print(diagnosticMessage)
        
        // Private initializer to enforce singleton pattern
        syncWithUserConfiguration()
    }
    
    // MARK: - Public Methods
    
    /// Updates the credentials from a User object
    /// - Parameter user: The user object to update from
    func updateFrom(user: User) {
        // Use DispatchQueue.main.async to avoid publishing changes during view updates
        DispatchQueue.main.async {
            // Update published properties
            self.isSignedIn = user.isAuthenticated
            self.userId = user.userId
            self.username = user.username
            self.userEmail = user.email
            self.profilePictureUrl = user.profilePictureUrl ?? ""
            
            // Save to UserDefaults using shared keys
            self.userDefaults.set(user.isAuthenticated, forKey: AppGroupConstants.UserDefaultsKeys.isSignedIn)
            self.userDefaults.set(user.userId, forKey: AppGroupConstants.UserDefaultsKeys.userId)
            self.userDefaults.set(user.username, forKey: AppGroupConstants.UserDefaultsKeys.username)
            self.userDefaults.set(user.email, forKey: AppGroupConstants.UserDefaultsKeys.userEmail)
            self.userDefaults.set(user.profilePictureUrl ?? "", forKey: AppGroupConstants.UserDefaultsKeys.profilePictureUrl)
            self.userDefaults.synchronize() // Force immediate save
            
            print("DEBUG: Updated user credentials and saved to app group - \(user.userId)")
        }
    }
    
    /// Clears all user credentials - IMPORTANT: Only call during explicit user logout or account deletion
    func clearCredentials() {
        print("⚠️ WARNING: clearCredentials() called - this affects the app group and should ONLY be used during explicit user logout or account deletion")
        
        // Use DispatchQueue.main.async to avoid publishing changes during view updates
        DispatchQueue.main.async {
            // Update published properties
            self.isSignedIn = false
            self.userId = ""
            self.username = ""
            self.userEmail = ""
            self.profilePictureUrl = ""
            
            // Clear from UserDefaults using shared keys
            self.userDefaults.set(false, forKey: AppGroupConstants.UserDefaultsKeys.isSignedIn)
            self.userDefaults.set("", forKey: AppGroupConstants.UserDefaultsKeys.userId)
            self.userDefaults.set("", forKey: AppGroupConstants.UserDefaultsKeys.username)
            self.userDefaults.set("", forKey: AppGroupConstants.UserDefaultsKeys.userEmail)
            self.userDefaults.set("", forKey: AppGroupConstants.UserDefaultsKeys.profilePictureUrl)
            self.userDefaults.synchronize() // Force immediate save
            
            print("DEBUG: Cleared user credentials from app group")
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
        }
        // Never clear credentials during normal sync - 
        // this ensures share extension can still access credentials
    }
    
    /// Saves the current credentials to UserConfiguration
    func saveToUserConfiguration() {
        let user = toUser()
        UserConfiguration.shared.saveUser(user)
    }
} 