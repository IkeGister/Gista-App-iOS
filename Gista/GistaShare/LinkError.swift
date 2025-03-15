//
//  LinkError.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/15/25.
//


import Foundation
import Shared

enum LinkError: Error, LocalizedError {
        case invalidURL
        case encodingError
        case networkError
        case decodingError
        case apiError(statusCode: Int, message: String)
        case unauthorized
        case timeoutError
        case noInternetConnection
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .encodingError:
                return "Failed to encode request"
            case .networkError:
                return "Network error occurred"
            case .decodingError:
                return "Failed to decode response"
            case .apiError(let statusCode, let message):
                return "API error (\(statusCode)): \(message)"
            case .unauthorized:
                return "Unauthorized access"
            case .timeoutError:
                return "Request timed out"
            case .noInternetConnection:
                return "No internet connection"
            }
        }
    }