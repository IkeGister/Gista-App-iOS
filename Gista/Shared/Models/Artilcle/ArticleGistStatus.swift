//
//  ArticleGistStatus.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//


import SwiftUI
import Foundation

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