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
    @Published var pendingItems: [SharedItem] = []
    @Published var isProcessing = false
    
    private let userDefaults: UserDefaults
    private let appGroupId = "group.com.yourdomain.gista"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Logger.log("Initializing SharedContentService", level: .info)
        guard let groupDefaults = UserDefaults(suiteName: AppConstants.appGroupId) else {
            Logger.error(SharedContentError.invalidAppGroup, context: "Initialization")
            fatalError("Failed to initialize app group UserDefaults")
        }
        self.userDefaults = groupDefaults
        
        // Check for shared content on initialization
        checkForSharedContent()
        
        // Setup notification observer for when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.checkForSharedContent()
            }
            .store(in: &cancellables)
    }
    
    func checkForSharedContent() {
        guard !isProcessing else { return }
        isProcessing = true
        
        guard let queue = userDefaults.array(forKey: "ShareQueue") as? [[String: Any]] else {
            isProcessing = false
            return
        }
        
        for item in queue {
            if let type = item["type"] as? String {
                switch type {
                case "url":
                    if let urlString = item["content"] as? String {
                        handleSharedURL(urlString)
                    }
                case "pdf":
                    if let filename = item["filename"] as? String {
                        handleSharedPDF(filename)
                    }
                case "text":
                    if let content = item["content"] as? String {
                        handleSharedText(content)
                    }
                default:
                    break
                }
            }
        }
        
        // Clear the queue after processing
        userDefaults.removeObject(forKey: "ShareQueue")
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
    
    private func addPendingItem(_ item: SharedItem) {
        DispatchQueue.main.async {
            self.pendingItems.append(item)
            self.notifyNewContent()
        }
    }
    
    private func notifyNewContent() {
        // Post notification for new content
        NotificationCenter.default.post(
            name: NSNotification.Name("NewSharedContentReceived"),
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
