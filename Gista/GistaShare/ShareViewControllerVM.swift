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
    private func loadUserId() {
        // Run diagnostics and log the results
        let diagnosticMessage = AppGroupConstants.verifyAppGroupAccess(source: "ShareExtension")
        Logger.log(diagnosticMessage, level: .debug)
        
        // Use the shared constants
        let userDefaults = AppGroupConstants.getUserDefaults()
        
        // Get the user ID using the shared key
        if let storedUserId = userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.userId), !storedUserId.isEmpty {
            Logger.log("Loaded userId from App Group: \(storedUserId)", level: .debug)
            
            // Verify the format if we expect "username_UUID"
            if storedUserId.contains("_") {
                self.userId = storedUserId
                Logger.log("User ID appears to be in expected format", level: .debug)
            } else {
                Logger.log("Warning: User ID found but not in expected format (username_UUID): \(storedUserId)", level: .warning)
                self.userId = storedUserId // Still use it, but log the warning
            }
        } else {
            Logger.log("No userId found in App Group or it was empty", level: .error)
            // Don't set a default userId in production - require proper authentication
        }
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
        
        // Add more sophisticated category detection logic
        switch host {
        case _ where host.contains("github"):
            return "Development"
        case _ where host.contains("stackoverflow"):
            return "Development"
        case _ where host.contains("medium"):
            return "Article"
        case _ where host.contains("youtube"):
            return "Video"
        case _ where host.contains("twitter") || host.contains("x.com"):
            return "Social"
        default:
            // Try to determine category from path components or query parameters
            let path = url.path.lowercased()
            if path.contains("blog") || path.contains("article") {
                return "Article"
            }
            return "Uncategorized"
        }
    }
    
    // MARK: - Process Shared URL
    func processSharedURL(_ url: URL, title: String? = nil) async -> Result<LinkResponse, LinkError> {
        // Validate user authentication
        guard let userId = self.userId else {
            Logger.log("No userId available", level: .error)
            return .failure(.unauthorized)
        }
        
        // Check if userId looks like a valid UUID
        if UUID(uuidString: userId) == nil && !userId.hasPrefix("test_") {
            Logger.log("User ID format is not valid: \(userId)", level: .error)
            return .failure(.unauthorized)
        }
        
        // Validate URL
        let urlValidation = validateURL(url)
        switch urlValidation {
        case .failure(let error):
            return .failure(error)
        case .success(let validatedURL):
            // Validate and sanitize title
            let sanitizedTitle = validateTitle(title)
            
            // Determine category
            let category = determineCategoryFromURL(validatedURL)
            
            // Attempt to send link with retry logic
            var attempts = 0
            let maxAttempts = 3
            
            while attempts < maxAttempts {
                attempts += 1
                
                let result = await linkSender.sendLink(
                    userId: userId,
                    url: validatedURL,
                    title: sanitizedTitle,
                    category: category
                )
                
                switch result {
                case .success(let response):
                    return .success(response)
                case .failure(let error):
                    // Only retry on network errors
                    if case .networkError = error, attempts < maxAttempts {
                        // Add exponential backoff
                        try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempts)) * 1_000_000_000))
                        continue
                    }
                    return .failure(error)
                }
            }
            
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
