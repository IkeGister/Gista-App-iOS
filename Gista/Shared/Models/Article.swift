//
//  Article.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/16/25.
//

import SwiftUI
import Shared
import Foundation

public struct Article: Identifiable {
    public let id: UUID
    public let title: String
    public let url: URL
    public let dateAdded: Date
    public let duration: Int // in seconds
    
    public init(id: UUID = UUID(),
                title: String,
                url: URL,
                dateAdded: Date = Date(),
                duration: Int) {
        self.id = id
        self.title = title
        self.url = url
        self.dateAdded = dateAdded
        self.duration = duration
    }
}


