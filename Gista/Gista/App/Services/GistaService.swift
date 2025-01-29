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
    func updateUser(username: String, email: String) async throws -> Bool
    func storeArticle(userId: String, article: Article) async throws -> Article
    func updateArticleGistStatus(userId: String, articleId: String, gistId: String, imageUrl: String, title: String) async throws -> Article
    func fetchArticles(userId: String) async throws -> [Article]
    func createGist(userId: String, gist: GistRequest) async throws -> Gist
    func updateGistStatus(userId: String, gistId: String, status: GistStatus) async throws -> Bool
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
    
    func updateUser(username: String, email: String) async throws -> Bool {
        let endpoint = Endpoint.updateUser(username: username, email: email)
        return try await performRequest(endpoint)
    }
    
    func storeArticle(userId: String, article: Article) async throws -> Article {
        let endpoint = Endpoint.storeLink(
            userId: userId,
            category: article.category,
            url: article.url.absoluteString,
            title: article.title
        )
        let response: ArticleResponse = try await performRequest(endpoint)
        return Article(from: response)
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
        return try await performRequest(endpoint)
    }
    
    func updateGistStatus(userId: String, gistId: String, status: GistStatus) async throws -> Bool {
        let endpoint = Endpoint.updateGistStatus(userId: userId, gistId: gistId, status: status)
        return try await performRequest(endpoint)
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
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        // Attempt request with retry
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
                }
                #endif
                
                switch httpResponse.statusCode {
                case 200...299:
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    return try decoder.decode(T.self, from: data)
                    
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
}

// MARK: - Endpoints
private extension GistaService {
    enum Endpoint {
        case createUser(email: String, password: String, username: String)
        case updateUser(username: String, email: String)
        case storeLink(userId: String, category: String, url: String, title: String)
        case updateLinkGistStatus(userId: String, linkId: String, gistId: String, imageUrl: String, title: String)
        case fetchLinks(userId: String)
        case createGist(userId: String, gist: GistRequest)
        case updateGistStatus(userId: String, gistId: String, status: GistStatus)
        case fetchGists(userId: String)
        case fetchCategories
        case fetchCategory(slug: String)
        case createCategory(name: String, tags: [String])
        case updateCategory(id: String, name: String?, tags: [String]?)
        
        var path: String {
            switch self {
            case .createUser:
                return "/auth/create-user"
            case .updateUser:
                return "/auth/update-user"
            case .storeLink:
                return "/links/store"
            case let .updateLinkGistStatus(userId, linkId, _, _, _):
                return "/links/update-gist-status/\(userId)/\(linkId)"
            case let .fetchLinks(userId):
                return "/links/\(userId)"
            case let .createGist(userId, _):
                return "/gists/add/\(userId)"
            case let .updateGistStatus(userId, gistId, _):
                return "/gists/update/\(userId)/\(gistId)"
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
            case .updateUser, .updateLinkGistStatus, .updateGistStatus, .updateCategory:
                return .put
            case .fetchLinks, .fetchGists, .fetchCategories, .fetchCategory:
                return .get
            }
        }
        
        var body: Encodable? {
            switch self {
            case let .createUser(email, password, username):
                return ["email": email, "password": password, "username": username]
            case let .updateUser(username, email):
                return ["username": username, "email": email]
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
            case let .updateGistStatus(_, _, status):
                return status
            case .fetchCategories, .fetchCategory:
                return nil
            case let .createCategory(name, tags):
                return CategoryRequest(name: name, tags: tags)
            case let .updateCategory(id, name, tags):
                return CategoryRequest(name: name, tags: tags)
            case .fetchLinks, .fetchGists:
                return nil
            }
        }
        
        func url(baseURL: URL) -> URL? {
            return URL(string: path, relativeTo: baseURL)
        }
    }
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
}

