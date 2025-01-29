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

public struct CategoriesResponse: Codable {
    public let categories: [Category]
    public let count: Int
} 