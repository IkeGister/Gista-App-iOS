//
//  UserStorage.swift
//  Gista
//
//  Created by Tony Nlemadim on 5/1/25.
//

import Foundation

/// A singleton class responsible for persisting and retrieving User data
class UserConfiguration {
    // MARK: - Singleton
    static let shared = UserConfiguration()
    
    // MARK: - Constants
    private enum Constants {
        static let userKey = "com.gista.user"
    }
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    // MARK: - Initialization
    private init() {
        // Private initializer to enforce singleton pattern
    }
    
    // MARK: - Public Methods
    
    /// Saves a user to UserDefaults
    /// - Parameter user: The user to save
    func saveUser(_ user: User) {
        do {
            let userData = try jsonEncoder.encode(user)
            userDefaults.set(userData, forKey: Constants.userKey)
        } catch {
            print("Error saving user: \(error.localizedDescription)")
        }
    }
    
    /// Loads a user from UserDefaults
    /// - Returns: The saved user, or nil if no user is saved or an error occurs
    func loadUser() -> User? {
        guard let userData = userDefaults.data(forKey: Constants.userKey) else {
            return nil
        }
        
        do {
            let user = try jsonDecoder.decode(User.self, from: userData)
            return user
        } catch {
            print("Error loading user: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Clears the saved user from UserDefaults
    func clearUser() {
        userDefaults.removeObject(forKey: Constants.userKey)
    }
} 
