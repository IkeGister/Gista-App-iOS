//
//  Gist.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/16/25.
//

import SwiftUI
import Shared


public struct Gist: Identifiable {    public let id: UUID
    public let name: String
    public let itemCount: Int
    public let color: Color
    
    public init(id: UUID, name: String, itemCount: Int, color: Color) {
        self.id = id
        self.name = name
        self.itemCount = itemCount
        self.color = color
    }
}

public extension Gist {
    static let previews: [Gist] = [
        Gist(id: UUID(), name: "Tech Articles", itemCount: 12, color: .blue),
        Gist(id: UUID(), name: "Business", itemCount: 8, color: .green),
        Gist(id: UUID(), name: "Science", itemCount: 5, color: .purple),
        Gist(id: UUID(), name: "Favorites", itemCount: 3, color: .orange)
    ]
}
