//
//  TestShareView.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

#if DEBUG
import SwiftUI
import SafariServices

struct TestShareView: View {
    @EnvironmentObject private var sharedContentService: SharedContentService
    @State private var showingSafari = false
    @State private var testURL = "https://www.apple.com"
    @State private var testText = "This is a test article content"
    
    var body: some View {
        List {
            Section("Quick Tests") {
                Button("Add Sample URL") {
                    Logger.log("Adding sample URL", level: .debug)
                    sharedContentService.addTestItem()
                }
                
                Button("Clear All Items") {
                    Logger.log("Clearing all items", level: .info)
                    sharedContentService.clearPendingItems()
                }
            }
            
            Section("Custom Tests") {
                VStack(alignment: .leading) {
                    TextField("Test URL", text: $testURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    
                    HStack {
                        Button("Test in Safari") {
                            showingSafari.toggle()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Add as URL") {
                            addCustomURL()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 4)
                }
                
                VStack(alignment: .leading) {
                    TextField("Test Text", text: $testText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    
                    Button("Add as Text") {
                        addCustomText()
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
            }
            
            Section("Error Testing") {
                Button("Simulate App Group Error") {
                    Logger.error(SharedContentError.invalidAppGroup, context: "Test")
                }
                
                Button("Simulate File Access Error") {
                    Logger.error(SharedContentError.fileAccessError, context: "Test")
                }
                
                Button("Simulate Invalid Content") {
                    Logger.error(SharedContentError.invalidContent, context: "Test")
                }
            }
            
            Section("Pending Items (\(sharedContentService.pendingItems.count))") {
                if sharedContentService.pendingItems.isEmpty {
                    Text("No pending items")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(sharedContentService.pendingItems, id: \.id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.content)
                                .font(.headline)
                                .lineLimit(2)
                            
                            HStack {
                                Label(
                                    item.type.description,
                                    systemImage: iconName(for: item.type)
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(item.dateAdded.relativeFormatted())
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .navigationTitle("Share Testing")
        .sheet(isPresented: $showingSafari) {
            if let url = URL(string: testURL) {
                SafariView(url: url)
            }
        }
    }
    
    private func addCustomURL() {
        guard let url = URL(string: testURL) else {
            Logger.log("Invalid URL format", level: .warning)
            return
        }
        
        let item = SharedItem(
            type: .url,
            content: url.absoluteString
        )
        
        Logger.log("Adding custom URL: \(url.absoluteString)", level: .debug)
        sharedContentService.pendingItems.append(item)
    }
    
    private func addCustomText() {
        let item = SharedItem(
            type: .text,
            content: testText
        )
        
        Logger.log("Adding custom text", level: .debug)
        sharedContentService.pendingItems.append(item)
    }
    
    private func deleteItems(at offsets: IndexSet) {
        sharedContentService.pendingItems.remove(atOffsets: offsets)
    }
    
    private func iconName(for type: SharedItemType) -> String {
        switch type {
        case .url:
            return "link"
        case .pdf:
            return "doc.fill"
        case .text:
            return "doc.text"
        }
    }
}

// Safari View for testing URLs
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

// Preview
struct TestShareView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TestShareView()
                .environmentObject(SharedContentService.preview)
        }
    }
}
#endif

