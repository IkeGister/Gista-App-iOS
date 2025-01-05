//
//  MyResourcesView.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/5/25.
//

import SwiftUI


struct MyResourcesView: View {
    @StateObject private var sharedContentService = SharedContentService.shared
    
    var body: some View {
        NavigationStack {
            Group {
                if sharedContentService.pendingItems.isEmpty {
                    ContentUnavailableView(
                        "No Saved Resources",
                        systemImage: "link.circle",
                        description: Text("Resources you save from other apps will appear here")
                    )
                    .onAppear {
                        Logger.log("Showing empty state view", level: .debug)
                    }
                } else {
                    List(sharedContentService.pendingItems) { item in
                        SharedItemRow(item: item)
                            .onTapGesture {
                                handleItemTap(item)
                            }
                    }
                    .listStyle(.plain)
                    .onAppear {
                        Logger.log("Showing list with \(sharedContentService.pendingItems.count) items", level: .debug)
                        for (index, item) in sharedContentService.pendingItems.enumerated() {
                            Logger.log("Item \(index): type=\(item.type), content=\(item.content)", level: .debug)
                        }
                    }
                }
            }
            .navigationTitle("My Resources")
            .onAppear {
                Logger.log("MyResourcesView appeared", level: .debug)
            }
        }
    }
    
    private func handleItemTap(_ item: SharedItem) {
        Logger.log("Tapped item: type=\(item.type), content=\(item.content)", level: .debug)
        switch item.type {
        case .url:
            if let url = URL(string: item.content) {
                UIApplication.shared.open(url)
            }
        case .pdf:
            Logger.log("Opening PDF: \(item.filename ?? item.content)", level: .debug)
        case .text:
            Logger.log("Showing text content: \(item.content)", level: .debug)
        }
    }
}

struct SharedItemRow: View {
    let item: SharedItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on item type
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: iconName)
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(item.type.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(item.dateAdded.relativeFormatted())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch item.type {
        case .url:
            return "link"
        case .pdf:
            return "doc.fill"
        case .text:
            return "doc.text"
        }
    }
    
    private var displayTitle: String {
        if let filename = item.filename {
            return filename
        }
        // For URLs, try to get the last path component or just show the content
        if item.type == .url, let url = URL(string: item.content) {
            return url.lastPathComponent
        }
        // For text, show first line or truncated content
        return item.content.components(separatedBy: .newlines).first ?? item.content
    }
}
