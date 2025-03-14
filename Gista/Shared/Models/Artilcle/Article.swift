//
//  Article.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/16/25.
//

import SwiftUI
import Foundation

// MARK: - Helper Types
struct AnyDecodable: Decodable {
    let value: Any
    
    init(value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyDecodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyDecodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
        }
    }
}

// MARK: - JSON Helper
enum JSON: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSON])
    case array([JSON])
    case null
    
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
    
    var intValue: Int? {
        if case .int(let value) = self {
            return value
        }
        return nil
    }
    
    var doubleValue: Double? {
        if case .double(let value) = self {
            return value
        }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }
    
    var objectValue: [String: JSON]? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }
    
    var arrayValue: [JSON]? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }
    
    subscript(key: String) -> JSON? {
        if case .object(let dict) = self {
            return dict[key]
        }
        return nil
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSON].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSON].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode JSON")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - Main Article Model
public struct Article: Identifiable {
    public let id: UUID
    public let title: String
    public let url: URL
    public let dateAdded: Date
    public let duration: Int // in seconds
    public let category: String
    public var gistStatus: ArticleGistStatus?
    
    public init(id: UUID = UUID(),
                title: String,
                url: URL,
                dateAdded: Date = Date(),
                duration: Int,
                category: String = "Uncategorized",
                gistStatus: ArticleGistStatus? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.dateAdded = dateAdded
        self.duration = duration
        self.category = category
        self.gistStatus = gistStatus
    }
}

// MARK: - Core Supporting Types


// MARK: - API Models


struct ArticlesResponse: Codable {
    let articles: [ArticleData.LinkData]
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case articles = "links"
        case count
    }
}

public struct ArticleRequest: Codable {
    let userId: String
    let article: ArticleData
    let autoCreateGist: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case article = "link"
        case autoCreateGist = "auto_create_gist"
    }
    
    struct ArticleData: Codable {
        let category: String
        let url: String
        let title: String
    }
    
    init(userId: String, article: ArticleData, autoCreateGist: Bool = true) {
        self.userId = userId
        self.article = article
        self.autoCreateGist = autoCreateGist
    }
}

// MARK: - API Conversion
extension Article {
    // Convert from API Response to Article
    init(from response: ArticleData) {
        self.init(
            id: UUID(),
            title: response.link.gistCreated.title,
            url: URL(string: response.link.gistCreated.url)!,
            dateAdded: response.link.dateAdded ?? Date(),
            duration: 0,
            category: response.link.category,
            gistStatus: response.link.gistCreated
        )
    }
    
    // For direct conversion from LinkData
    init(from linkData: ArticleData.LinkData) {
        self.init(
            id: UUID(),
            title: linkData.gistCreated.title,
            url: URL(string: linkData.gistCreated.url)!,
            dateAdded: linkData.dateAdded ?? Date(),
            duration: 0,
            category: linkData.category,
            gistStatus: linkData.gistCreated
        )
    }
    
    // Convert to API Request
    func toArticleRequest(userId: String, autoCreateGist: Bool = true) -> ArticleRequest {
        ArticleRequest(
            userId: userId,
            article: ArticleRequest.ArticleData(
                category: category,
                url: url.absoluteString,
                title: title
            ),
            autoCreateGist: autoCreateGist
        )
    }
}

// MARK: - Preview Data
public extension Article {
    static let articlePreviews: [Article] = [
        Article(
            title: "SwiftUI Best Practices",
            url: URL(string: "https://example.com/swiftui")!,
            duration: 300,
            category: "Technology"
        ),
        Article(
            title: "Market Analysis",
            url: URL(string: "https://example.com/market")!,
            duration: 240,
            category: "Business"
        )
    ]
}


