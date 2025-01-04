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
        var processingCount = 0
        
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            Logger.log("No extension items found", level: .debug)
            completeRequest()
            return
        }
        
        print("Found \(extensionItems.count) extension items")
        
        for extensionItem in extensionItems {
            guard let itemProviders = extensionItem.attachments else { 
                print("No attachments found")
                continue 
            }
            
            print("Processing \(itemProviders.count) providers")
            
            for provider in itemProviders {
                processingCount += 1
                
                // Handle URLs
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    print("Found URL type")
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (url, error) in
                        if let shareURL = url as? URL {
                            print("Processing URL: \(shareURL)")
                            self?.handleURL(shareURL)
                        }
                        processingCount -= 1
                        if processingCount == 0 {
                            self?.completeRequest()
                        }
                    }
                }
                
                // Handle PDFs
                if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { [weak self] (pdf, error) in
                        if let pdfURL = pdf as? URL {
                            self?.handlePDF(pdfURL)
                        }
                    }
                }
                
                // Handle text
                if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (text, error) in
                        if let sharedText = text as? String {
                            self?.handleText(sharedText)
                        }
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
    
    private func handleURL(_ url: URL) {
        saveToAppGroup(["type": "url", "content": url.absoluteString])
        // Don't call completeRequest here - let the user dismiss
    }
    
    private func handlePDF(_ url: URL) {
        if let pdfData = try? Data(contentsOf: url) {
            let filename = url.lastPathComponent
            saveToAppGroup(["type": "pdf", "filename": filename, "size": pdfData.count])
            savePDFToSharedContainer(pdfData, filename: filename)
        }
        completeRequest()
    }
    
    private func handleText(_ text: String) {
        saveToAppGroup(["type": "text", "content": text])
        completeRequest()
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
        
        // Prevent multiple dismissals
        guard !isDismissing else {
            Logger.log("Already dismissing, ignoring request", level: .debug)
            return
        }
        
        isDismissing = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            Logger.log("Attempting to dismiss extension", level: .debug)
            
            // First cancel the extension context
            self.extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: 0))
            
            // Then close the host app
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    Logger.log("Found UIApplication, suspending", level: .debug)
                    application.perform(Selector(("suspend")))
                    break
                }
                responder = responder?.next
            }
        }
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
} 
