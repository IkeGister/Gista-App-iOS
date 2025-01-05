//
//  SharedContentService.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import Foundation
import Combine
import UIKit
import Shared

class SharedContentService: ObservableObject {
    // Add static instance for singleton pattern
    static let shared = SharedContentService()
    
    @Published var pendingItems: [SharedItem] = []
    @Published var isProcessing = false
    
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    
    private init() {  // Make init private
        Logger.log("Initializing SharedContentService", level: .info)
        guard let groupDefaults = UserDefaults(suiteName: AppConstants.appGroupId) else {
            Logger.error(SharedContentError.invalidAppGroup, context: "Initialization")
            fatalError("Failed to initialize app group UserDefaults")
        }
        self.userDefaults = groupDefaults
        
        // Initial check for content
        checkForSharedContent()
        
        // Setup notification observer for when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Logger.log("App became active, checking for shared content", level: .debug)
                self?.checkForSharedContent()
            }
            .store(in: &cancellables)
    }
    
    private func addPendingItem(_ item: SharedItem) {
        // Check for duplicates before adding
        guard !pendingItems.contains(where: { $0.content == item.content }) else {
            Logger.log("Skipping duplicate item: \(item.content)", level: .debug)
            return
        }
        
        DispatchQueue.main.async {
            self.pendingItems.append(item)
            Logger.log("New pendingItems count: \(self.pendingItems.count)", level: .debug)
            self.notifyNewContent()
        }
    }
    
    private func testAppGroupAccess() {
        if let testValue = userDefaults.string(forKey: "testKey") {
            print("✅ Main App: Successfully read from App Group: \(testValue)")
        } else {
            print("⚠️ Main App: No test value found in App Group")
        }
    }
    
    func checkForSharedContent() {
        Logger.log("Checking for shared content", level: .debug)
        
        // Log the app group ID we're using
        Logger.log("Using App Group ID: \(AppConstants.appGroupId)", level: .debug)
        
        guard let queue = userDefaults.array(forKey: AppConstants.shareQueueKey) as? [[String: Any]] else {
            Logger.log("No shared content found or invalid format", level: .debug)
            return
        }
        
        Logger.log("Found \(queue.count) shared items", level: .debug)
        guard !isProcessing else { 
            Logger.log("Already processing items, skipping", level: .debug)
            return 
        }
        isProcessing = true
        
        for (index, item) in queue.enumerated() {
            Logger.log("Processing item \(index): \(item)", level: .debug)
            
            if let type = item["type"] as? String {
                switch type {
                case "url":
                    if let urlString = item["content"] as? String {
                        Logger.log("Handling URL: \(urlString)", level: .debug)
                        handleSharedURL(urlString)
                    }
                case "pdf":
                    if let filename = item["filename"] as? String {
                        Logger.log("Handling PDF: \(filename)", level: .debug)
                        handleSharedPDF(filename)
                    }
                case "text":
                    if let content = item["content"] as? String {
                        Logger.log("Handling text content", level: .debug)
                        handleSharedText(content)
                    }
                default:
                    Logger.log("Unknown type: \(type)", level: .debug)
                    break
                }
            }
        }
        
        Logger.log("Current pendingItems count: \(pendingItems.count)", level: .debug)
        
        // Only clear the queue if we successfully processed items
        if !pendingItems.isEmpty {
            userDefaults.removeObject(forKey: AppConstants.shareQueueKey)
            Logger.log("Cleared queue after successful processing", level: .debug)
        }
        
        isProcessing = false
    }
    
    private func handleSharedURL(_ urlString: String) {
        let sharedItem = SharedItem(
            type: .url,
            content: urlString
        )
        addPendingItem(sharedItem)
    }
    
    private func handleSharedPDF(_ filename: String) {
        guard let containerURL = FileManager.default
                    .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupId)?
                    .appendingPathComponent(AppConstants.sharedFilesDirectory)
                    .appendingPathComponent(filename) else {
            Logger.error(SharedContentError.invalidAppGroup, context: "PDF Handling")
            return
        }
        
        let sharedItem = SharedItem(
            type: .pdf,
            content: containerURL.path,
            filename: filename
        )
        addPendingItem(sharedItem)
    }
    
    private func handleSharedText(_ text: String) {
        let sharedItem = SharedItem(
            type: .text,
            content: text
        )
        addPendingItem(sharedItem)
    }
    
    private func notifyNewContent() {
        // Post notification for new content using constant
        NotificationCenter.default.post(
            name: NSNotification.Name(AppConstants.Notifications.newContentReceived),
            object: nil
        )
        
        // Create local notification
        let content = UNMutableNotificationContent()
        content.title = "New Content Added"
        content.body = "Tap to view your new content"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Public Methods
    
    func processPendingItems() {
        // Process items and convert to articles
        // This will be implemented when we add the article conversion service
    }
    
    func clearPendingItems() {
        pendingItems.removeAll()
    }
}

#if DEBUG
extension SharedContentService {
    static var preview: SharedContentService {
        let service = SharedContentService()
        
        // Add some test items
        service.pendingItems = [
            SharedItem(type: .url, content: "https://www.apple.com"),
            SharedItem(type: .text, content: "Test article content"),
            SharedItem(type: .pdf, content: "test.pdf", filename: "test.pdf")
        ]
        
        return service
    }
    
    func addTestItem() {
        Logger.log("Adding test item", level: .debug)
        let testItem = SharedItem(
            type: .url,
            content: "https://www.example.com/article-\(Date().timeIntervalSince1970)"
        )
        addPendingItem(testItem)
    }
}
#endif
