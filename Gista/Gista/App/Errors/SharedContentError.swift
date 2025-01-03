//
//  SharedContentError.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import Foundation

enum SharedContentError: Error {
    case invalidAppGroup
    case fileAccessError
    case invalidContent
    
    var localizedDescription: String {
        switch self {
        case .invalidAppGroup:
            return "Failed to access app group container"
        case .fileAccessError:
            return "Failed to access or write file"
        case .invalidContent:
            return "Invalid or unsupported content type"
        }
    }
}
