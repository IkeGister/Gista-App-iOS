//
//  LinkResponse.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/15/25.
//


import Foundation
import Shared

struct LinkResponse {
        let success: Bool
        let message: String
        let linkId: String?
        let gistId: String?
    }