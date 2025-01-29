//
//  GistaTests.swift
//  GistaTests
//
//  Created by Tony Nlemadim on 1/2/25.
//

import Testing
import Foundation
@testable import Gista

// MARK: - Mock URLSession
/// A mock implementation of URLSession for testing.
/// This class allows us to control the response data, errors, and status codes
/// that would normally come from a network request.
@MainActor
final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    /// Data to be returned by the mock session
    var mockData: Data?
    /// Response to be returned by the mock session
    var mockResponse: URLResponse?
    /// Error to be thrown by the mock session if needed
    var mockError: Error?
    
    init(mockData: Data? = nil, mockResponse: URLResponse? = nil, mockError: Error? = nil) {
        self.mockData = mockData
        self.mockResponse = mockResponse
        self.mockError = mockError
    }
    
    /// Factory method to create a new mock session
    static func createMockSession() -> MockURLSession {
        return MockURLSession()
    }
    
    /// Simulates the data task of a real URLSession
    /// - Returns: Tuple of (Data, URLResponse) or throws an error
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        return (
            mockData ?? Data(),
            mockResponse ?? HTTPURLResponse(url: request.url!, 
                                         statusCode: 200, 
                                         httpVersion: Optional<String>.none, 
                                         headerFields: Optional<[String: String]>.none)!
        )
    }
}

// MARK: - Test Data Factory
/// Factory for creating mock data used in tests.
/// Centralizes the creation of test data to maintain consistency across tests.
enum TestDataFactory {
    /// Creates a mock user with predefined test values
    static func createMockUser() -> User {
        return User(userId: "test123", message: "User created successfully")
    }
    
    /// Creates a mock article response from the API
    static func createMockArticleResponse() -> ArticleResponse {
        return ArticleResponse(
            category: "Technology",
            dateAdded: Date(),
            gistCreated: ArticleGistStatus(
                gistCreated: false,
                gistId: nil,
                imageUrl: nil,
                articleId: "article123",
                title: "Test Article",
                type: "Web",
                url: "https://example.com"
            )
        )
    }
    
    /// Creates a mock article with test data
    static func createMockArticle() -> Article {
        return Article(
            title: "Test Article",
            url: URL(string: "https://example.com")!,
            duration: 120,
            category: "Technology"
        )
    }
    
    /// Creates a mock gist with test data and segments
    static func createMockGist() -> Gist {
        return Gist(
            title: "Test Gist",
            category: "Technology",
            imageUrl: "https://example.com/image.jpg",
            link: "https://example.com",
            playbackDuration: 120,
            publisher: "testUser",
            segments: [
                GistSegment(
                    duration: 60,
                    title: "Test Segment",
                    audioUrl: "https://example.com/audio.mp3"
                )
            ],
            status: GistStatus(
                isDonePlaying: false,
                isNowPlaying: false,
                playbackTime: 0
            )
        )
    }
}

// MARK: - GistaService Tests
/// Test suite for GistaService
/// Tests all major functionality including:
/// - User management (creation, updates)
/// - Article management (storage, retrieval)
/// - Gist management (creation, updates, retrieval)
/// - Error handling
@MainActor
final class GistaServiceTests {
    private var mockSession: MockURLSession!
    private var service: GistaService!
    private let testUserId = "test123"
    
    /// Sets up a fresh test environment before each test
    func setUp() {
        mockSession = MockURLSession.createMockSession()
        service = GistaService(
            environment: GistaService.Environment.development,
            session: mockSession,
            authToken: "test-token"
        )
    }
    
    /// Tears down the test environment after each test
    func tearDown() {
        mockSession = nil
        service = nil
    }
    
    // MARK: - User Management Tests
    
    /// Tests user creation functionality
    /// Verifies that:
    /// - The service can create a new user
    /// - The response contains expected user data
    @Test
    func testCreateUser() async throws {
        setUp()
        defer { tearDown() }
        
        // Arrange: Set up mock response
        let mockUser = TestDataFactory.createMockUser()
        mockSession.mockData = try JSONEncoder().encode(mockUser)
        
        // Act: Attempt to create user
        let result = try await service.createUser(
            email: "test@example.com",
            password: "password123",
            username: "testuser"
        )
        
        // Assert: Verify response matches mock data
        #expect(result.userId == mockUser.userId)
        #expect(result.message == mockUser.message)
    }
    
    /// Tests user update functionality
    /// Verifies that:
    /// - The service can update user information
    /// - The update operation returns success
    @Test
    func testUpdateUser() async throws {
        setUp()
        defer { tearDown() }
        
        // Arrange: Set up successful response
        mockSession.mockData = try JSONEncoder().encode(true)
        
        // Act: Attempt to update user
        let result = try await service.updateUser(
            username: "newUsername",
            email: "new@example.com"
        )
        
        // Assert: Verify update was successful
        #expect(result == true)
    }
    
    // MARK: - Article Management Tests
    
    /// Tests article storage functionality
    /// Verifies that:
    /// - The service can store a new article
    /// - The stored article matches the input data
    @Test
    func testStoreArticle() async throws {
        setUp()
        defer { tearDown() }
        
        // Arrange: Create mock article and response
        let mockArticle = TestDataFactory.createMockArticle()
        let mockResponse = TestDataFactory.createMockArticleResponse()
        mockSession.mockData = try JSONEncoder().encode(mockResponse)
        
        // Act: Attempt to store article
        let result = try await service.storeArticle(
            userId: testUserId,
            article: mockArticle
        )
        
        // Assert: Verify stored article matches input
        #expect(result.title == mockArticle.title)
        #expect(result.category == mockArticle.category)
    }
    
    /// Tests article fetching functionality
    /// Verifies that:
    /// - The service can retrieve articles
    /// - The retrieved articles match expected data
    @Test
    func testFetchArticles() async throws {
        setUp()
        defer { tearDown() }
        
        // Arrange: Set up mock response with articles
        let mockResponse = ArticlesResponse(
            articles: [TestDataFactory.createMockArticleResponse()],
            count: 1
        )
        mockSession.mockData = try JSONEncoder().encode(mockResponse)
        
        // Act: Attempt to fetch articles
        let result = try await service.fetchArticles(userId: testUserId)
        
        // Assert: Verify fetched articles
        #expect(result.count == 1)
        #expect(result.first?.category == "Technology")
    }
    
    // MARK: - Gist Management Tests
    
    /// Tests gist creation functionality
    /// Verifies that:
    /// - The service can create a new gist
    /// - The created gist matches the input data
    @Test
    func testCreateGist() async throws {
        setUp()
        defer { tearDown() }
        
        // Arrange: Set up mock gist and request
        let mockGist = TestDataFactory.createMockGist()
        mockSession.mockData = try JSONEncoder().encode(mockGist)
        
        let gistRequest = GistRequest(
            title: "Test Gist",
            link: "https://example.com",
            imageUrl: "https://example.com/image.jpg",
            category: "Technology",
            segments: [
                GistSegment(
                    duration: 60,
                    title: "Test Segment",
                    audioUrl: "https://example.com/audio.mp3"
                )
            ],
            playbackDuration: 120
        )
        
        // Act: Attempt to create gist
        let result = try await service.createGist(userId: testUserId, gist: gistRequest)
        
        // Assert: Verify created gist
        #expect(result.title == mockGist.title)
        #expect(result.segments.count == mockGist.segments.count)
    }
    
    /// Tests gist status update functionality
    /// Verifies that:
    /// - The service can update gist status
    /// - The update operation returns success
    @Test
    func testUpdateGistStatus() async throws {
        setUp()
        defer { tearDown() }
        
        // Arrange: Set up successful response and status
        mockSession.mockData = try JSONEncoder().encode(true)
        
        let status = GistStatus(
            isDonePlaying: true,
            isNowPlaying: false,
            playbackTime: 120
        )
        
        // Act: Attempt to update status
        let result = try await service.updateGistStatus(
            userId: testUserId,
            gistId: "gist123",
            status: status
        )
        
        // Assert: Verify update was successful
        #expect(result == true)
    }
    
    /// Tests gist fetching functionality
    /// Verifies that:
    /// - The service can retrieve gists
    /// - The retrieved gists match expected data
    @Test
    func testFetchGists() async throws {
        setUp()
        defer { tearDown() }
        
        // Arrange: Set up mock gists response
        let mockGists = [TestDataFactory.createMockGist()]
        mockSession.mockData = try JSONEncoder().encode(mockGists)
        
        // Act: Attempt to fetch gists
        let result = try await service.fetchGists(userId: testUserId)
        
        // Assert: Verify fetched gists
        #expect(result.count == 1)
        let gist = result.first
        #expect(gist?.title == "Test Gist")
    }
    
    /// Tests retry on failure functionality
    /// Verifies that:
    /// - The service can retry fetching gists after a temporary failure
    /// - The service returns data after a successful retry
    @Test
    func testRetryOnFailure() async throws {
        setUp()
        defer { tearDown() }
        
        // Arrange: Set up temporary failure then success
        var attemptCount = 0
        mockSession.mockError = GistaError.serverError("Temporary error")
        
        // Override mock data method to succeed on second attempt
        class RetryMockSession: MockURLSession {
            var attemptCount = 0
            override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
                attemptCount += 1
                if attemptCount == 1 {
                    throw GistaError.serverError("Temporary error")
                }
                return (
                    try JSONEncoder().encode(TestDataFactory.createMockGist()),
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                )
            }
        }
        
        let retrySession = RetryMockSession()
        service = GistaService(
            environment: .development,
            session: retrySession,
            authToken: "test-token"
        )
        
        // Act
        let result = try await service.fetchGists(userId: testUserId)
        
        // Assert
        #expect(retrySession.attemptCount == 2, "Should succeed on second attempt")
        #expect(!result.isEmpty, "Should return data after retry")
    }
    
    // MARK: - Error Handling Tests
    
    /// Tests unauthorized error handling
    /// Verifies that:
    /// - The service properly handles 401 responses
    /// - The correct error type is thrown
    @Test
    func testUnauthorizedError() async throws {
        setUp()
        defer { tearDown() }
        
        // Arrange: Set up 401 unauthorized response
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        
        // Act & Assert: Verify unauthorized error is thrown
        do {
            _ = try await service.fetchGists(userId: testUserId)
            #expect(Bool(false), "Expected unauthorized error but no error was thrown")
        } catch let error as GistaError {
            #expect(error == .unauthorized, "Expected unauthorized error but got \(error)")
        }
    }
    
    /// Tests network error handling
    /// Verifies that:
    /// - The service properly handles network errors
    /// - The correct error type is thrown
    @Test
    func testNetworkError() async throws {
        setUp()
        defer { tearDown() }
        
        // Arrange: Set up network error
        struct MockNetworkError: Error {}
        mockSession.mockError = MockNetworkError()
        
        // Act & Assert: Verify network error is caught
        do {
            _ = try await service.fetchGists(userId: testUserId)
            #expect(Bool(false), "Expected network error but no error was thrown")
        } catch is GistaError {
            #expect(Bool(true), "Successfully caught GistaError")
        }
    }
    
    // MARK: - Category Management Tests
    /// Tests category fetching functionality
    @Test
    func testFetchCategories() async throws {
        setUp()
        defer { tearDown() }
        
        // Arrange
        let mockCategories = CategoriesResponse(
            categories: [
                Category(id: "cat001", name: "Business", slug: "business", tags: ["finance", "economics"])
            ],
            count: 1
        )
        mockSession.mockData = try JSONEncoder().encode(mockCategories)
        
        // Act
        let result = try await service.fetchCategories()
        
        // Assert
        #expect(result.count == 1)
        #expect(result.first?.name == "Business")
    }
}
