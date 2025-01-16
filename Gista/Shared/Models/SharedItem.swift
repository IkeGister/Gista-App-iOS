//
//  SharedItem.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import Foundation

public enum SharedItemType {
    case url
    case pdf
    case text
}

//Review this declaration
// Move protocol conformance to the enum declaration
extension SharedItemType: CustomStringConvertible {
    public var description: String {  // Make description public
        switch self {
        case .url: return "URL"
        case .pdf: return "PDF"
        case .text: return "Text"
        }
    }
}

public struct SharedItem: Identifiable, Hashable {
    public let id: UUID
    public let type: SharedItemType
    public let content: String
    public let filename: String?
    public let dateAdded: Date
    
    public init(type: SharedItemType, content: String, filename: String? = nil) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.filename = filename
        self.dateAdded = Date()
    }
    
    // Add Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: SharedItem, rhs: SharedItem) -> Bool {
        lhs.id == rhs.id
    }
}

// Optional: Add preview data
public extension SharedItem {
    static let previews: [SharedItem] = [
        SharedItem(type: .url, content: "https://example.com", filename: "Example Link"),
        SharedItem(type: .pdf, content: "sample.pdf", filename: "Sample PDF"),
        SharedItem(type: .text, content: "Some shared text", filename: "Note")
    ]
}
