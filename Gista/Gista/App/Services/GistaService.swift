//
//  GistaService.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/29/25.
//

import Foundation
import Shared

// MARK: - Protocol
protocol GistaServiceProtocol {
    func createUser(email: String, password: String, username: String) async throws -> User
    func updateUser(userId: String, username: String, email: String) async throws -> Bool
    func deleteUser(userId: String) async throws -> Bool
    func storeArticle(userId: String, article: Article) async throws -> Article
    func updateArticleGistStatus(userId: String, articleId: String, gistId: String, imageUrl: String, title: String) async throws -> Article
    func fetchArticles(userId: String) async throws -> [Article]
    func createGist(userId: String, gist: GistRequest) async throws -> Gist
    func updateGistStatus(userId: String, gistId: String, status: GistStatus, isPlayed: Bool?, ratings: Int?) async throws -> Bool
    func updateGistProductionStatus(userId: String, gistId: String) async throws -> Bool
    func deleteGist(userId: String, gistId: String) async throws -> Bool
    func fetchGists(userId: String) async throws -> [Gist]
    func fetchCategories() async throws -> [Category]
    func fetchCategory(slug: String) async throws -> Category
    func createCategory(name: String, tags: [String]) async throws -> Category
    func updateCategory(id: String, name: String?, tags: [String]?) async throws -> Category
}

// MARK: - Errors
enum GistaError: LocalizedError, Equatable {
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
    
    var errorDescription: String? {
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
    
    static func == (lhs: GistaError, rhs: GistaError) -> Bool {
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

// MARK: - API Models
struct User: Codable {
    let userId: String
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case message
    }
    
    init(userId: String, message: String) {
        self.userId = userId
        self.message = message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode userId, which should always be present
        userId = try container.decode(String.self, forKey: .userId)
        
        // Try to decode message, but use a default if missing
        if let decodedMessage = try? container.decode(String.self, forKey: .message) {
            message = decodedMessage
        } else {
            message = "User operation completed"
        }
    }
}

struct UserRequest: Codable {
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

// MARK: - Service Implementation
final class GistaService: GistaServiceProtocol {
    private let baseURL: URL
    private let session: URLSessionProtocol
    private var authToken: String?
    
    public enum Environment {
        case development
        case production
        
        var baseURL: URL {
            switch self {
            case .development:
                return URL(string: "http://localhost:5001")!
            case .production:
                return URL(string: "https://us-central1-dof-ai.cloudfunctions.net/api")!
            }
        }
    }
    
    init(environment: Environment = .production,
         session: URLSessionProtocol = URLSession.shared,
         authToken: String? = nil) {
        self.baseURL = environment.baseURL
        self.session = session
        self.authToken = authToken
    }
}

// MARK: - API Methods
extension GistaService {
    func createUser(email: String, password: String, username: String) async throws -> User {
        let endpoint = Endpoint.createUser(email: email, password: password, username: username)
        return try await performRequest(endpoint)
    }
    
    func updateUser(userId: String, username: String, email: String) async throws -> Bool {
        let endpoint = Endpoint.updateUser(userId: userId, username: username, email: email)
        return try await performRequest(endpoint)
    }
    
    func deleteUser(userId: String) async throws -> Bool {
        let endpoint = Endpoint.deleteUser(userId: userId)
        let response: DeleteResponse = try await performRequest(endpoint)
        return response.message.contains("deleted successfully")
    }
    
    func storeArticle(userId: String, article: Article) async throws -> Article {
        let endpoint = Endpoint.storeLink(
            userId: userId,
            category: article.category,
            url: article.url.absoluteString,
            title: article.title
        )
        
        do {
            // Get the raw response data
            let (data, response) = try await performRawRequest(endpoint)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GistaError.invalidResponse
            }
            
            // Check for successful status code
            guard (200...299).contains(httpResponse.statusCode) else {
                throw GistaError.unexpectedStatus(httpResponse.statusCode)
            }
            
            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw response: \(responseString)")
            }
            
            // Parse the JSON manually
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let _ = json["message"] as? String,
                  let linkData = json["link"] as? [String: Any],
                  let category = linkData["category"] as? String,
                  let gistCreatedData = linkData["gist_created"] as? [String: Any] else {
                throw GistaError.decodingError(NSError(domain: "GistaService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"]))
            }
            
            // Extract date_added if available
            var dateAdded = Date()
            if let dateAddedString = linkData["date_added"] as? String,
               let date = ISO8601DateFormatter().date(from: dateAddedString) {
                dateAdded = date
            }
            
            // Extract gist_created fields
            let gistCreated = gistCreatedData["gist_created"] as? Bool ?? false
            let gistId = gistCreatedData["gist_id"] as? String
            let imageUrl = gistCreatedData["image_url"] as? String
            let linkId = gistCreatedData["link_id"] as? String ?? UUID().uuidString
            let linkTitle = gistCreatedData["link_title"] as? String ?? article.title
            let linkType = gistCreatedData["link_type"] as? String ?? "Web"
            let url = gistCreatedData["url"] as? String ?? article.url.absoluteString
            
            // Create the ArticleGistStatus
            let gistStatus = ArticleGistStatus(
                gistCreated: gistCreated,
                gistId: gistId,
                imageUrl: imageUrl,
                articleId: linkId,
                title: linkTitle,
                type: linkType,
                url: url
            )
            
            // Create the Article
            let createdArticle = Article(
                id: UUID(),
                title: linkTitle,
                url: URL(string: url) ?? article.url,
                dateAdded: dateAdded,
                duration: article.duration,
                category: category,
                gistStatus: gistStatus
            )
            
            // Log success with detailed information
            print("Successfully created article manually: \(createdArticle)")
            print("- Title: \(createdArticle.title)")
            print("- URL: \(createdArticle.url)")
            print("- Category: \(createdArticle.category)")
            print("- Date Added: \(createdArticle.dateAdded)")
            
            if let gistStatus = createdArticle.gistStatus {
                print("- Gist Status:")
                print("  - Gist Created: \(gistStatus.gistCreated)")
                print("  - Gist ID: \(gistStatus.gistId ?? "nil")")
                print("  - Image URL: \(gistStatus.imageUrl ?? "nil")")
                print("  - Article ID: \(gistStatus.articleId)")
                print("  - Title: \(gistStatus.title)")
                print("  - Type: \(gistStatus.type)")
                print("  - URL: \(gistStatus.url)")
            }
            
            return createdArticle
        } catch {
            print("Error in storeArticle: \(error)")
            
            // If it's a decoding error, try to extract useful information from the raw response
            if case let GistaError.decodingError(decodingError) = error {
                print("Decoding error details: \(decodingError)")
                
                // Rethrow with more context
                throw GistaError.decodingError(decodingError)
            }
            
            throw error
        }
    }
    
    func updateArticleGistStatus(userId: String, articleId: String, gistId: String, imageUrl: String, title: String) async throws -> Article {
        let endpoint = Endpoint.updateLinkGistStatus(
            userId: userId,
            linkId: articleId,
            gistId: gistId,
            imageUrl: imageUrl,
            title: title
        )
        let response: ArticleResponse = try await performRequest(endpoint)
        return Article(from: response)
    }
    
    func fetchArticles(userId: String) async throws -> [Article] {
        let endpoint = Endpoint.fetchLinks(userId: userId)
        let response: ArticlesResponse = try await performRequest(endpoint)
        return response.articles.map { Article(from: $0) }
    }
    
    func createGist(userId: String, gist: GistRequest) async throws -> Gist {
        let endpoint = Endpoint.createGist(userId: userId, gist: gist)
        
        do {
            // Get the raw response data
            let (data, response) = try await performRawRequest(endpoint)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GistaError.invalidResponse
            }
            
            // Check for successful status code
            guard (200...299).contains(httpResponse.statusCode) else {
                throw GistaError.unexpectedStatus(httpResponse.statusCode)
            }
            
            // Log the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw gist response: \(responseString)")
            }
            
            // Parse the JSON manually
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let _ = json["message"] as? String,
                  let gistData = json["gist"] as? [String: Any],
                  let title = gistData["title"] as? String,
                  let category = gistData["category"] as? String,
                  let imageUrl = gistData["image_url"] as? String,
                  let link = gistData["link"] as? String else {
                throw GistaError.decodingError(NSError(domain: "GistaService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse gist response"]))
            }
            
            // Extract optional fields with defaults
            let gistId = gistData["gistId"] as? String ?? gistData["link_id"] as? String
            let dateCreatedString = gistData["date_created"] as? String
            let dateCreated = dateCreatedString != nil ? ISO8601DateFormatter().date(from: dateCreatedString!) ?? Date() : Date()
            let isPlayed = gistData["is_played"] as? Bool ?? false
            let isPublished = gistData["is_published"] as? Bool ?? true
            let playbackDuration = gistData["playback_duration"] as? Int ?? 0
            let publisher = gistData["publisher"] as? String ?? "theNewGista"
            let ratings = gistData["ratings"] as? Int ?? 0
            let users = gistData["users"] as? Int ?? 0
            
            // Extract segments
            var segments: [GistSegment] = []
            if let segmentsData = gistData["segments"] as? [[String: Any]] {
                for segmentData in segmentsData {
                    let title = segmentData["segment_title"] as? String ?? "Untitled Segment"
                    let audioUrl = segmentData["segment_audioUrl"] as? String ?? ""
                    
                    // Handle duration which might be a string or int
                    var duration = 0
                    if let durationInt = segmentData["playback_duration"] as? Int {
                        duration = durationInt
                    } else if let durationString = segmentData["playback_duration"] as? String,
                              let durationInt = Int(durationString) {
                        duration = durationInt
                    }
                    
                    let segmentIndex = segmentData["segment_index"] as? Int
                    
                    segments.append(GistSegment(
                        duration: duration,
                        title: title,
                        audioUrl: audioUrl,
                        segmentIndex: segmentIndex
                    ))
                }
            }
            
            // Extract status
            var status = GistStatus(inProduction: false, productionStatus: "Reviewing Content")
            if let statusData = gistData["status"] as? [String: Any] {
                let inProduction = statusData["inProduction"] as? Bool ?? false
                let productionStatus = statusData["production_status"] as? String ?? "Reviewing Content"
                status = GistStatus(inProduction: inProduction, productionStatus: productionStatus)
            }
            
            // Create the Gist
            let createdGist = Gist(
                id: UUID(),
                title: title,
                category: category,
                dateCreated: dateCreated,
                imageUrl: imageUrl,
                isPlayed: isPlayed,
                isPublished: isPublished,
                link: link,
                playbackDuration: playbackDuration,
                publisher: publisher,
                ratings: ratings,
                segments: segments,
                status: status,
                users: users,
                gistId: gistId
            )
            
            // Log success with detailed information
            print("Successfully created gist manually: \(createdGist)")
            print("- Title: \(createdGist.title)")
            print("- Category: \(createdGist.category)")
            print("- Segments: \(createdGist.segments.count)")
            
            return createdGist
        } catch {
            print("Error in createGist: \(error)")
            
            // If it's a decoding error, try to extract useful information from the raw response
            if case let GistaError.decodingError(decodingError) = error {
                print("Decoding error details: \(decodingError)")
                
                // Rethrow with more context
                throw GistaError.decodingError(decodingError)
            }
            
            throw error
        }
    }
    
    func updateGistStatus(userId: String, gistId: String, status: GistStatus, isPlayed: Bool? = nil, ratings: Int? = nil) async throws -> Bool {
        let endpoint = Endpoint.updateGistStatus(userId: userId, gistId: gistId, status: status, isPlayed: isPlayed, ratings: ratings)
        return try await performRequest(endpoint)
    }
    
    func updateGistProductionStatus(userId: String, gistId: String) async throws -> Bool {
        let endpoint = Endpoint.updateGistProductionStatus(userId: userId, gistId: gistId)
        let response: StatusResponse = try await performRequest(endpoint)
        return response.success
    }
    
    func deleteGist(userId: String, gistId: String) async throws -> Bool {
        let endpoint = Endpoint.deleteGist(userId: userId, gistId: gistId)
        let response: DeleteResponse = try await performRequest(endpoint)
        return response.message.contains("deleted successfully")
    }
    
    func fetchGists(userId: String) async throws -> [Gist] {
        let endpoint = Endpoint.fetchGists(userId: userId)
        return try await performRequest(endpoint)
    }
    
    func fetchCategories() async throws -> [Category] {
        let response: CategoriesResponse = try await performRequest(.fetchCategories)
        return response.categories
    }
    
    func fetchCategory(slug: String) async throws -> Category {
        return try await performRequest(.fetchCategory(slug: slug))
    }
    
    func createCategory(name: String, tags: [String]) async throws -> Category {
        return try await performRequest(.createCategory(name: name, tags: tags))
    }
    
    func updateCategory(id: String, name: String?, tags: [String]?) async throws -> Category {
        return try await performRequest(.updateCategory(id: id, name: name, tags: tags))
    }
}

// MARK: - Network Request
private extension GistaService {
    func performRequest<T: Decodable>(_ endpoint: Endpoint, 
                                     config: RequestConfig = .default) async throws -> T {
        guard let url = endpoint.url(baseURL: baseURL) else {
            throw GistaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = config.timeout
        request.cachePolicy = config.cachePolicy
        request.httpMethod = endpoint.method.rawValue
        
        // Add default headers
        NetworkConstants.baseHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add auth token if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body if available
        if let body = endpoint.body {
            let encoder = JSONEncoder()
            
            // For gist creation, don't convert keys to snake_case since we're already specifying exact field names
            if case .createGist = endpoint {
                // Use default key encoding strategy (no conversion)
                print("Using custom encoder for gist creation")
            } else {
                encoder.keyEncodingStrategy = .convertToSnakeCase
            }
            
            request.httpBody = try encoder.encode(body)
        }
        
        // For non-GET requests, use a single attempt to prevent duplicate operations
        if endpoint.method != .get {
            return try await performSingleRequest(request: request, endpoint: endpoint)
        }
        
        // For GET requests, we can safely retry
        var lastError: Error?
        for attempt in 0...config.retryCount {
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GistaError.invalidResponse
                }
                
                // Log response for debugging in development
                #if DEBUG
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response (\(httpResponse.statusCode)): \(responseString)")
                    
                    // Additional debug info for decoding errors
                    if endpoint.path.contains("/auth/create_user") && T.self == User.self {
                        print("Attempting to decode User model from: \(responseString)")
                    }
                }
                #endif
                
                // Special handling for user creation when user already exists
                if httpResponse.statusCode == 400 && endpoint.path.contains("/auth/create_user") {
                    if let responseString = String(data: data, encoding: .utf8),
                       responseString.contains("User already exists"),
                       T.self == User.self {
                        // Extract the user ID from the request body
                        if case let .createUser(email, _, _) = endpoint {
                            let userId = "user_\(email.hashValue)"
                            let user = User(userId: userId, message: "User already exists")
                            if let result = user as? T {
                                return result
                            }
                        }
                    }
                }
                
                // Special handling for user creation success
                if httpResponse.statusCode == 201 && endpoint.path.contains("/auth/create_user") && T.self == User.self {
                    do {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        return try decoder.decode(T.self, from: data)
                    } catch {
                        // If standard decoding fails, try to extract user_id manually
                        if let responseString = String(data: data, encoding: .utf8),
                           let userIdRange = responseString.range(of: "\"user_id\":\""),
                           let endQuoteRange = responseString[userIdRange.upperBound...].range(of: "\"") {
                            let startIndex = userIdRange.upperBound
                            let endIndex = endQuoteRange.lowerBound
                            let userId = String(responseString[startIndex..<endIndex])
                            let user = User(userId: userId, message: "User created successfully")
                            if let result = user as? T {
                                return result
                            }
                        }
                        
                        // If we still can't extract the user_id, rethrow the original error
                        throw GistaError.decodingError(error)
                    }
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        return try decoder.decode(T.self, from: data)
                    } catch {
                        print("Decoding error: \(error)")
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("Failed to decode: \(responseString)")
                        }
                        throw GistaError.decodingError(error)
                    }
                    
                case 401:
                    throw GistaError.unauthorized
                case 403:
                    throw GistaError.forbidden
                case 404:
                    throw GistaError.notFound
                case 429:
                    throw GistaError.rateLimited
                case 500...599:
                    throw GistaError.serverError("Status code: \(httpResponse.statusCode)")
                default:
                    throw GistaError.unexpectedStatus(httpResponse.statusCode)
                }
            } catch {
                lastError = error
                
                // Don't retry on certain errors
                if let gistaError = error as? GistaError {
                    switch gistaError {
                    case .unauthorized, .forbidden, .notFound:
                        throw error
                    default:
                        break
                    }
                }
                
                // If this was the last attempt, throw the error
                if attempt == config.retryCount {
                    throw error
                }
                
                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(NetworkConstants.retryDelay * 1_000_000_000))
            }
        }
        
        throw lastError ?? GistaError.unknown
    }
    
    // Helper method for single request (no retries)
    private func performSingleRequest<T: Decodable>(request: URLRequest, endpoint: Endpoint) async throws -> T {
        // Log request details for debugging
        #if DEBUG
        print("Request URL: \(request.url?.absoluteString ?? "Unknown URL")")
        print("Request Method: \(request.httpMethod ?? "Unknown Method")")
        
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Request Body: \(bodyString)")
            
            // For gist creation, log more details
            if endpoint.path.contains("/gists/add/") {
                print("Gist Creation Request Body Details:")
                do {
                    if let json = try JSONSerialization.jsonObject(with: body, options: []) as? [String: Any] {
                        if let segments = json["segments"] as? [[String: Any]] {
                            print("Segments count: \(segments.count)")
                            for (index, segment) in segments.enumerated() {
                                print("Segment \(index):")
                                for (key, value) in segment {
                                    print("  \(key): \(value)")
                                }
                            }
                        } else {
                            print("No segments found in request body")
                        }
                    }
                } catch {
                    print("Error parsing request body: \(error)")
                }
            }
        }
        #endif
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GistaError.invalidResponse
        }
        
        // Log response for debugging in development
        #if DEBUG
        if let responseString = String(data: data, encoding: .utf8) {
            print("Response (\(httpResponse.statusCode)): \(responseString)")
            
            // Additional debug info for decoding errors
            if endpoint.path.contains("/auth/create_user") && T.self == User.self {
                print("Attempting to decode User model from: \(responseString)")
            }
        }
        #endif
        
        // Special handling for user creation when user already exists
        if httpResponse.statusCode == 400 && endpoint.path.contains("/auth/create_user") {
            if let responseString = String(data: data, encoding: .utf8),
               responseString.contains("User already exists"),
               T.self == User.self {
                // Extract the user ID from the request body
                if case let .createUser(email, _, _) = endpoint {
                    let userId = "user_\(email.hashValue)"
                    let user = User(userId: userId, message: "User already exists")
                    if let result = user as? T {
                        return result
                    }
                }
            }
        }
        
        // Special handling for user creation success
        if httpResponse.statusCode == 201 && endpoint.path.contains("/auth/create_user") && T.self == User.self {
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(T.self, from: data)
            } catch {
                // If standard decoding fails, try to extract user_id manually
                if let responseString = String(data: data, encoding: .utf8),
                   let userIdRange = responseString.range(of: "\"user_id\":\""),
                   let endQuoteRange = responseString[userIdRange.upperBound...].range(of: "\"") {
                    let startIndex = userIdRange.upperBound
                    let endIndex = endQuoteRange.lowerBound
                    let userId = String(responseString[startIndex..<endIndex])
                    let user = User(userId: userId, message: "User created successfully")
                    if let result = user as? T {
                        return result
                    }
                }
                
                // If we still can't extract the user_id, rethrow the original error
                throw GistaError.decodingError(error)
            }
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(T.self, from: data)
            } catch {
                print("Decoding error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Failed to decode: \(responseString)")
                }
                throw GistaError.decodingError(error)
            }
            
        case 401:
            throw GistaError.unauthorized
        case 403:
            throw GistaError.forbidden
        case 404:
            throw GistaError.notFound
        case 429:
            throw GistaError.rateLimited
        case 500...599:
            throw GistaError.serverError("Status code: \(httpResponse.statusCode)")
        default:
            throw GistaError.unexpectedStatus(httpResponse.statusCode)
        }
    }
    
    // Helper method to perform a request and return the raw data
    private func performRawRequest(_ endpoint: Endpoint, 
                                  config: RequestConfig = .default) async throws -> (Data, URLResponse) {
        guard let url = endpoint.url(baseURL: baseURL) else {
            throw GistaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = config.timeout
        request.cachePolicy = config.cachePolicy
        request.httpMethod = endpoint.method.rawValue
        
        // Add default headers
        NetworkConstants.baseHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add auth token if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body if available
        if let body = endpoint.body {
            let encoder = JSONEncoder()
            
            // For gist creation, don't convert keys to snake_case since we're already specifying exact field names
            if case .createGist = endpoint {
                // Use default key encoding strategy (no conversion)
                print("Using custom encoder for gist creation")
            } else {
                encoder.keyEncodingStrategy = .convertToSnakeCase
            }
            
            request.httpBody = try encoder.encode(body)
        }
        
        // Log request details for debugging
        #if DEBUG
        print("Request URL: \(request.url?.absoluteString ?? "Unknown URL")")
        print("Request Method: \(request.httpMethod ?? "Unknown Method")")
        
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Request Body: \(bodyString)")
        }
        #endif
        
        // Perform the request
        return try await session.data(for: request)
    }
}

// MARK: - Endpoints
private extension GistaService {
    enum Endpoint {
        case createUser(email: String, password: String, username: String)
        case updateUser(userId: String, username: String, email: String)
        case deleteUser(userId: String)
        case storeLink(userId: String, category: String, url: String, title: String)
        case updateLinkGistStatus(userId: String, linkId: String, gistId: String, imageUrl: String, title: String)
        case fetchLinks(userId: String)
        case createGist(userId: String, gist: GistRequest)
        case updateGistStatus(userId: String, gistId: String, status: GistStatus, isPlayed: Bool?, ratings: Int?)
        case updateGistProductionStatus(userId: String, gistId: String)
        case deleteGist(userId: String, gistId: String)
        case fetchGists(userId: String)
        case fetchCategories
        case fetchCategory(slug: String)
        case createCategory(name: String, tags: [String])
        case updateCategory(id: String, name: String?, tags: [String]?)
        
        var path: String {
            switch self {
            case .createUser:
                return "/auth/create_user"
            case .updateUser:
                return "/auth/update-user"
            case let .deleteUser(userId):
                return "/auth/delete_user/\(userId)"
            case .storeLink:
                return "/links/store"
            case let .updateLinkGistStatus(userId, linkId, _, _, _):
                return "/links/update_gist_status/\(userId)/\(linkId)"
            case let .fetchLinks(userId):
                return "/links/\(userId)"
            case let .createGist(userId, _):
                return "/gists/add/\(userId)"
            case let .updateGistStatus(userId, gistId, _, _, _):
                return "/gists/update/\(userId)/\(gistId)"
            case let .updateGistProductionStatus(userId, gistId):
                return "/gists/\(userId)/\(gistId)/status"
            case let .deleteGist(userId, gistId):
                return "/gists/delete/\(userId)/\(gistId)"
            case let .fetchGists(userId):
                return "/gists/\(userId)"
            case .fetchCategories:
                return "/categories"
            case let .fetchCategory(slug):
                return "/categories/\(slug)"
            case .createCategory:
                return "/categories/add"
            case let .updateCategory(id, _, _):
                return "/categories/update/\(id)"
            }
        }
        
        var method: HTTPMethod {
            switch self {
            case .createUser, .storeLink, .createGist, .createCategory:
                return .post
            case .updateUser, .updateLinkGistStatus, .updateGistStatus, .updateCategory, .updateGistProductionStatus:
                return .put
            case .fetchLinks, .fetchGists, .fetchCategories, .fetchCategory:
                return .get
            case .deleteUser, .deleteGist:
                return .delete
            }
        }
        
        var body: Encodable? {
            switch self {
            case let .createUser(email, password, username):
                // Generate a user_id based on email to satisfy the API requirement
                let userId = "user_\(email.hashValue)"
                return UserRequest(userId: userId, email: email, password: password, username: username)
            case let .updateUser(userId, username, email):
                return ["user_id": userId, "username": username, "email": email]
            case .deleteUser:
                return nil // DELETE requests typically don't have a body
            case let .storeLink(userId, category, url, title):
                return ArticleRequest(
                    userId: userId,
                    article: ArticleRequest.ArticleData(
                        category: category,
                        url: url,
                        title: title
                    )
                )
            case let .updateLinkGistStatus(_, _, gistId, imageUrl, title):
                return [
                    "gist_id": gistId,
                    "image_url": imageUrl,
                    "link_title": title
                ]
            case let .createGist(_, gist):
                return gist
            case let .updateGistStatus(_, _, status, isPlayed, ratings):
                var body: [String: Any] = [
                    "status": [
                        "inProduction": status.inProduction,
                        "production_status": status.productionStatus
                    ]
                ]
                
                if let isPlayed = isPlayed {
                    body["is_played"] = isPlayed
                }
                
                if let ratings = ratings {
                    body["ratings"] = ratings
                }
                
                return body as? Encodable
            case .updateGistProductionStatus:
                // Signal-based approach - empty JSON object
                return [String: String]()
            case .deleteGist:
                return nil // DELETE requests typically don't have a body
            case .fetchCategories, .fetchCategory, .fetchLinks, .fetchGists:
                return nil
            case let .createCategory(name, tags):
                return CategoryRequest(name: name, tags: tags)
            case let .updateCategory(_, name, tags):
                return CategoryRequest(name: name, tags: tags)
            }
        }
        
        func url(baseURL: URL) -> URL? {
            // Check if the base URL already includes /api
            if baseURL.absoluteString.hasSuffix("/api") {
                // For production URL that already includes /api
                return URL(string: baseURL.absoluteString + path)
            } else {
                // For development URL
                let pathWithSlash = path.hasPrefix("/") ? path : "/\(path)"
                return URL(string: pathWithSlash, relativeTo: baseURL)
            }
        }
    }
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
}

// MARK: - Additional Models
struct DeleteResponse: Codable {
    let message: String
}

struct StatusResponse: Codable {
    let success: Bool
    let message: String
}

