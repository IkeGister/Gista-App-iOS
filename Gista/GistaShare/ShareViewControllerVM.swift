//
//  ShareViewControllerVM.swift
//  GistaShare
//
//  Created by Tony Nlemadim on 3/14/25.
//

import Foundation
import Shared


// MARK: - ShareViewControllerVM
class ShareViewControllerVM {
    // MARK: - Properties
    private let linkSender: LinkSender
    private var userId: String?
    
    // Add validation properties
    private let validSchemes = ["http", "https"]
    private let maxTitleLength = 255
    private let maxUrlLength = 2048
    
    // MARK: - Initialization
    init(linkSender: LinkSender = LinkSender()) {
        self.linkSender = linkSender
        loadUserId()
    }
    
    // MARK: - User ID Management
    
    // Public method to manually set userId from outside
    func setUserId(_ userId: String) {
        print("🔐 VIEW MODEL: Setting userId explicitly to: \(userId)")
        self.userId = userId
        print("🔐 VIEW MODEL: userId is now: \(self.userId ?? "nil")")
    }
    
    private func loadUserId() {
        print("🔑 SHARE VIEW MODEL - LOADING USER ID - Direct print")
        Logger.log("🔑 SHARE VIEW MODEL - LOADING USER ID", level: .debug)
        
        // Run diagnostics and log the results
        let diagnosticMessage = AppGroupConstants.verifyAppGroupAccess(source: "ShareExtension")
        print(diagnosticMessage)
        Logger.log(diagnosticMessage, level: .debug)
        
        // Use the shared constants
        let userDefaults = AppGroupConstants.getUserDefaults()
        
        // Log all keys to debug what's actually present
        let allKeys = userDefaults.dictionaryRepresentation().keys.sorted()
        print("🔍 All keys in app group user defaults: \(allKeys)")
        Logger.log("🔍 All keys in app group user defaults: \(allKeys)", level: .debug)
        
        // Explicitly check the isSignedIn and userId keys
        print("🔍 Direct check of user keys:")
        print("- isSignedIn: \(userDefaults.bool(forKey: AppGroupConstants.UserDefaultsKeys.isSignedIn))")
        print("- userId: \(userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.userId) ?? "nil")")
        print("- username: \(userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.username) ?? "nil")")
        
        // First check if the user is signed in
        let isSignedIn = userDefaults.bool(forKey: AppGroupConstants.UserDefaultsKeys.isSignedIn)
        Logger.log("🔍 isSignedIn value: \(isSignedIn)", level: .debug)
        
        if !isSignedIn {
            print("❌ User is not signed in according to app group - Direct print")
            Logger.log("❌ User is not signed in according to app group", level: .error)
            self.userId = nil
            return
        }
        
        // Get the user ID using the shared key
        if let storedUserId = userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.userId), !storedUserId.isEmpty {
            print("✅ Loaded userId from App Group: \(storedUserId) - Direct print")
            Logger.log("✅ Loaded userId from App Group: \(storedUserId)", level: .debug)
            self.userId = storedUserId
            
            // Log the username too for context
            if let username = userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.username) {
                print("✅ Username from App Group: \(username) - Direct print")
                Logger.log("✅ Username from App Group: \(username)", level: .debug)
            }
        } else {
            print("❌ No userId found in App Group using key: \(AppGroupConstants.UserDefaultsKeys.userId) - Direct print")
            Logger.log("❌ No userId found in App Group using key: \(AppGroupConstants.UserDefaultsKeys.userId)", level: .error)
            self.userId = nil
        }
        
        // Final status
        print("📱 Share extension userId after loading: \(self.userId ?? "nil") - Direct print")
        Logger.log("📱 Share extension userId after loading: \(self.userId ?? "nil")", level: .debug)
    }
    
    // MARK: - URL Validation
    private func validateURL(_ url: URL) -> Result<URL, LinkError> {
        // Check URL scheme
        guard let scheme = url.scheme?.lowercased(),
              validSchemes.contains(scheme) else {
            return .failure(.invalidURL)
        }
        
        // Check URL length
        guard url.absoluteString.count <= maxUrlLength else {
            return .failure(.invalidURL)
        }
        
        // Check if URL is reachable (optional)
        return .success(url)
    }
    
    // MARK: - Title Validation
    private func validateTitle(_ title: String?) -> String {
        let sanitizedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if sanitizedTitle.isEmpty {
            return "Untitled"
        }
        return String(sanitizedTitle.prefix(maxTitleLength))
    }
    
    // MARK: - Category Detection
    private func determineCategoryFromURL(_ url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        
        print("🔍 Determining category from URL: \(url)")
        print("🔍 Host detected: \(host.isEmpty ? "EMPTY" : host)")
        
        // Default category if everything else fails
        var category = "Uncategorized"
        
        // Add more sophisticated category detection logic
        switch host {
        case _ where host.contains("github"):
            category = "Development"
        case _ where host.contains("stackoverflow"):
            category = "Development"
        case _ where host.contains("medium"):
            category = "Article"
        case _ where host.contains("youtube"):
            category = "Video"
        case _ where host.contains("twitter") || host.contains("x.com"):
            category = "Social"
        case _ where host.contains("wikipedia"):
            // Use "Article" instead of "Reference" for Wikipedia
            category = "Article"
            print("🔍 Wikipedia detected - using category: Article")
        default:
            // Try to determine category from path components or query parameters
            let path = url.path.lowercased()
            print("🔍 Path detected: \(path)")
            if path.contains("blog") || path.contains("article") {
                category = "Article"
            } else {
                category = "Uncategorized"
            }
        }
        
        print("📊 Final category determined: \(category)")
        return category
    }
    
    // MARK: - Process Shared URL
    func processSharedURL(_ url: URL, title: String? = nil) async -> Result<LinkResponse, LinkError> {
        print("🔄 PROCESSING SHARED URL: \(url.absoluteString)")
        // Validate user authentication
        guard let userId = self.userId else {
            print("❌ No userId available for processing URL")
            Logger.log("No userId available", level: .error)
            return .failure(.unauthorized)
        }
        
        print("✅ Using userId: \(userId) to process URL")
        
        // Removed UUID validation logic - we only need userId to be non-nil
        // isSignedIn is already verified when loading the userId
        
        // Validate URL
        print("🔍 Validating URL: \(url.absoluteString)")
        let urlValidation = validateURL(url)
        switch urlValidation {
        case .failure(let error):
            print("❌ URL validation failed: \(error)")
            return .failure(error)
        case .success(let validatedURL):
            // Validate and sanitize title
            let sanitizedTitle = validateTitle(title)
            print("✅ URL validated. Using title: \(sanitizedTitle)")
            
            // Determine category
            let category = determineCategoryFromURL(validatedURL)
            print("📊 Category determined: \(category)")
            
            // Attempt to send link with retry logic
            var attempts = 0
            let maxAttempts = 3
            
            print("🚀 Attempting to send link to API (max attempts: \(maxAttempts))")
            
            while attempts < maxAttempts {
                attempts += 1
                print("📡 Attempt #\(attempts) to send link")
                
                let result = await linkSender.sendLink(
                    userId: userId,
                    url: validatedURL,
                    title: sanitizedTitle,
                    category: category
                )
                
                print("📥 Received result from attempt #\(attempts): \(result)")
                
                switch result {
                case .success(let response):
                    print("✅ Success on attempt #\(attempts): \(response)")
                    return .success(response)
                case .failure(let error):
                    print("❌ Error on attempt #\(attempts): \(error)")
                    // Only retry on network errors
                    if case .networkError = error, attempts < maxAttempts {
                        print("🔄 Will retry due to network error")
                        // Add exponential backoff
                        try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempts)) * 1_000_000_000))
                        continue
                    }
                    print("❌ Error is terminal, not retrying: \(error)")
                    return .failure(error)
                }
            }
            
            print("❌ All attempts failed. Returning network error")
            return .failure(.networkError)
        }
    }
}

// MARK: - Constants
private extension ShareViewControllerVM {
    enum Constants {
        static let maxRetryAttempts = 3
        static let baseRetryDelay: TimeInterval = 1.0
    }
}
