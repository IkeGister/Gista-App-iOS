//
//  GistaError.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//


import Foundation

public enum GistaError: LocalizedError, Equatable {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
    case unauthorized
    case serverError(String)
    case forbidden
    case notFound
    case rateLimited
    case unexpectedStatus(Int)
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Unauthorized access"
        case .serverError(let message):
            return "Server error: \(message)"
        case .forbidden:
            return "Forbidden access"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Rate limit exceeded"
        case .unexpectedStatus(let statusCode):
            return "Unexpected status code: \(statusCode)"
        case .unknown:
            return "Unknown error"
        }
    }
    
    public static func == (lhs: GistaError, rhs: GistaError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.rateLimited, .rateLimited):
            return true
        case let (.serverError(lhsMsg), .serverError(rhsMsg)):
            return lhsMsg == rhsMsg
        case let (.networkError(lhsErr), .networkError(rhsErr)):
            return lhsErr.localizedDescription == rhsErr.localizedDescription
        case let (.decodingError(lhsErr), .decodingError(rhsErr)):
            return lhsErr.localizedDescription == rhsErr.localizedDescription
        default:
            return false
        }
    }
}