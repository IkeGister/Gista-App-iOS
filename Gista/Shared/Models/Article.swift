//
//  Article.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/16/25.
//

import SwiftUI
import Foundation

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
}

// MARK: - API Models
struct ArticleResponse: Codable {
    let category: String
    let dateAdded: Date
    let gistCreated: ArticleGistStatus
    
    enum CodingKeys: String, CodingKey {
        case category
        case dateAdded = "date_added"
        case gistCreated = "gist_created"
    }
}

struct ArticlesResponse: Codable {
    let articles: [ArticleResponse]
    let count: Int
    
    enum CodingKeys: String, CodingKey {
        case articles = "links"
        case count
    }
}

public struct ArticleRequest: Codable {
    let userId: String
    let article: ArticleData
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case article = "link"
    }
    
    struct ArticleData: Codable {
        let category: String
        let url: String
        let title: String
    }
}

// MARK: - API Conversion
extension Article {
    // Convert from API Response to Article
    init(from response: ArticleResponse) {
        self.init(
            id: UUID(),
            title: response.gistCreated.title,
            url: URL(string: response.gistCreated.url)!,
            dateAdded: response.dateAdded,
            duration: 0,
            category: response.category,
            gistStatus: response.gistCreated
        )
    }
    
    // Convert to API Request
    func toArticleRequest(userId: String) -> ArticleRequest {
        ArticleRequest(
            userId: userId,
            article: ArticleRequest.ArticleData(
                category: category,
                url: url.absoluteString,
                title: title
            )
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


