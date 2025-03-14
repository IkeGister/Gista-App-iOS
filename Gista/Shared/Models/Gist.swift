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
        
        // Try to decode imageUrl, but use a default if missing
        if let imageUrlString = try? container.decode(String.self, forKey: .imageUrl) {
            self.imageUrl = imageUrlString
        } else {
            print("Warning: imageUrl missing in Gist, using default")
            self.imageUrl = "https://example.com/image.jpg"
        }
        
        // Try to decode optional fields with defaults
        self.isPlayed = try container.decodeIfPresent(Bool.self, forKey: .isPlayed) ?? false
        self.isPublished = try container.decodeIfPresent(Bool.self, forKey: .isPublished) ?? true
        self.link = try container.decode(String.self, forKey: .link)
        self.playbackDuration = try container.decodeIfPresent(Int.self, forKey: .playbackDuration) ?? 0
        self.publisher = try container.decodeIfPresent(String.self, forKey: .publisher) ?? "theNewGista"
        self.ratings = try container.decodeIfPresent(Int.self, forKey: .ratings) ?? 0
        self.users = try container.decodeIfPresent(Int.self, forKey: .users) ?? 0
        
        // Try to decode segments, but use an empty array if missing or if decoding fails
        do {
            self.segments = try container.decode([GistSegment].self, forKey: .segments)
        } catch {
            print("Warning: Failed to decode segments in Gist: \(error)")
            self.segments = []
        }
        
        // Try to decode status, but use a default if missing or if decoding fails
        do {
            self.status = try container.decode(GistStatus.self, forKey: .status)
        } catch {
            print("Warning: Failed to decode status in Gist: \(error)")
            self.status = GistStatus(inProduction: false, productionStatus: "Reviewing Content")
        }
        
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
    
    enum CodingKeys: String, CodingKey {
        case duration = "playback_duration"
        case title = "segment_title"
        case audioUrl = "segment_audioUrl"
        case segmentIndex = "segment_index"
    }
    
    public init(duration: Int, title: String, audioUrl: String, segmentIndex: Int? = nil) {
        self.duration = duration
        self.title = title
        self.audioUrl = audioUrl
        self.segmentIndex = segmentIndex
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
        
        // Try to decode title, but use a default if missing
        if let titleValue = try? container.decode(String.self, forKey: .title) {
            self.title = titleValue
        } else {
            self.title = "Untitled Segment"
        }
        
        // Try to decode audioUrl, but use a default if missing
        if let audioUrlValue = try? container.decode(String.self, forKey: .audioUrl) {
            self.audioUrl = audioUrlValue
        } else {
            self.audioUrl = "https://example.com/audio.mp3"
        }
        
        self.segmentIndex = try container.decodeIfPresent(Int.self, forKey: .segmentIndex)
    }
    
    // Custom encode method to ensure proper formatting for the API
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(duration, forKey: .duration)
        
        // Ensure title is never undefined by using a default if it's empty
        let safeTitle = title.isEmpty ? "Untitled Segment" : title
        try container.encode(safeTitle, forKey: .title)
        
        try container.encode(audioUrl, forKey: .audioUrl)
        
        if let segmentIndex = segmentIndex {
            try container.encode(segmentIndex, forKey: .segmentIndex)
        }
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
    
    // Custom encode method to ensure proper formatting for the API
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(inProduction, forKey: .inProduction)
        
        // Ensure productionStatus is never undefined
        let safeStatus = productionStatus.isEmpty ? "Reviewing Content" : productionStatus
        try container.encode(safeStatus, forKey: .productionStatus)
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
        case title, link, category, segments, status, isFinished
        case imageUrl = "image_url"
        case playbackDuration = "playback_duration"
        case linkId = "link_id"
        case gistId = "gist_id"
        case playbackTime = "playback_time"
    }
    
    // Custom encode method to ensure proper formatting for the API
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Ensure title is never undefined
        let safeTitle = title.isEmpty ? "Untitled Gist" : title
        try container.encode(safeTitle, forKey: .title)
        
        // Ensure link is never undefined
        let safeLink = link.isEmpty ? "https://example.com" : link
        try container.encode(safeLink, forKey: .link)
        
        // Ensure imageUrl is never undefined
        let safeImageUrl = imageUrl.isEmpty ? "https://example.com/image.jpg" : imageUrl
        try container.encode(safeImageUrl, forKey: .imageUrl)
        
        // Ensure category is never undefined
        let safeCategory = category.isEmpty ? "General" : category
        try container.encode(safeCategory, forKey: .category)
        
        // Ensure segments array is never empty
        if segments.isEmpty {
            let defaultSegment = GistSegment(
                duration: 60,
                title: "Default Segment",
                audioUrl: "https://example.com/audio.mp3",
                segmentIndex: 0
            )
            try container.encode([defaultSegment], forKey: .segments)
        } else {
            try container.encode(segments, forKey: .segments)
        }
        
        try container.encode(playbackDuration, forKey: .playbackDuration)
        try container.encode(linkId, forKey: .linkId)
        
        if let gistId = gistId {
            try container.encode(gistId, forKey: .gistId)
        }
        
        try container.encode(isFinished, forKey: .isFinished)
        try container.encode(playbackTime, forKey: .playbackTime)
        try container.encode(status, forKey: .status)
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
