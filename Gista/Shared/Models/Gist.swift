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
    
    enum CodingKeys: String, CodingKey {
        case id
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
                color: Color = .blue) {
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
            status: GistStatus(isDonePlaying: false, isNowPlaying: false, playbackTime: 0),
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
            status: GistStatus(isDonePlaying: false, isNowPlaying: false, playbackTime: 0),
            color: .green
        )
    ]
}

// MARK: - Core Supporting Types
public struct GistSegment: Codable {
    public let duration: Int
    public let title: String
    public let audioUrl: String
    
    public init(duration: Int, title: String, audioUrl: String) {
        self.duration = duration
        self.title = title
        self.audioUrl = audioUrl
    }
}

public struct GistStatus: Codable {
    public let isDonePlaying: Bool
    public let isNowPlaying: Bool
    public let playbackTime: Int
    
    public init(isDonePlaying: Bool, isNowPlaying: Bool, playbackTime: Int) {
        self.isDonePlaying = isDonePlaying
        self.isNowPlaying = isNowPlaying
        self.playbackTime = playbackTime
    }
    
    enum CodingKeys: String, CodingKey {
        case isDonePlaying = "is_done_playing"
        case isNowPlaying = "is_now_playing"
        case playbackTime = "playback_time"
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
    
    public init(
        title: String,
        link: String,
        imageUrl: String,
        category: String,
        segments: [GistSegment],
        playbackDuration: Int
    ) {
        self.title = title
        self.link = link
        self.imageUrl = imageUrl
        self.category = category
        self.segments = segments
        self.playbackDuration = playbackDuration
    }
    
    enum CodingKeys: String, CodingKey {
        case title, link, category, segments
        case imageUrl = "image_url"
        case playbackDuration = "playback_duration"
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
