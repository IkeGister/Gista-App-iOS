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
    
    public enum CodingKeys: String, CodingKey {
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


// MARK: - Core Supporting Types
public struct GistSegment: Codable {
    public let duration: Int
    public let title: String
    public let audioUrl: String
    public let segmentIndex: Int?
    
    public enum CodingKeys: String, CodingKey {
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
    
    public enum CodingKeys: String, CodingKey {
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


// MARK: - UI Supporting Types
public struct GistColor: Codable {
    public let color: Color
    public let name: String
    
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
    
    public static let colorMap: [String: Color] = [
        "blue": .blue,
        "green": .green,
        "purple": .purple,
        "orange": .orange,
        "red": .red,
        "yellow": .yellow
    ]
}

