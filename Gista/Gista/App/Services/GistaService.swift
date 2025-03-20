//
//  GistaService.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/29/25.
//

import Foundation


// MARK: - Service Implementation
public final class GistaService: GistaServiceProtocol {
    // MARK: - Environment
    public enum Environment {
        case development
        case production
        
        public var baseURL: URL {
            switch self {
            case .development:
                return URL(string: "https://us-central1-dof-ai.cloudfunctions.net/api")!
            case .production:
                return URL(string: "https://us-central1-dof-ai.cloudfunctions.net/api")!
            }
        }
    }
    
    // MARK: - Request Configuration
    public struct RequestConfig {
        let timeout: TimeInterval
        let cachePolicy: URLRequest.CachePolicy
        
        public static let `default` = RequestConfig(
            timeout: 30.0,
            cachePolicy: .useProtocolCachePolicy
        )
    }
    
    // MARK: - Properties
    private let baseURL: URL
    private let session: URLSessionProtocol
    private var authToken: String?
    
    public init(environment: Environment = .production,
         session: URLSessionProtocol = URLSession.shared,
         authToken: String? = nil) {
        self.baseURL = environment.baseURL
        self.session = session
        self.authToken = authToken
    }
    
    // MARK: - User Management Methods
    public func createUser(email: String, password: String, username: String) async throws -> User {
        print("===== CREATING USER =====")
        print("Email: \(email)")
        print("Username: \(username)")
        print("Password: \(password.isEmpty ? "empty" : "[redacted]")")
        
        // Create the endpoint for user creation with parameters
        let endpoint = Endpoint.createUser(email: email, password: password, username: username)
        
        do {
            let response: User = try await performRequest(
                endpoint
            )
            
            print("✅ API User Creation Successful")
            print("User ID: \(response.userId)")
            print("Message: \(response.message)")
            print("Full Response: \(response)")
            print("========================")
            
            return response
        } catch {
            print("❌ API User Creation Failed")
            print("Error: \(error)")
            if let gistaError = error as? GistaError {
                print("GistaError: \(gistaError.errorDescription ?? "Unknown")")
            }
            print("========================")
            throw error
        }
    }
    
    public func updateUser(userId: String, username: String, email: String) async throws -> Bool {
        // TODO: Implement actual user update
        return true
    }
    
    public func deleteUser(userId: String) async throws -> Bool {
        print("===== DELETING USER =====")
        print("User ID: \(userId)")
        
        let endpoint = Endpoint.deleteUser(userId: userId)
        
        do {
            // Get the raw response data
            let (data, response) = try await performRawRequest(endpoint)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GistaError.invalidResponse
            }
            
            // Check for successful status code
            let isSuccess = (200...299).contains(httpResponse.statusCode)
            
            // Log the result
            if isSuccess {
                print("✅ API User Deletion Successful")
            } else {
                print("❌ API User Deletion Failed with status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
            }
            print("========================")
            
            return isSuccess
        } catch {
            print("❌ API User Deletion Failed")
            print("Error: \(error)")
            print("========================")
            throw error
        }
    }
}

// MARK: - API Methods
extension GistaService {
    /**
     * Stores an article and optionally creates a gist automatically.
     *
     * This method handles two response formats:
     * 1. When autoCreateGist = true: Response contains a direct "gistId" field
     * 2. When autoCreateGist = false: Response contains the traditional format with a nested gist_created object
     *
     * - Parameters:
     *   - userId: The user's unique identifier
     *   - article: The article to store
     *   - autoCreateGist: Whether to automatically create a gist (defaults to true)
     *
     * - Returns: The created article with appropriate gist status
     * - Throws: GistaError if there's an issue with the request or response
     */
    public func storeArticle(userId: String, article: Article, autoCreateGist: Bool = true) async throws -> GistaServiceResponse {
        let endpoint = Endpoint.storeLink(
            userId: userId,
            category: article.category,
            url: article.url.absoluteString,
            title: article.title,
            autoCreateGist: autoCreateGist
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
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw GistaError.decodingError(NSError(domain: "GistaService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"]))
            }
            
            // Extract message
            let message = json["message"] as? String ?? "Operation completed"
            
            // Extract linkId and gistId if available
            let linkId = json["linkId"] as? String
            let gistId = json["gistId"] as? String
            
            // Log extracted data
            print("API success: \(message)")
            if let linkId = linkId {
                print("Link ID from API: \(linkId)")
            }
            if let gistId = gistId {
                print("Gist ID from API: \(gistId)")
            }
            
            // Return a simple response object
            return GistaServiceResponse(
                success: true, 
                message: message,
                linkId: linkId,
                gistId: gistId
            )
            
        } catch {
            print("Error in storeArticle: \(error)")
            
            // If it's a decoding error, add more context
            if case let GistaError.decodingError(decodingError) = error {
                print("Decoding error details: \(decodingError)")
            }
            
            throw error
        }
    }
    
    public func updateArticleGistStatus(userId: String, articleId: String, gistId: String, imageUrl: String, title: String) async throws -> Article {
        let endpoint = Endpoint.updateLinkGistStatus(
            userId: userId,
            linkId: articleId,
            gistId: gistId,
            imageUrl: imageUrl,
            title: title
        )
        let response: ArticleData = try await performRequest(endpoint)
        return Article(from: response)
    }
    
    public func fetchArticles(userId: String) async throws -> [Article] {
        let endpoint = Endpoint.fetchLinks(userId: userId)
        let response: ArticlesResponse = try await performRequest(endpoint)
        return response.articles.map { Article(from: $0) }
    }
    
    public func updateGistStatus(userId: String, gistId: String, status: GistStatus, isPlayed: Bool? = nil, ratings: Int? = nil) async throws -> Bool {
        print("Updating gist with ID: \(gistId) for user: \(userId)")
        print("Status: inProduction=\(status.inProduction), productionStatus=\(status.productionStatus)")
        if let isPlayed = isPlayed {
            print("isPlayed: \(isPlayed)")
        }
        if let ratings = ratings {
            print("ratings: \(ratings)")
        }
        
        let endpoint = Endpoint.updateGistStatus(userId: userId, gistId: gistId, status: status, isPlayed: isPlayed, ratings: ratings)
        
        do {
            let response: GistUpdateResponse = try await performRequest(endpoint)
            print("Update gist result: success=\(response.success), message=\(response.message)")
            return response.success
        } catch {
            print("Error updating gist: \(error)")
            throw error
        }
    }
    
    /**
     * Updates the production status of a gist using the signal-based approach.
     *
     * This method implements the API's signal-based approach where an empty request body
     * is sent, and the server automatically sets the gist to:
     * - inProduction = true
     * - productionStatus = "Reviewing Content"
     *
     * - Parameters:
     *   - userId: The user's unique identifier
     *   - gistId: The gist's unique identifier
     *
     * - Returns: True if the update was successful
     * - Throws: GistaError if there's an issue with the request or response
     */
    public func updateGistProductionStatus(userId: String, gistId: String) async throws -> Bool {
        print("🔄 STARTING: Update gist production status using signal-based approach")
        print("📋 Details: User ID: \(userId), Gist ID: \(gistId)")
        
        // Use the endpoint definition which now points to the correct path
        let endpoint = Endpoint.updateGistProductionStatus(userId: userId, gistId: gistId)
        
        // Get the URL from the endpoint
        guard let url = endpoint.url(baseURL: baseURL) else {
            print("❌ Failed to construct URL")
            throw GistaError.invalidURL
        }
        
        print("🔗 Using URL: \(url.absoluteString)")
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Empty JSON object as body (signal-based approach)
        let emptyBody = "{}".data(using: .utf8)
        request.httpBody = emptyBody
        
        do {
            print("📤 Sending request...")
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                throw GistaError.invalidResponse
            }
            
            print("📥 Response status code: \(httpResponse.statusCode)")
            
            // Log the response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Response body: \(responseString)")
            }
            
            // Parse the response for success
            if (200...299).contains(httpResponse.statusCode) {
                // Try to decode the success response
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(StatusResponse.self, from: data)
                    print("✅ SUCCESS: \(response.message)")
                    return response.success
                } catch {
                    // If we can't decode the specific response format but the HTTP status is success
                    print("⚠️ Could not decode response, but HTTP status indicates success: \(error)")
                    print("✅ Assuming success based on HTTP status code")
                    return true
                }
            } else {
                print("❌ Failed with status code: \(httpResponse.statusCode)")
                throw GistaError.unexpectedStatus(httpResponse.statusCode)
            }
        } catch {
            print("❌ Error updating gist production status: \(error)")
            throw error
        }
    }
    
    public func deleteGist(userId: String, gistId: String) async throws -> Bool {
        let endpoint = Endpoint.deleteGist(userId: userId, gistId: gistId)
        let response: DeleteResponse = try await performRequest(endpoint)
        return response.message.contains("deleted successfully")
    }
    
    public func fetchGists(userId: String) async throws -> [Gist] {
        let endpoint = Endpoint.fetchGists(userId: userId)
        do {
            let response: GistsResponse = try await performRequest(endpoint)
            return response.gists
        } catch {
            print("Error fetching gists: \(error)")
            
            // If it's a decoding error, try to extract the gists manually
            if case GistaError.decodingError = error {
                print("Attempting to extract gists manually from response")
                
                // Get the raw response data
                let (data, _) = try await performRawRequest(endpoint)
                
                // Try to parse the JSON manually
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let gistsArray = json["gists"] as? [[String: Any]] {
                    
                    // Create gists from the array
                    var gists: [Gist] = []
                    for gistData in gistsArray {
                        if let title = gistData["title"] as? String,
                           let category = gistData["category"] as? String,
                           let link = gistData["link"] as? String {
                            
                            // Extract other fields
                            let gistId = gistData["gistId"] as? String
                            let imageUrl = gistData["image_url"] as? String ?? "https://example.com/image.jpg"
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
                            let gist = Gist(
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
                            
                            gists.append(gist)
                        }
                    }
                    
                    print("Successfully extracted \(gists.count) gists manually")
                    return gists
                }
            }
            
            throw error
        }
    }
    
    public func fetchCategories() async throws -> [GistCategory] {
        let response: GistaServiceCategories = try await performRequest(GistaService.Endpoint.fetchCategories)
        return response.categories
    }
    
    public func fetchCategory(slug: String) async throws -> GistCategory {
        return try await performRequest(GistaService.Endpoint.fetchCategory(slug: slug))
    }
    
    public func createCategory(name: String, tags: [String]) async throws -> GistCategory {
        return try await performRequest(GistaService.Endpoint.createCategory(name: name, tags: tags))
    }
    
    public func updateCategory(id: String, name: String?, tags: [String]?) async throws -> GistCategory {
        return try await performRequest(GistaService.Endpoint.updateCategory(id: id, name: name, tags: tags))
    }
}

// MARK: - Network Request
private extension GistaService {
    // Helper method to perform a request and decode the response
    private func performRequest<T: Decodable>(_ endpoint: Endpoint,
                                          config: GistaService.RequestConfig = .default) async throws -> T {
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
            encoder.keyEncodingStrategy = .convertToSnakeCase
            
            // Ensure date encoding is consistent
            encoder.dateEncodingStrategy = .iso8601
            
            request.httpBody = try encoder.encode(body)
        }
        
        return try await performSingleRequest(request: request, endpoint: endpoint)
    }
    
    // Helper method for single request (no retries)
    private func performSingleRequest<T: Decodable>(request: URLRequest, endpoint: Endpoint) async throws -> T {
        // Log request details for debugging
        #if DEBUG
        print("Request URL: \(request.url?.absoluteString ?? "Unknown URL")")
        print("Request Method: \(request.httpMethod ?? "Unknown Method")")
        
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("Request Body: \(bodyString)")
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
            
            // Additional debug info for gist update
            if endpoint.path.contains("/gists/update/") {
                print("Gist update response: \(responseString)")
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
                                  config: GistaService.RequestConfig = .default) async throws -> (Data, URLResponse) {
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
            encoder.keyEncodingStrategy = .convertToSnakeCase
            
            // Ensure date encoding is consistent
            encoder.dateEncodingStrategy = .iso8601
            
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
        case storeLink(userId: String, category: String, url: String, title: String, autoCreateGist: Bool)
        case updateLinkGistStatus(userId: String, linkId: String, gistId: String, imageUrl: String, title: String)
        case fetchLinks(userId: String)
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
                return "/links/update-gist-status/\(userId)/\(linkId)"
            case let .fetchLinks(userId):
                return "/links/\(userId)"
            case let .updateGistStatus(userId, gistId, _, _, _):
                return "/gists/update/\(userId)/\(gistId)"
            case let .updateGistProductionStatus(userId, gistId):
                // Based on API documentation, the correct endpoint is:
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
            case .createUser, .storeLink, .createCategory:
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
                // Use the username_UUID format for consistent user IDs
                let consistentUserId = "\(username)_\(UUID().uuidString)"
                return CreateUserRequest(userId: consistentUserId, email: email, password: password, username: username)
            case let .updateUser(userId, username, email):
                return ["user_id": userId, "username": username, "email": email]
            case .deleteUser:
                return nil // DELETE requests typically don't have a body
            case let .storeLink(userId, category, url, title, autoCreateGist):
                return ArticleRequest(
                    userId: userId,
                    article: ArticleRequest.ArticleData(
                        category: category,
                        url: url,
                        title: title
                    ),
                    autoCreateGist: autoCreateGist
                )
            case let .updateLinkGistStatus(_, _, gistId, imageUrl, title):
                return [
                    "gist_id": gistId,
                    "image_url": imageUrl,
                    "link_title": title
                ]
            case let .updateGistStatus(_, _, status, isPlayed, ratings):
                return GistUpdateRequest(status: status, isPlayed: isPlayed, ratings: ratings)
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
            // Debug the path
            print("Constructing URL with path: \(path)")
            
            // Check if the base URL already includes /api
            if baseURL.absoluteString.hasSuffix("/api") {
                // For production URL that already includes /api
                let fullURL = baseURL.absoluteString + path
                print("Full URL (production): \(fullURL)")
                return URL(string: fullURL)
            } else {
                // For development URL
                let pathWithSlash = path.hasPrefix("/") ? path : "/\(path)"
                let fullURL = baseURL.absoluteString + pathWithSlash
                print("Full URL (development): \(fullURL)")
                return URL(string: fullURL)
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

// MARK: - Request Configuration

struct GistUpdateResponse: Codable {
    let success: Bool
    let message: String
    
    init(success: Bool, message: String) {
        self.success = success
        self.message = message
    }
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
    }
}

// Response wrapper for gists
struct GistsResponse: Codable {
    let gists: [Gist]
    
    enum CodingKeys: String, CodingKey {
        case gists
    }
}




