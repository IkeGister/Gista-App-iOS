//
//  Item.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
