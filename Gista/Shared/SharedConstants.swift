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

// Add other shared constants here if needed
