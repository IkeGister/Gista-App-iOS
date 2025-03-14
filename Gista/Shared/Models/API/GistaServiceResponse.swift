//
//  GistaServiceResponse.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//


import Foundation
import Shared

// Gista Service general response type
struct GistaServiceResponse {
    let success: Bool
    let message: String
    let linkId: String?
    let gistId: String?
    
    init(success: Bool, message: String, linkId: String? = nil, gistId: String? = nil) {
        self.success = success
        self.message = message
        self.linkId = linkId
        self.gistId = gistId
    }
}
