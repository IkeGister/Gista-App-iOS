//
//  CreateUserRequest.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//


import Foundation
import Shared

struct CreateUserRequest: Codable {
    let userId: String
    let email: String
    let password: String
    let username: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case password
        case username
    }
}