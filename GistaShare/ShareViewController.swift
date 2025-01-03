import UIKit
import Social
import UniformTypeIdentifiers
import MobileCoreServices
import Shared

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add a navigation bar with buttons
        let navigationBar = UINavigationBar(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44))
        view.addSubview(navigationBar)
        
        let navigationItem = UINavigationItem(title: "Share to Gista")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        navigationBar.items = [navigationItem]
        
        processSharedItem()
    }
    
    @objc private func cancelTapped() {
        extensionContext?.completeRequest(returningItems: nil)
    }
    
    @objc private func doneTapped() {
        processSharedItem()
    }
    
    private func processSharedItem() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }
        
        for extensionItem in extensionItems {
            guard let itemProviders = extensionItem.attachments else { continue }
            
            for provider in itemProviders {
                // Handle URLs
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (url, error) in
                        if let shareURL = url as? URL {
                            self?.handleURL(shareURL)
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
    }
    
    private func handleURL(_ url: URL) {
        saveToAppGroup(["type": "url", "content": url.absoluteString])
        completeRequest()
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
        guard let userDefaults = UserDefaults(suiteName: SharedConstants.appGroupId) else { return }
        var queue = userDefaults.array(forKey: SharedConstants.shareQueueKey) as? [[String: Any]] ?? []
        queue.append(data)
        userDefaults.set(queue, forKey: SharedConstants.shareQueueKey)
    }
    
    private func savePDFToSharedContainer(_ data: Data, filename: String) {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupId)?
            .appendingPathComponent(SharedConstants.sharedFilesDirectory) else { return }
        
        try? FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        try? data.write(to: containerURL.appendingPathComponent(filename))
    }
    
    private func completeRequest() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }
} 