//
//  NetworkService.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/7/25.
//

import Foundation
import Shared

// MARK: - NetworkService Protocol
protocol NetworkServiceProtocol {
    func performRequest<T: Decodable>(_ endpoint: String,
                                     method: HTTPMethod,
                                     headers: [String: String]?,
                                     body: Encodable?,
                                     queryItems: [URLQueryItem]?) async throws -> T
}

// MARK: - HTTP Method Enum
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - Network Error Types
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
    case unauthorized
    case serverError(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized access"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}

// MARK: - Network Constants
enum NetworkConstants {
    static let baseHeaders: [String: String] = [
        "Content-Type": "application/json",
        "Accept": "application/json"
    ]
    
    static let retryDelay: TimeInterval = 1.0
    static let defaultTimeout: TimeInterval = 30.0
    static let maxRetryAttempts: Int = 2
}

// MARK: - NetworkService Implementation
class NetworkService: NetworkServiceProtocol {
    private let baseURL: URL
    private let session: URLSessionProtocol
    private var authToken: String?
    
    init(baseURL: URL, session: URLSessionProtocol = URLSession.shared, authToken: String? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.authToken = authToken
    }
    
    func setAuthToken(_ token: String?) {
        self.authToken = token
    }
    
    func performRequest<T: Decodable>(_ endpoint: String,
                                     method: HTTPMethod,
                                     headers: [String: String]? = nil,
                                     body: Encodable? = nil,
                                     queryItems: [URLQueryItem]? = nil) async throws -> T {
        
        // Construct URL with query parameters if provided
        guard var urlComponents = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true) else {
            throw NetworkError.invalidURL
        }
        
        if let queryItems = queryItems, !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = NetworkConstants.defaultTimeout
        
        // Add default headers
        NetworkConstants.baseHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add auth token if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body if available
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw NetworkError.encodingError(error)
            }
        }
        
        // Perform request with retry logic
        var lastError: Error?
        
        for attempt in 0...NetworkConstants.maxRetryAttempts {
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                // Log response for debugging in development
                #if DEBUG
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response (\(httpResponse.statusCode)): \(responseString)")
                }
                #endif
                
                switch httpResponse.statusCode {
                case 200...299:
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    do {
                        return try decoder.decode(T.self, from: data)
                    } catch {
                        throw NetworkError.decodingError(error)
                    }
                    
                case 401:
                    throw NetworkError.unauthorized
                case 500...599:
                    throw NetworkError.serverError("Status code: \(httpResponse.statusCode)")
                default:
                    throw NetworkError.httpError(httpResponse.statusCode)
                }
            } catch {
                lastError = error
                
                // Don't retry on certain errors
                if let networkError = error as? NetworkError {
                    switch networkError {
                    case .unauthorized, .invalidURL, .decodingError, .encodingError:
                        throw error
                    default:
                        break
                    }
                }
                
                // If this was the last attempt, throw the error
                if attempt == NetworkConstants.maxRetryAttempts {
                    throw error
                }
                
                // Wait before retrying
                try? await Task.sleep(nanoseconds: UInt64(NetworkConstants.retryDelay * 1_000_000_000))
            }
        }
        
        throw lastError ?? NetworkError.unknown
    }
}

// MARK: - Network Monitoring
class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private(set) var isConnected: Bool = true
    
    // In a real implementation, you would use NWPathMonitor to monitor network connectivity
    // For simplicity, we're just providing a placeholder implementation
    
    func startMonitoring() {
        // Implementation would use NWPathMonitor to monitor network status
        print("Network monitoring started")
    }
    
    func stopMonitoring() {
        // Implementation would stop the NWPathMonitor
        print("Network monitoring stopped")
    }
}

