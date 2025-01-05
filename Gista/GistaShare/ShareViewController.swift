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

// If SharedItemType isn't accessible, we can define it here
enum SharedItemType {
    case url
    case pdf
    case text
}

class ShareViewController: UIViewController {
    private var isDismissing = false
    private var processingCount = 0
    private var processedURLs = Set<String>() // Store normalized URLs
    
    private lazy var previewContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var previewImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .systemGray6
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set placeholder image
        let placeholderConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        let placeholder = UIImage(systemName: "link.circle.fill", withConfiguration: placeholderConfig)
        imageView.image = placeholder
        imageView.tintColor = .systemGray3
        
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var urlLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var createGistButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Create Gist"
        configuration.cornerStyle = .medium
        
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(createGistTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.log("ShareViewController: viewDidLoad", level: .debug)
        testAppGroupAccess()
        
        // Configure view with system background color
        view.backgroundColor = .systemBackground
        
        setupUI()
        configureNavigationBar()
        
        // Start processing shared content
        processSharedItem()
    }
    
    private func setupUI() {
        // Add preview container
        view.addSubview(previewContainer)
        
        // Add elements to container
        previewContainer.addSubview(previewImageView)
        previewContainer.addSubview(titleLabel)
        previewContainer.addSubview(urlLabel)
        previewContainer.addSubview(createGistButton)
        
        NSLayoutConstraint.activate([
            // Container constraints
            previewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            previewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            previewContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            
            // Image constraints
            previewImageView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 16),
            previewImageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 16),
            previewImageView.heightAnchor.constraint(equalToConstant: 60),
            previewImageView.widthAnchor.constraint(equalToConstant: 60),
            
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: previewImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -16),
            
            // URL constraints
            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            urlLabel.leadingAnchor.constraint(equalTo: previewImageView.trailingAnchor, constant: 12),
            urlLabel.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -16),
            
            // Button constraints
            createGistButton.topAnchor.constraint(greaterThanOrEqualTo: previewImageView.bottomAnchor, constant: 16),
            createGistButton.topAnchor.constraint(greaterThanOrEqualTo: urlLabel.bottomAnchor, constant: 16),
            createGistButton.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 16),
            createGistButton.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -16),
            createGistButton.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -16),
            createGistButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func configureNavigationBar() {
        Logger.log("ShareViewController: configuring navigation bar", level: .debug)
        // Create and configure navigation bar
        let navigationBar = UINavigationBar(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44))
        navigationBar.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        view.addSubview(navigationBar)
        
        // Create navigation item with title and cancel button
        let navigationItem = UINavigationItem(title: "Share to Gista")
        
        // Cancel button
        let cancelButton = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        
        print("ShareViewController: setting up navigation items")
        navigationItem.leftBarButtonItem = cancelButton
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
        updatePreview(for: SharedItemType.url, content: url.absoluteString)
        saveToAppGroup(["type": "url", "content": url.absoluteString])
    }
    
    private func handlePDF(_ url: URL) {
        let filename = url.lastPathComponent
        updatePreview(for: SharedItemType.pdf, content: url.path, filename: filename)
        
        if let pdfData = try? Data(contentsOf: url) {
            saveToAppGroup(["type": "pdf", "filename": filename, "size": pdfData.count])
            savePDFToSharedContainer(pdfData, filename: filename)
        }
    }
    
    private func handleText(_ text: String) {
        updatePreview(for: SharedItemType.text, content: text)
        saveToAppGroup(["type": "text", "content": text])
    }
    
    private func saveToAppGroup(_ item: [String: Any]) {
        Logger.log("Attempting to save to App Group", level: .debug)
        Logger.log("Using App Group ID: \(AppConstants.appGroupId)", level: .debug)
        Logger.log("Using ShareQueue Key: \(AppConstants.shareQueueKey)", level: .debug)
        Logger.log("Saving item: \(item)", level: .debug)
        
        guard let userDefaults = UserDefaults(suiteName: AppConstants.appGroupId) else {
            Logger.log("Failed to access App Group UserDefaults", level: .error)
            return
        }
        
        // Get existing queue or create new one
        var queue = userDefaults.array(forKey: AppConstants.shareQueueKey) as? [[String: Any]] ?? []
        Logger.log("Current queue count: \(queue.count)", level: .debug)
        
        // Add new item
        queue.append(item)
        
        // Save back to UserDefaults
        userDefaults.set(queue, forKey: AppConstants.shareQueueKey)
        userDefaults.synchronize() // Force save
        
        Logger.log("Saved item to queue. New count: \(queue.count)", level: .debug)
        
        // Verify save immediately
        if let savedQueue = userDefaults.array(forKey: AppConstants.shareQueueKey) as? [[String: Any]] {
            Logger.log("Verified save. Queue contains \(savedQueue.count) items", level: .debug)
            Logger.log("Queue contents: \(savedQueue)", level: .debug)
        } else {
            Logger.log("Failed to verify save to App Group", level: .error)
        }
        
        // Log all keys in UserDefaults
        let allKeys = userDefaults.dictionaryRepresentation().keys
        Logger.log("All UserDefaults keys after save: \(allKeys)", level: .debug)
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
    
    @objc private func createGistTapped() {
        Logger.log("Create Gist tapped", level: .debug)
        
        // Since we've already processed and saved the items during initial load,
        // we can just dismiss the extension
        doneTapped()
    }
    
    private func updatePreview(for type: SharedItemType, content: String, filename: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Configure image and labels based on type
            switch type {
            case .url:
                if let url = URL(string: content) {
                    self.titleLabel.text = url.lastPathComponent
                    self.urlLabel.text = url.host
                    
                    // Load favicon
                    if let faviconURL = URL(string: "https://www.google.com/s2/favicons?sz=128&domain=\(url.host ?? "")") {
                        URLSession.shared.dataTask(with: faviconURL) { [weak self] data, response, error in
                            if let data = data, let image = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    self?.previewImageView.image = image
                                }
                            }
                        }.resume()
                    }
                }
                
                // URL icon as placeholder
                let placeholderConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
                previewImageView.image = UIImage(systemName: "link.circle.fill", withConfiguration: placeholderConfig)
                previewImageView.tintColor = .systemGray3
                
            case .pdf:
                titleLabel.text = filename ?? "PDF Document"
                urlLabel.text = "PDF File"
                
                // PDF icon
                let placeholderConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
                previewImageView.image = UIImage(systemName: "doc.fill", withConfiguration: placeholderConfig)
                previewImageView.tintColor = .systemRed
                
            case .text:
                // Take first line as title, or truncate if no newlines
                let lines = content.components(separatedBy: .newlines)
                titleLabel.text = lines.first ?? content
                urlLabel.text = "Text Content"
                
                // Text icon
                let placeholderConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
                previewImageView.image = UIImage(systemName: "doc.text.fill", withConfiguration: placeholderConfig)
                previewImageView.tintColor = .systemBlue
            }
        }
    }
}
