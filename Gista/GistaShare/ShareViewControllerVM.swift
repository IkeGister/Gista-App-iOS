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
        self.userId = userId
        Logger.log("UserId explicitly set: \(userId)", level: .debug)
    }
    
    private func loadUserId() {
        Logger.log("Loading user ID from app group", level: .debug)
        
        // Run diagnostics and log the results
        let diagnosticMessage = AppGroupConstants.verifyAppGroupAccess(source: "ShareExtension")
        Logger.log(diagnosticMessage, level: .debug)
        
        // Use the shared constants
        let userDefaults = AppGroupConstants.getUserDefaults()
        
        // First check if the user is signed in
        let isSignedIn = userDefaults.bool(forKey: AppGroupConstants.UserDefaultsKeys.isSignedIn)
        Logger.log("isSignedIn value: \(isSignedIn)", level: .debug)
        
        if !isSignedIn {
            Logger.log("User is not signed in according to app group", level: .error)
            self.userId = nil
            return
        }
        
        // Get the user ID using the shared key
        if let storedUserId = userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.userId), !storedUserId.isEmpty {
            Logger.log("Loaded userId from App Group: \(storedUserId)", level: .debug)
            self.userId = storedUserId
            
            // Log the username too for context
            if let username = userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.username) {
                Logger.log("Username from App Group: \(username)", level: .debug)
            }
        } else {
            Logger.log("No userId found in App Group using key: \(AppGroupConstants.UserDefaultsKeys.userId)", level: .error)
            self.userId = nil
        }
        
        // Final status
        Logger.log("Share extension userId after loading: \(self.userId ?? "nil")", level: .debug)
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
        
        Logger.log("Determining category from URL: \(url)", level: .debug)
        
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
        default:
            // Try to determine category from path components or query parameters
            let path = url.path.lowercased()
            if path.contains("blog") || path.contains("article") {
                category = "Article"
            } else {
                category = "Uncategorized"
            }
        }
        
        Logger.log("Category determined: \(category)", level: .debug)
        return category
    }
    
    // MARK: - Process Shared URL
    func processSharedURL(_ url: URL, title: String? = nil) async -> Result<LinkResponse, LinkError> {
        Logger.log("Processing shared URL: \(url.absoluteString)", level: .debug)
        
        // Validate user authentication
        guard let userId = self.userId else {
            Logger.log("No userId available", level: .error)
            return .failure(.unauthorized)
        }
        
        Logger.log("Using userId: \(userId) to process URL", level: .debug)
        
        // Validate URL
        Logger.log("Validating URL: \(url.absoluteString)", level: .debug)
        let urlValidation = validateURL(url)
        switch urlValidation {
        case .failure(let error):
            Logger.log("URL validation failed: \(error)", level: .error)
            return .failure(error)
        case .success(let validatedURL):
            // Validate and sanitize title
            let sanitizedTitle = validateTitle(title)
            Logger.log("URL validated. Using title: \(sanitizedTitle)", level: .debug)
            
            // Determine category
            let category = determineCategoryFromURL(validatedURL)
            Logger.log("Category determined: \(category)", level: .debug)
            
            // Attempt to send link with retry logic
            var attempts = 0
            let maxAttempts = 3
            
            Logger.log("Attempting to send link to API (max attempts: \(maxAttempts))", level: .debug)
            
            while attempts < maxAttempts {
                attempts += 1
                Logger.log("Attempt #\(attempts) to send link", level: .debug)
                
                let result = await linkSender.sendLink(
                    userId: userId,
                    url: validatedURL,
                    title: sanitizedTitle,
                    category: category
                )
                
                Logger.log("Received result from attempt #\(attempts): \(result)", level: .debug)
                
                switch result {
                case .success(let response):
                    Logger.log("Success on attempt #\(attempts): \(response)", level: .debug)
                    return .success(response)
                case .failure(let error):
                    Logger.log("Error on attempt #\(attempts): \(error)", level: .error)
                    // Only retry on network errors
                    if case .networkError = error, attempts < maxAttempts {
                        Logger.log("Will retry due to network error", level: .debug)
                        // Add exponential backoff
                        try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempts)) * 1_000_000_000))
                        continue
                    }
                    Logger.log("Error is terminal, not retrying: \(error)", level: .error)
                    return .failure(error)
                }
            }
            
            Logger.log("All attempts failed. Returning network error", level: .error)
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
