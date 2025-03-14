//
//  ColorExtensions.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//

import Foundation
import SwiftUI

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
