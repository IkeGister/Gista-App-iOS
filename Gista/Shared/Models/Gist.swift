//
//  Gist.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/16/25.
//

import SwiftUI

// MARK: - Main Gist Model
public struct Gist: Identifiable, Codable {
    public let id: UUID
    public let title: String
    public let category: String
    public let dateCreated: Date
    public let imageUrl: String
    public let isPlayed: Bool
    public let isPublished: Bool
    public let link: String
    public let playbackDuration: Int
    public let publisher: String
    public let ratings: Int
    public let segments: [GistSegment]
    public let status: GistStatus
    public let users: Int
    public let gistColor: GistColor
    public let gistId: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case category
        case dateCreated = "date_created"
        case imageUrl = "image_url"
        case isPlayed = "is_played"
        case isPublished = "is_published"
        case link
        case playbackDuration = "playback_duration"
        case publisher
        case ratings
        case segments
        case status
        case users
        case gistColor = "color"
        case gistId = "gistId"
        case id
    }
    
    public init(id: UUID = UUID(),
                title: String,
                category: String,
                dateCreated: Date = Date(),
                imageUrl: String,
                isPlayed: Bool = false,
                isPublished: Bool = true,
                link: String,
                playbackDuration: Int,
                publisher: String,
                ratings: Int = 0,
                segments: [GistSegment],
                status: GistStatus,
                users: Int = 0,
                color: Color = .blue,
                gistId: String? = nil) {
        self.id = id
        self.title = title
        self.category = category
        self.dateCreated = dateCreated
        self.imageUrl = imageUrl
        self.isPlayed = isPlayed
        self.isPublished = isPublished
        self.link = link
        self.playbackDuration = playbackDuration
        self.publisher = publisher
        self.ratings = ratings
        self.segments = segments
        self.status = status
        self.users = users
        self.gistColor = GistColor(color, name: category.lowercased())
        self.gistId = gistId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode id, but if it's missing, create a new UUID
        if let idString = try? container.decodeIfPresent(String.self, forKey: .id) {
            self.id = UUID(uuidString: idString) ?? UUID()
        } else {
            self.id = UUID()
        }
        
        // Try to decode gistId
        self.gistId = try container.decodeIfPresent(String.self, forKey: .gistId)
        
        // Decode the rest of the fields
        self.title = try container.decode(String.self, forKey: .title)
        self.category = try container.decode(String.self, forKey: .category)
        
        // Try to decode dateCreated, but use current date if missing
        if let dateString = try? container.decode(String.self, forKey: .dateCreated),
           let date = ISO8601DateFormatter().date(from: dateString) {
            self.dateCreated = date
        } else {
            self.dateCreated = Date()
        }
        
        self.imageUrl = try container.decode(String.self, forKey: .imageUrl)
        self.isPlayed = try container.decode(Bool.self, forKey: .isPlayed)
        self.isPublished = try container.decode(Bool.self, forKey: .isPublished)
        self.link = try container.decode(String.self, forKey: .link)
        self.playbackDuration = try container.decode(Int.self, forKey: .playbackDuration)
        self.publisher = try container.decode(String.self, forKey: .publisher)
        self.ratings = try container.decode(Int.self, forKey: .ratings)
        self.segments = try container.decode([GistSegment].self, forKey: .segments)
        self.status = try container.decode(GistStatus.self, forKey: .status)
        self.users = try container.decode(Int.self, forKey: .users)
        
        // Try to decode gistColor, but use a default if missing
        if let gistColor = try? container.decodeIfPresent(GistColor.self, forKey: .gistColor) {
            self.gistColor = gistColor
        } else {
            self.gistColor = GistColor(.blue, name: self.category.lowercased())
        }
    }
    
    public var color: Color {
        gistColor.color
    }
}

// MARK: - Preview Data
public extension Gist {
    static let previews: [Gist] = [
        Gist(
            title: "Tech Articles",
            category: "Technology",
            imageUrl: "https://example.com/image.jpg",
            link: "https://example.com/tech",
            playbackDuration: 120,
            publisher: "TechGista",
            segments: [
                GistSegment(duration: 60, title: "Intro", audioUrl: "https://example.com/audio1.mp3")
            ],
            status: GistStatus(inProduction: false, productionStatus: "Reviewing Content"),
            color: .blue
        ),
        Gist(
            title: "Business",
            category: "Business",
            imageUrl: "https://example.com/image.jpg",
            link: "https://example.com/business",
            playbackDuration: 180,
            publisher: "BizGista",
            segments: [
                GistSegment(duration: 90, title: "Market Update", audioUrl: "https://example.com/audio2.mp3")
            ],
            status: GistStatus(inProduction: false, productionStatus: "Reviewing Content"),
            color: .green
        )
    ]
}

// MARK: - Core Supporting Types
public struct GistSegment: Codable {
    public let duration: Int
    public let title: String
    public let audioUrl: String
    public let segmentIndex: Int?
    
    public init(duration: Int, title: String, audioUrl: String, segmentIndex: Int? = nil) {
        self.duration = duration
        self.title = title
        self.audioUrl = audioUrl
        self.segmentIndex = segmentIndex
    }
    
    enum CodingKeys: String, CodingKey {
        case duration
        case title
        case audioUrl = "audioUrl"
        case segmentIndex = "index"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode duration as Int, but if it's a String, convert it
        if let durationInt = try? container.decode(Int.self, forKey: .duration) {
            self.duration = durationInt
        } else if let durationString = try? container.decode(String.self, forKey: .duration),
                  let durationInt = Int(durationString) {
            self.duration = durationInt
        } else {
            self.duration = 0
        }
        
        self.title = try container.decode(String.self, forKey: .title)
        self.audioUrl = try container.decode(String.self, forKey: .audioUrl)
        self.segmentIndex = try container.decodeIfPresent(Int.self, forKey: .segmentIndex)
    }
}

public struct GistStatus: Codable {
    public let inProduction: Bool
    public let productionStatus: String
    
    public init(inProduction: Bool, productionStatus: String) {
        self.inProduction = inProduction
        self.productionStatus = productionStatus
    }
    
    enum CodingKeys: String, CodingKey {
        case inProduction
        case productionStatus = "production_status"
    }
}

public struct GistCreatedStatus: Codable {
    public let gistCreated: Bool
    public let gistId: String?
    public let imageUrl: String?
    public let linkId: String
    public let linkTitle: String
    public let linkType: String
    public let url: String
    
    public init(
        gistCreated: Bool,
        gistId: String?,
        imageUrl: String?,
        linkId: String,
        linkTitle: String,
        linkType: String,
        url: String
    ) {
        self.gistCreated = gistCreated
        self.gistId = gistId
        self.imageUrl = imageUrl
        self.linkId = linkId
        self.linkTitle = linkTitle
        self.linkType = linkType
        self.url = url
    }
    
    enum CodingKeys: String, CodingKey {
        case gistCreated = "gist_created"
        case gistId = "gist_id"
        case imageUrl = "image_url"
        case linkId = "link_id"
        case linkTitle = "link_title"
        case linkType = "link_type"
        case url
    }
}

// MARK: - API Models
public struct GistRequest: Codable {
    public let title: String
    public let link: String
    public let imageUrl: String
    public let category: String
    public let segments: [GistSegment]
    public let playbackDuration: Int
    public let linkId: String
    public let gistId: String?
    public let isFinished: Bool
    public let playbackTime: Int
    public let status: GistStatus
    
    public init(
        title: String,
        link: String,
        imageUrl: String,
        category: String,
        segments: [GistSegment],
        playbackDuration: Int,
        linkId: String,
        gistId: String? = nil,
        isFinished: Bool = false,
        playbackTime: Int = 0,
        status: GistStatus = GistStatus(inProduction: false, productionStatus: "Reviewing Content")
    ) {
        self.title = title
        self.link = link
        self.imageUrl = imageUrl
        self.category = category
        self.segments = segments
        self.playbackDuration = playbackDuration
        self.linkId = linkId
        self.gistId = gistId
        self.isFinished = isFinished
        self.playbackTime = playbackTime
        self.status = status
    }
    
    enum CodingKeys: String, CodingKey {
        case title, link, category, segments, status
        case imageUrl = "image_url"
        case playbackDuration = "playback_duration"
        case linkId = "link_id"
        case gistId = "gist_id"
        case isFinished
        case playbackTime = "playback_time"
    }
}

// MARK: - UI Supporting Types
public struct GistColor: Codable {
    public let color: Color
    let name: String
    
    public init(_ color: Color, name: String) {
        self.color = color
        self.name = name
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let colorName = try container.decode(String.self)
        self.name = colorName
        self.color = Self.colorMap[colorName] ?? .blue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }
    
    static let colorMap: [String: Color] = [
        "blue": .blue,
        "green": .green,
        "purple": .purple,
        "orange": .orange,
        "red": .red,
        "yellow": .yellow
    ]
}

// MARK: - Color Extension
extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let r = try container.decode(Double.self, forKey: .red)
        let g = try container.decode(Double.self, forKey: .green)
        let b = try container.decode(Double.self, forKey: .blue)
        let a = try container.decode(Double.self, forKey: .alpha)
        
        self.init(red: r, green: g, blue: b, opacity: a)
    }
    
    public func encode(to encoder: Encoder) throws {
        guard let colorComponents = self.cgColor?.components else {
            throw EncodingError.invalidValue(self, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Could not get color components"
            ))
        }
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(colorComponents[0], forKey: .red)
        try container.encode(colorComponents[1], forKey: .green)
        try container.encode(colorComponents[2], forKey: .blue)
        try container.encode(colorComponents[3], forKey: .alpha)
    }
}
