//
//  SharedItem.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import Foundation

enum SharedItemType {
    case url
    case pdf
    case text
}

struct SharedItem: Identifiable, Hashable {
    let id: UUID
    let type: SharedItemType
    let content: String
    let filename: String?
    let dateAdded: Date
    
    init(type: SharedItemType, content: String, filename: String? = nil) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.filename = filename
        self.dateAdded = Date()
    }
    
    // Add Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SharedItem, rhs: SharedItem) -> Bool {
        lhs.id == rhs.id
    }
}

// Make SharedItemType conform to String representable
extension SharedItemType: CustomStringConvertible {
    var description: String {
        switch self {
        case .url: return "URL"
        case .pdf: return "PDF"
        case .text: return "Text"
        }
    }
}

