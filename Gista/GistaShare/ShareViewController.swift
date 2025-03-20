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
    
    // Add loading state
    private var isLoading = false {
        didSet {
            updateLoadingState()
        }
    }
    
    // Add loading indicator
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // Add error label
    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .systemRed
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Add view model property
    private lazy var viewModel = ShareViewControllerVM()
    
    // Current shared URL and title
    private var currentURL: URL?
    private var currentTitle: String?
    
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
    
    private lazy var createGistButton: UIView = {
        print("Creating entirely new button implementation using UIView + Gesture")
        
        // Create a container view
        let container = UIView()
        container.backgroundColor = .systemBlue
        container.layer.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Add a label
        let label = UILabel()
        label.text = "Create Gist"
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(label)
        
        // Constrain the label
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(createGistViewTapped))
        container.addGestureRecognizer(tapGesture)
        container.isUserInteractionEnabled = true
        
        print("✅ Created button with tap gesture")
        
        return container
    }()
    
    @objc func createGistViewTapped(_ gesture: UITapGestureRecognizer) {
        print("⚡️⚡️⚡️ VIEW TAPPED GESTURE ⚡️⚡️⚡️")
        print("⚡️⚡️⚡️ LOCATION: \(gesture.location(in: view)) ⚡️⚡️⚡️")
        createGistTapped()
    }
    
    @objc func createGistTappedTraditional() {
        print("📱📱📱 TRADITIONAL BUTTON TAPPED 📱📱📱")
        // Forward to the original method
        createGistTapped()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.log("ShareViewController: viewDidLoad", level: .debug)
        
        // Add a debug button at the top of the view
        let debugButton = UIButton(type: .system)
        debugButton.setTitle("Debug Tap", for: .normal)
        debugButton.backgroundColor = .systemPurple
        debugButton.setTitleColor(.white, for: .normal)
        debugButton.addTarget(self, action: #selector(createGistTapped), for: .touchUpInside)
        debugButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(debugButton)
        
        NSLayoutConstraint.activate([
            debugButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            debugButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            debugButton.widthAnchor.constraint(equalToConstant: 100),
            debugButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        print("Added debug button at top of view")
        
        // Add detailed user credential diagnostics
        if let userDefaults = UserDefaults(suiteName: AppConstants.appGroupId) {
            Logger.log("🔑 SHARE EXTENSION - USER CHECK", level: .debug)
            Logger.log("App Group ID: \(AppConstants.appGroupId)", level: .debug)
            
            // Check if user is signed in
            let isSignedIn = userDefaults.bool(forKey: AppGroupConstants.UserDefaultsKeys.isSignedIn)
            Logger.log("Is Signed In: \(isSignedIn)", level: .debug)
            
            // Check user ID
            if let userId = userDefaults.string(forKey: "userId") {
                Logger.log("User ID from app group: \(userId)", level: .debug)
                // Validate format
                if userId.contains("_") {
                    Logger.log("User ID appears to be in valid format (contains underscore)", level: .debug)
                    
                    // Manually force the userId into our viewModel for reliability
                    print("🔐 MANUALLY SETTING USERID IN VIEWMODEL: \(userId)")
                    viewModel.setUserId(userId)
                } else {
                    Logger.log("⚠️ WARNING: User ID is not in expected format: \(userId)", level: .debug)
                }
            } else {
                Logger.log("❌ ERROR: No user ID found in app group", level: .debug)
            }
            
            // Check username and email
            if let username = userDefaults.string(forKey: "username") {
                Logger.log("Username from app group: \(username)", level: .debug)
            }
            if let email = userDefaults.string(forKey: "userEmail") {
                Logger.log("Email from app group: \(email)", level: .debug)
            }
            
            // Dump all user-related keys for debugging
            let allKeys = userDefaults.dictionaryRepresentation().keys
            let userKeys = allKeys.filter { $0.starts(with: "user") || $0 == AppGroupConstants.UserDefaultsKeys.isSignedIn }
            Logger.log("All user-related keys in app group: \(userKeys)", level: .debug)
        } else {
            Logger.log("❌ ERROR: Could not access app group UserDefaults", level: .debug)
        }
        
        testAppGroupAccess()
        
        // Log diagnostic information about app group and user credentials
        let diagnosticMessage = AppGroupConstants.verifyAppGroupAccess(source: "ShareExtension-viewDidLoad")
        Logger.log(diagnosticMessage, level: .debug)
        
        // Configure view with system background color
        view.backgroundColor = .systemBackground
        
        setupUI()
        configureNavigationBar()
        
        // Start processing shared content
        processSharedItem()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("📱📱📱 SHARE EXTENSION VIEW DID APPEAR 📱📱📱")
        Logger.log("ShareViewController: viewDidAppear - View is now visible to the user", level: .debug)
        
        // Add emergency tap gesture to the whole preview container
        let emergencyTap = UITapGestureRecognizer(target: self, action: #selector(emergencyTapHandler(_:)))
        emergencyTap.numberOfTapsRequired = 3 // Triple tap to avoid accidental triggers
        previewContainer.addGestureRecognizer(emergencyTap)
        previewContainer.isUserInteractionEnabled = true
        
        print("Added emergency triple-tap gesture to preview container")
        
        // Log details about current URL and button state
        if let currentURL = currentURL {
            print("Current URL ready for processing: \(currentURL)")
        } else {
            print("No URL available yet for processing")
        }
        
        print("Create Gist button state - enabled: \(createGistButton.isUserInteractionEnabled), hidden: \(createGistButton.isHidden)")
    }
    
    @objc func emergencyTapHandler(_ gesture: UITapGestureRecognizer) {
        print("🚨🚨🚨 EMERGENCY TAP DETECTED 🚨🚨🚨")
        
        // Double check all user defaults values
        let userDefaults = AppGroupConstants.getUserDefaults()
        let isSignedIn = userDefaults.bool(forKey: AppGroupConstants.UserDefaultsKeys.isSignedIn) 
        let userId = userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.userId) ?? "nil"
        let username = userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.username) ?? "nil"
        
        print("APP GROUP VALUES:")
        print("- isSignedIn: \(isSignedIn)")
        print("- userId: \(userId)")
        print("- username: \(username)")
        
        // Force update the view model and attempt the process
        if userId != "nil" {
            viewModel.setUserId(userId)
            print("🚨 FORCING userId: \(userId) into viewModel")
            
            if let currentURL = currentURL {
                print("🚨 FORCING PROCESS URL: \(currentURL)")
                createGistTapped()
            } else {
                showError(message: "Emergency: No URL available")
            }
        } else {
            showError(message: "Emergency: No user ID in app group")
        }
    }
    
    private func setupUI() {
        print("Setting up UI for ShareViewController")
        // Add preview container
        view.addSubview(previewContainer)
        
        // Add elements to container
        previewContainer.addSubview(previewImageView)
        previewContainer.addSubview(titleLabel)
        previewContainer.addSubview(urlLabel)
        previewContainer.addSubview(createGistButton)
        previewContainer.addSubview(loadingIndicator)
        previewContainer.addSubview(errorLabel)
        
        print("Create Gist button setup - configuring gesture recognizers")
        
        // Clear any existing gesture recognizers
        if let existingGestures = createGistButton.gestureRecognizers {
            for gesture in existingGestures {
                createGistButton.removeGestureRecognizer(gesture)
            }
        }
        
        // Add our tap gesture (this will be our primary action)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(createGistViewTapped))
        tapGesture.numberOfTapsRequired = 1
        
        // Also add a direct handler for the main createGistTapped method
        let mainTapGesture = UITapGestureRecognizer(target: self, action: #selector(createGistTapped))
        mainTapGesture.numberOfTapsRequired = 1
        
        // Add both gesture recognizers
        createGistButton.addGestureRecognizer(tapGesture)
        createGistButton.addGestureRecognizer(mainTapGesture)
        
        print("Added two gesture recognizers to button:")
        print("1. Tap to createGistViewTapped - debug version")
        print("2. Tap to createGistTapped - direct version")
        
        // Ensure view is ready to receive touches
        createGistButton.isUserInteractionEnabled = true
        createGistButton.isHidden = false
        createGistButton.alpha = 1.0
        
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
            createGistButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Loading indicator constraints
            loadingIndicator.centerYAnchor.constraint(equalTo: createGistButton.centerYAnchor),
            loadingIndicator.trailingAnchor.constraint(equalTo: createGistButton.leadingAnchor, constant: -8),
            
            // Error label constraints
            errorLabel.topAnchor.constraint(equalTo: createGistButton.bottomAnchor, constant: 8),
            errorLabel.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -16),
            errorLabel.bottomAnchor.constraint(lessThanOrEqualTo: previewContainer.bottomAnchor, constant: -16)
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
        // Store the current URL and title for later use
        currentURL = url
        currentTitle = url.lastPathComponent
        
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
    
    private func updateLoadingState() {
        print("Updating loading state: isLoading = \(isLoading)")
        if isLoading {
            loadingIndicator.startAnimating()
            createGistButton.isUserInteractionEnabled = false
            createGistButton.alpha = 0.5
            
            // For a UIView button, we need to find the label and update its text
            if let label = createGistButton.subviews.first as? UILabel {
                label.text = "Processing..."
            }
        } else {
            loadingIndicator.stopAnimating()
            createGistButton.isUserInteractionEnabled = true
            createGistButton.alpha = 1.0
            
            // For a UIView button, we need to find the label and update its text
            if let label = createGistButton.subviews.first as? UILabel {
                label.text = "Create Gist"
            }
        }
    }
    
    private func showError(message: String) {
        print("❌❌❌ SHOWING ERROR: \(message) ❌❌❌")
        Logger.log("SHOWING ERROR: \(message)", level: .error)
        
        // Show error in the UI
        DispatchQueue.main.async {
            // Make sure error label is properly styled
            self.errorLabel.text = message
            self.errorLabel.textColor = .systemRed
            self.errorLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            self.errorLabel.layer.cornerRadius = 8
            self.errorLabel.clipsToBounds = true
            self.errorLabel.isHidden = false
            self.errorLabel.alpha = 1.0
            
            // Also show alert for good measure
            let alert = UIAlertController(
                title: "Error",
                message: message,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            print("Presenting error alert")
            self.present(alert, animated: true) {
                print("Error alert presented")
            }
            
            // Reset loading state
            self.isLoading = false
            self.updateLoadingState()
        }
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
        print("CREATE GIST BUTTON TAPPED - Direct print")
        print("-----------------------------------------------------")
        print("🔵🔵🔵 STARTING GIST CREATION PROCESS 🔵🔵🔵")
        print("-----------------------------------------------------")
        
        Logger.log("CREATE GIST BUTTON TAPPED - BEGIN", level: .debug)
        
        // Check for user authentication first
        let userDefaults = AppGroupConstants.getUserDefaults()
        let isSignedIn = userDefaults.bool(forKey: AppGroupConstants.UserDefaultsKeys.isSignedIn)
        let userId = userDefaults.string(forKey: AppGroupConstants.UserDefaultsKeys.userId) ?? ""
        
        print("Auth check - isSignedIn: \(isSignedIn), userId: \(userId)")
        Logger.log("Auth check - isSignedIn: \(isSignedIn), userId: \(userId)", level: .debug)
        
        // Force the userId into the viewModel
        if !userId.isEmpty {
            print("Force setting userId in viewModel: \(userId)")
            viewModel.setUserId(userId)
        }
        
        guard isSignedIn && !userId.isEmpty else {
            print("Authentication failed - showing error")
            Logger.log("Authentication failed - showing error", level: .debug)
            // Show sign-in required error
            showError(message: "Please sign in to Gista before using this feature")
            return
        }
        
        guard let currentURL = currentURL else {
            print("No URL available to create gist")
            Logger.log("No URL available to create gist", level: .error)
            showError(message: "No URL found to process")
            return
        }
        
        // Double check URL is valid
        print("Double checking URL validity: \(currentURL.absoluteString)")
        guard currentURL.scheme != nil, !currentURL.absoluteString.isEmpty else {
            print("URL is invalid")
            showError(message: "Invalid URL format")
            return
        }
        
        // Start loading animation
        print("Starting loading animation, URL: \(currentURL)")
        Logger.log("Starting loading animation, URL: \(currentURL)", level: .debug)
        
        isLoading = true
        DispatchQueue.main.async {
            self.updateLoadingState()
        }
        
        // Process URL using view model
        print("Creating Task to process URL")
        Logger.log("Creating Task to process URL", level: .debug)
        
        Task {
            do {
                print("Inside Task - about to call viewModel.processSharedURL")
                Logger.log("Inside Task - about to call viewModel.processSharedURL", level: .debug)
                
                let result = await viewModel.processSharedURL(currentURL, title: currentTitle)
                
                print("Task completed with result: \(result)")
                Logger.log("Task completed with result: \(result)", level: .debug)
                
                // Update UI on main thread
                await MainActor.run {
                    print("On MainActor - updating UI")
                    Logger.log("On MainActor - updating UI", level: .debug)
                    isLoading = false
                    
                    switch result {
                    case .success(let response):
                        print("Success: \(response)")
                        Logger.log("Link sent successfully: \(response)", level: .debug)
                        showSuccessAndDismiss()
                    case .failure(let error):
                        print("Failure: \(error)")
                        Logger.log("Failed to send link: \(error)", level: .error)
                        switch error {
                        case .unauthorized:
                            showError(message: "Please sign in to Gista before using this feature")
                        case .networkError:
                            showError(message: "Network error. Please try again.")
                        case .apiError(_, let message):
                            showError(message: message)
                        default:
                            showError(message: "Failed to process URL: \(error.localizedDescription)")
                        }
                    }
                }
            } catch {
                print("❌❌❌ CRITICAL ERROR in Task: \(error)")
                
                await MainActor.run {
                    isLoading = false
                    showError(message: "Critical error: \(error.localizedDescription)")
                }
            }
        }
        
        print("-----------------------------------------------------")
        print("🔵🔵🔵 TASK CREATED FOR GIST PROCESSING 🔵🔵🔵")
        print("-----------------------------------------------------")
    }
    
    private func showSuccessAndDismiss() {
        print("📱📱📱 SHOWING SUCCESS ALERT 📱📱📱")
        Logger.log("SHOWING SUCCESS ALERT", level: .debug)
        
        // Create alert
        let alert = UIAlertController(
            title: "Success",
            message: "Gist has been queued for production",
            preferredStyle: .alert
        )
        
        // Add OK button
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            print("📱📱📱 SUCCESS ALERT OK BUTTON TAPPED 📱📱📱")
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        })
        
        print("📱📱📱 PRESENTING SUCCESS ALERT 📱📱📱")
        present(alert, animated: true) {
            print("📱📱📱 SUCCESS ALERT PRESENTED 📱📱📱")
        }
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
