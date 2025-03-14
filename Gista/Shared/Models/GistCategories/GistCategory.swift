//
//  GistCategory.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//

import Foundation

public struct GistCategory: Codable {
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
