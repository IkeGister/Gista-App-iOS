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
    
    // MARK: - Initialization
    init(linkSender: LinkSender = LinkSender()) {
        self.linkSender = linkSender
        // Try to load userId from UserDefaults or keychain in a real implementation
        loadUserId()
    }
    
    // MARK: - User ID Management
    private func loadUserId() {
        // In a real implementation, this would load from secure storage
        // For now, we'll check if there's a userId in the app group UserDefaults
        guard let userDefaults = UserDefaults(suiteName: ShareExtensionConstants.appGroupId) else {
            Logger.log("Failed to access App Group UserDefaults", level: .error)
            return
        }
        
        if let storedUserId = userDefaults.string(forKey: "userId") {
            Logger.log("Loaded userId from App Group: \(storedUserId)", level: .debug)
            self.userId = storedUserId
        } else {
            // For testing purposes only - in production, you'd require proper authentication
            Logger.log("No userId found in App Group, using default test ID", level: .warning)
            self.userId = "test_user_id" // Replace with your test user ID
        }
    }
    
    // MARK: - Process Shared URL
    func processSharedURL(_ url: URL, title: String? = nil) async -> Result<LinkResponse, Error> {
        // Extract title from URL if not provided
        let urlTitle = title ?? url.lastPathComponent
        
        // Determine category based on URL or default to "Uncategorized"
        let category = determineCategoryFromURL(url)
        
        // Send the link
        guard let userId = self.userId else {
            Logger.log("No userId available", level: .error)
            return .failure(LinkError.unauthorized)
        }
        
        // Map the specific LinkSender.LinkError to the more general Error type
        let result = await linkSender.sendLink(userId: userId, url: url, title: urlTitle, category: category)
        switch result {
        case .success(let response):
            return .success(response)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // Helper method to determine category from URL
    private func determineCategoryFromURL(_ url: URL) -> String {
        return "Uncategorized"
    }
}
