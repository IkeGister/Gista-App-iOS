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
public struct ArticleGistStatus: Codable {
    public let gistCreated: Bool
    public let gistId: String?
    public let imageUrl: String?
    public let articleId: String
    public let title: String
    public let type: String
    public let url: String
    
    public init(
        gistCreated: Bool,
        gistId: String?,
        imageUrl: String?,
        articleId: String,
        title: String,
        type: String,
        url: String
    ) {
        self.gistCreated = gistCreated
        self.gistId = gistId
        self.imageUrl = imageUrl
        self.articleId = articleId
        self.title = title
        self.type = type
        self.url = url
    }
    
    enum CodingKeys: String, CodingKey {
        case gistCreated = "gist_created"
        case gistId = "gist_id"
        case imageUrl = "image_url"
        case articleId = "link_id"
        case title = "link_title"
        case type = "link_type"
        case url
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode gistCreated directly
        if let gistCreatedValue = try? container.decode(Bool.self, forKey: .gistCreated) {
            gistCreated = gistCreatedValue
        } else {
            // Default to true if we can't decode it but we have other fields
            // This handles the case where the API doesn't include gist_created field
            // but we know it's true because we have a gist_id
            gistCreated = true
        }
        
        gistId = try container.decodeIfPresent(String.self, forKey: .gistId)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        
        // For required fields, provide fallbacks if they're missing
        if let id = try? container.decode(String.self, forKey: .articleId) {
            articleId = id
        } else {
            articleId = UUID().uuidString
            print("Warning: Missing articleId in ArticleGistStatus, using generated UUID")
        }
        
        if let titleValue = try? container.decode(String.self, forKey: .title) {
            title = titleValue
        } else {
            title = "Unknown Title"
            print("Warning: Missing title in ArticleGistStatus, using default")
        }
        
        if let typeValue = try? container.decode(String.self, forKey: .type) {
            type = typeValue
        } else {
            type = "Web"
            print("Warning: Missing type in ArticleGistStatus, using default")
        }
        
        if let urlValue = try? container.decode(String.self, forKey: .url) {
            url = urlValue
        } else {
            url = "https://example.com"
            print("Warning: Missing url in ArticleGistStatus, using default")
        }
    }
    
    // Add a static method to create from a JSON object
    static func from(json: [String: JSON]) -> ArticleGistStatus {
        let gistCreated = json["gist_created"]?.boolValue ?? true
        let gistId = json["gist_id"]?.stringValue
        let imageUrl = json["image_url"]?.stringValue
        let articleId = json["link_id"]?.stringValue ?? UUID().uuidString
        let title = json["link_title"]?.stringValue ?? "Unknown Title"
        let type = json["link_type"]?.stringValue ?? "Web"
        let url = json["url"]?.stringValue ?? "https://example.com"
        
        return ArticleGistStatus(
            gistCreated: gistCreated,
            gistId: gistId,
            imageUrl: imageUrl,
            articleId: articleId,
            title: title,
            type: type,
            url: url
        )
    }
}

// MARK: - API Models
struct ArticleResponse: Codable {
    let message: String
    let link: LinkData
    
    struct LinkData: Codable {
        let category: String
        let dateAdded: Date?
        let gistCreated: ArticleGistStatus
        
        enum CodingKeys: String, CodingKey {
            case category
            case dateAdded = "date_added"
            case gistCreated = "gist_created"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Decode category
            category = try container.decode(String.self, forKey: .category)
            
            // Try to decode dateAdded, but use current date if missing
            if let dateString = try? container.decode(String.self, forKey: .dateAdded),
               let date = ISO8601DateFormatter().date(from: dateString) {
                dateAdded = date
            } else {
                dateAdded = nil
            }
            
            // Get the raw value for gistCreated
            do {
                // Try to decode the gistCreated field as a nested object with proper types
                let nestedContainer = try container.nestedContainer(keyedBy: GistCreatedKeys.self, forKey: .gistCreated)
                
                // Extract values with proper types
                let gistCreatedBool = try nestedContainer.decodeIfPresent(Bool.self, forKey: .gistCreated) ?? false
                let gistId = try nestedContainer.decodeIfPresent(String.self, forKey: .gistId)
                let imageUrl = try nestedContainer.decodeIfPresent(String.self, forKey: .imageUrl)
                let linkId = try nestedContainer.decodeIfPresent(String.self, forKey: .linkId) ?? UUID().uuidString
                let linkTitle = try nestedContainer.decodeIfPresent(String.self, forKey: .linkTitle) ?? "Unknown Title"
                let linkType = try nestedContainer.decodeIfPresent(String.self, forKey: .linkType) ?? "Web"
                let url = try nestedContainer.decodeIfPresent(String.self, forKey: .url) ?? "https://example.com"
                
                // Create the ArticleGistStatus with the extracted values
                gistCreated = ArticleGistStatus(
                    gistCreated: gistCreatedBool,
                    gistId: gistId,
                    imageUrl: imageUrl,
                    articleId: linkId,
                    title: linkTitle,
                    type: linkType,
                    url: url
                )
                print("Successfully decoded gistCreated as nested object")
            } catch {
                print("Error decoding gistCreated as nested object: \(error)")
                
                // Try to decode as a dictionary of AnyDecodable
                do {
                    if let gistCreatedDict = try? container.decode([String: AnyDecodable].self, forKey: .gistCreated) {
                        // Extract values from the dictionary
                        let gistCreatedBool = (gistCreatedDict["gist_created"]?.value as? Bool) ?? false
                        let gistId = gistCreatedDict["gist_id"]?.value as? String
                        let imageUrl = gistCreatedDict["image_url"]?.value as? String
                        let linkId = (gistCreatedDict["link_id"]?.value as? String) ?? UUID().uuidString
                        let linkTitle = (gistCreatedDict["link_title"]?.value as? String) ?? "Unknown Title"
                        let linkType = (gistCreatedDict["link_type"]?.value as? String) ?? "Web"
                        let url = (gistCreatedDict["url"]?.value as? String) ?? "https://example.com"
                        
                        // Create the ArticleGistStatus with the extracted values
                        gistCreated = ArticleGistStatus(
                            gistCreated: gistCreatedBool,
                            gistId: gistId,
                            imageUrl: imageUrl,
                            articleId: linkId,
                            title: linkTitle,
                            type: linkType,
                            url: url
                        )
                        print("Successfully created gistCreated from dictionary")
                    } else {
                        throw DecodingError.dataCorrupted(DecodingError.Context(
                            codingPath: container.codingPath + [CodingKeys.gistCreated],
                            debugDescription: "Failed to decode gistCreated as dictionary"
                        ))
                    }
                } catch {
                    print("Error decoding gistCreated as dictionary: \(error)")
                    
                    // Create a fallback ArticleGistStatus with default values
                    gistCreated = ArticleGistStatus(
                        gistCreated: false,
                        gistId: nil,
                        imageUrl: nil,
                        articleId: UUID().uuidString,
                        title: "Unknown Title",
                        type: "Web",
                        url: "https://example.com"
                    )
                    print("Created fallback gistCreated")
                }
            }
        }
        
        // Define nested keys for gistCreated
        enum GistCreatedKeys: String, CodingKey {
            case gistCreated = "gist_created"
            case gistId = "gist_id"
            case imageUrl = "image_url"
            case linkId = "link_id"
            case linkTitle = "link_title"
            case linkType = "link_type"
            case url
        }
    }
}

struct ArticlesResponse: Codable {
    let articles: [ArticleResponse.LinkData]
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
    init(from response: ArticleResponse) {
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
    init(from linkData: ArticleResponse.LinkData) {
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


