//
//  CategoryRequest2.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//

/// Request model for creating or updating categories
public struct CategoryRequest: Encodable {
    public let name: String
    public let tags: [String]
    
    // For update requests where fields are optional
    public init(name: String?, tags: [String]?) {
        self.name = name ?? ""
        self.tags = tags ?? []
    }
    
    // For create requests where fields are required
    public init(name: String, tags: [String]) {
        self.name = name
        self.tags = tags
    }
}

// Response wrapper
public struct GistaServiceCategories: Codable {
    public let categories: [GistCategory]
    public let count: Int
}
