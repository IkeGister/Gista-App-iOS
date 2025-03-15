//
//  GistUpdateRequest.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//


import Foundation

struct GistUpdateRequest: Codable {
    let status: GistStatusRequest
    let isPlayed: Bool?
    let ratings: Int?
    
    struct GistStatusRequest: Codable {
        let inProduction: Bool
        let productionStatus: String
        
        enum CodingKeys: String, CodingKey {
            case inProduction
            case productionStatus = "production_status"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case status
        case isPlayed = "is_played"
        case ratings
    }
    
    init(status: GistStatus, isPlayed: Bool? = nil, ratings: Int? = nil) {
        self.status = GistStatusRequest(
            inProduction: status.inProduction,
            productionStatus: status.productionStatus
        )
        self.isPlayed = isPlayed
        self.ratings = ratings
    }
}