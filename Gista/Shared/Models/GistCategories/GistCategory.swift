//
//  GistCategory.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//

import Foundation

public struct GistCategory: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let slug: String
    public let tags: [String]
    
    public init(id: String, name: String, slug: String, tags: [String]) {
        self.id = id
        self.name = name
        self.slug = slug
        self.tags = tags
    }
    
    public enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case slug
        case tags
    }
}
