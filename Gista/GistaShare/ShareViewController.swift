//
//  ShareViewController.swift
//  GistaShare
//
//  Created by Tony Nlemadim on 1/2/25.
//

import UIKit
import Social
import UniformTypeIdentifiers
import MobileCoreServices
import Shared

class ShareViewController: UIViewController {
    private var isDismissing = false
    private var processingCount = 0
    private var processedURLs = Set<String>() // Store normalized URLs
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.log("ShareViewController: viewDidLoad", level: .debug)
        testAppGroupAccess()
        
        // Configure view with bright green background
        view.backgroundColor = .systemGreen // or .green for a more vivid color
        configureNavigationBar()
        
        // Start processing shared content
        processSharedItem()
    }
    
    private func configureNavigationBar() {
        Logger.log("ShareViewController: configuring navigation bar", level: .debug)
        // Create and configure navigation bar
        let navigationBar = UINavigationBar(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44))
        navigationBar.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        view.addSubview(navigationBar)
        
        // Create navigation item with title and buttons
        let navigationItem = UINavigationItem(title: "Share to Gista")
        
        // Cancel button
        let cancelButton = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        
        // Done button
        let doneButton = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        
        print("ShareViewController: setting up navigation items")
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = doneButton
        navigationBar.items = [navigationItem]
    }
    
    @objc private func cancelTapped() {
        Logger.log("Cancel tapped", level: .debug)
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    @objc private func doneTapped() {
        Logger.log("Done tapped", level: .debug)
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    private func processSharedItem() {
        Logger.log("Processing shared item", level: .debug)
        
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            Logger.log("No extension items found", level: .debug)
            return
        }
        
        for extensionItem in extensionItems {
            guard let itemProviders = extensionItem.attachments else { continue }
            
            for provider in itemProviders {
                processingCount += 1
                
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (url, error) in
                        guard let self = self else { return }
                        
                        if let shareURL = url as? URL {
                            // Always normalize the URL first
                            let normalizedURL = self.normalizeURL(shareURL)?.absoluteString ?? shareURL.absoluteString
                            Logger.log("Checking URL: \(normalizedURL)", level: .debug)
                            
                            // Check against normalized URLs
                            if !self.processedURLs.contains(normalizedURL) {
                                self.processedURLs.insert(normalizedURL)
                                Logger.log("Processing new URL: \(normalizedURL)", level: .debug)
                                self.handleURL(URL(string: normalizedURL)!)
                            } else {
                                Logger.log("Skipping duplicate URL: \(normalizedURL)", level: .debug)
                            }
                        }
                        self.itemProcessed()
                    }
                }
                
                if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { [weak self] (pdf, error) in
                        if let pdfURL = pdf as? URL {
                            self?.handlePDF(pdfURL)
                        }
                        self?.itemProcessed()
                    }
                }
                
                if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (text, error) in
                        if let sharedText = text as? String {
                            self?.handleText(sharedText)
                        }
                        self?.itemProcessed()
                    }
                }
            }
        }
        
        // If nothing was processed, complete
        if processingCount == 0 {
            Logger.log("No items to process", level: .debug)
            completeRequest()
        }
    }
    
    private func itemProcessed() {
        processingCount -= 1
        // Don't auto-complete, just log
        if processingCount == 0 {
            Logger.log("All items processed", level: .debug)
        }
    }
    
    private func handleURL(_ url: URL) {
        saveToAppGroup(["type": "url", "content": url.absoluteString])
    }
    
    private func handlePDF(_ url: URL) {
        if let pdfData = try? Data(contentsOf: url) {
            let filename = url.lastPathComponent
            saveToAppGroup(["type": "pdf", "filename": filename, "size": pdfData.count])
            savePDFToSharedContainer(pdfData, filename: filename)
        }
    }
    
    private func handleText(_ text: String) {
        saveToAppGroup(["type": "text", "content": text])
    }
    
    private func saveToAppGroup(_ data: [String: Any]) {
        guard let userDefaults = UserDefaults(suiteName: AppConstants.appGroupId) else { return }
        var queue = userDefaults.array(forKey: AppConstants.shareQueueKey) as? [[String: Any]] ?? []
        queue.append(data)
        userDefaults.set(queue, forKey: AppConstants.shareQueueKey)
    }
    
    private func savePDFToSharedContainer(_ data: Data, filename: String) {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupId)?
            .appendingPathComponent(AppConstants.sharedFilesDirectory) else { return }
        
        try? FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        try? data.write(to: containerURL.appendingPathComponent(filename))
    }
    
    private func completeRequest() {
        Logger.log("Completing request", level: .debug)
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    private func testAppGroupAccess() {
        guard let userDefaults = UserDefaults(suiteName: AppConstants.appGroupId) else {
            Logger.log("Share Extension: Failed to access App Group", level: .error)
            return
        }
        
        // Write a test value
        userDefaults.set("Test from Share Extension", forKey: "testKey")
        Logger.log("Share Extension: Successfully wrote to App Group", level: .debug)
    }
    
    // Optional: Add a loading indicator
    private func showLoading() {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.center = view.center
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
    }
    
    private func normalizeURL(_ url: URL) -> URL? {
        var urlString = url.absoluteString
        Logger.log("Attempting to normalize URL: \(urlString)", level: .debug)
        
        // Common mobile URL patterns with more specific replacements
        let mobilePatterns: [(pattern: String, replacement: String)] = [
            ("://m.", "://"),          // m.website.com -> website.com
            ("://en.m.", "://en."),    // en.m.website.com -> en.website.com
            ("://mobile.", "://"),      // mobile.website.com -> website.com
        ]
        
        for (pattern, replacement) in mobilePatterns {
            if urlString.contains(pattern) {
                urlString = urlString.replacingOccurrences(of: pattern, with: replacement)
                Logger.log("Normalized mobile URL: \(urlString)", level: .debug)
                return URL(string: urlString)
            }
        }
        
        Logger.log("URL already in desktop format: \(urlString)", level: .debug)
        return url
    }
}
