//
//  NetworkProtocols.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/29/25.
//


import Foundation
import Shared

/// Protocol to abstract URLSession for testing purposes.
/// This allows us to mock network calls without making actual HTTP requests.
public protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol { }

// MARK: - Request Configuration
public struct RequestConfig {
    let timeout: TimeInterval
    let retryCount: Int
    let cachePolicy: URLRequest.CachePolicy
    
    public static let `default` = RequestConfig(
        timeout: NetworkConstants.defaultTimeout,
        retryCount: NetworkConstants.maxRetryAttempts,
        cachePolicy: .useProtocolCachePolicy
    )
    
    public static let noRetry = RequestConfig(
        timeout: NetworkConstants.defaultTimeout,
        retryCount: 0,
        cachePolicy: .useProtocolCachePolicy
    )
}
