//
//  GistaServiceResponse.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//

import Foundation

// Gista Service general response type
public struct GistaServiceResponse {
    public let success: Bool
    public let message: String
    public let linkId: String?
    public let gistId: String?
    
    public init(success: Bool, message: String, linkId: String? = nil, gistId: String? = nil) {
        self.success = success
        self.message = message
        self.linkId = linkId
        self.gistId = gistId
    }
}
