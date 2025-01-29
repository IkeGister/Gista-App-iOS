//
//  Categories.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/29/25.
//

import Foundation

public struct Category: Codable {
    public let id: String
    public let name: String
    public let slug: String
    public let tags: [String]
    
    private enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case slug
        case tags
    }
}

// Response wrapper
struct CategoriesResponse: Codable {
    let categories: [Category]
    let count: Int
}
