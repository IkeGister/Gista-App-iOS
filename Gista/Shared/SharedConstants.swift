//
//  SharedConstants.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/29/25.
//

// MARK: - Network Constants
public enum NetworkConstants {
    /// Default timeout for network requests (30 seconds)
    public static let defaultTimeout: TimeInterval = 30
    
    /// Extended timeout for larger operations (60 seconds)
    public static let extendedTimeout: TimeInterval = 60
    
    /// Default headers for all API requests
    public static let baseHeaders: [String: String] = [
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "Gista/1.0"
    ]
    
    /// Maximum number of retry attempts for failed requests
    public static let maxRetryAttempts = 3
    
    /// Delay between retry attempts (in seconds)
    public static let retryDelay: TimeInterval = 2
    
    /// Cache policies
    public enum CachePolicy {
        /// Default cache duration (5 minutes)
        public static let defaultDuration: TimeInterval = 300
        
        /// Extended cache duration (1 hour)
        public static let extendedDuration: TimeInterval = 3600
    }
    
    /// API rate limits
    public enum RateLimit {
        /// Maximum requests per minute
        public static let requestsPerMinute = 60
        
        /// Cool down period after rate limit (in seconds)
        public static let coolDownPeriod: TimeInterval = 60
    }
}

// MARK: - App Group Constants
public enum AppGroupConstants {
    /// App Group identifier for sharing data between main app and extensions
    public static let appGroupId = "group.Voqa.io.Gista"
    
    /// Key for the share queue in UserDefaults
    public static let shareQueueKey = "ShareQueue"
    
    /// Directory for shared files
    public static let sharedFilesDirectory = "SharedFiles"
    
    /// UserDefaults keys
    public enum UserDefaultsKeys {
        public static let userId = "userId"
        public static let username = "username"
        public static let userEmail = "userEmail"
        public static let isSignedIn = "isSignedIn"
        public static let profilePictureUrl = "profilePictureUrl"
    }
    
    /// Notifications
    public enum Notifications {
        public static let newContentReceived = "NewSharedContentReceived"
    }
}

// MARK: - App Group Helpers
public extension AppGroupConstants {
    /// Get UserDefaults for the app group
    /// - Returns: UserDefaults instance for the app group, or standard UserDefaults if app group is not accessible
    static func getUserDefaults() -> UserDefaults {
        if let groupDefaults = UserDefaults(suiteName: appGroupId) {
            return groupDefaults
        } else {
            print("⚠️ Warning: Could not access app group UserDefaults, falling back to standard")
            return UserDefaults.standard
        }
    }
    
    /// Check if app group is accessible
    /// - Returns: True if app group is accessible
    static func isAppGroupAccessible() -> Bool {
        let userDefaults = getUserDefaults()
        let testKey = "appGroupAccessTest"
        userDefaults.set(true, forKey: testKey)
        let result = userDefaults.bool(forKey: testKey)
        userDefaults.removeObject(forKey: testKey)
        return result
    }
}

// MARK: - Diagnostics
public extension AppGroupConstants {
    /// Verify app group access and log diagnostic information
    /// - Parameter source: The source of the diagnostic check (e.g., "MainApp", "ShareExtension")
    /// - Returns: A diagnostic message with the results
    static func verifyAppGroupAccess(source: String) -> String {
        let userDefaults = getUserDefaults()
        let diagnosticKey = "appGroupDiagnostic"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let diagnosticValue = "Test from \(source) at \(timestamp)"
        
        // Write diagnostic value
        userDefaults.set(diagnosticValue, forKey: diagnosticKey)
        userDefaults.synchronize()
        
        // Read it back
        let readValue = userDefaults.string(forKey: diagnosticKey) ?? "Not found"
        let isAccessible = readValue == diagnosticValue
        
        // Get all relevant keys
        let userKeys = ["userId", "username", "userEmail", "isSignedIn"]
        var keyValues: [String: Any] = [:]
        for key in userKeys {
            if let value = userDefaults.object(forKey: key) {
                keyValues[key] = value
            } else {
                keyValues[key] = "Not set"
            }
        }
        
        // Create diagnostic message
        let message = """
        App Group Diagnostic from \(source):
        - Timestamp: \(timestamp)
        - App Group ID: \(appGroupId)
        - Access Working: \(isAccessible ? "✅ Yes" : "❌ No")
        - Write Value: \(diagnosticValue)
        - Read Value: \(readValue)
        - User Keys:
          \(keyValues.map { "  - \($0.key): \($0.value)" }.joined(separator: "\n"))
        """
        
        return message
    }
}

// Add other shared constants here if needed
