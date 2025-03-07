//
//  GistaServiceIntegrationTests.swift
//  GistaTests
//
//  Created by Tony Nlemadim on 2/16/25.
//

import Testing
import Foundation
@testable import Gista

/// Integration tests for GistaService that make actual network calls.
/// These tests verify that the service can properly communicate with the real API.
///
/// To run these tests:
/// 1. Set the RUN_INTEGRATION_TESTS environment variable to "YES"
/// 2. Provide valid test credentials in TestCredentials.swift
@MainActor
final class GistaServiceIntegrationTests {
    
    // Flag to control whether integration tests run
    private var runIntegrationTests: Bool {
        ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] == "YES"
    }
    
    // Test service instance
    private var service: GistaService!
    
    // Test user credentials and data
    private let testEmail = TestCredentials.email
    private let testPassword = TestCredentials.password
    private let testUsername = TestCredentials.username
    private var testUserId: String?
    
    /// Sets up the test environment
    func setUp() {
        service = GistaService(
            environment: .development, // Use development environment for testing
            authToken: TestCredentials.authToken
        )
    }
    
    /// Tears down the test environment
    func tearDown() {
        service = nil
    }
    
    // MARK: - Helper Methods
    
    /// Creates a test user for integration testing
    /// - Returns: The user ID of the created user
    private func createTestUser() async throws -> String {
        let user = try await service.createUser(
            email: testEmail,
            password: testPassword,
            username: testUsername
        )
        return user.userId
    }
    
    /// Cleans up test data after tests
    private func cleanupTestData(userId: String) async {
        do {
            _ = try await service.deleteUser(userId: userId)
        } catch {
            print("Warning: Failed to clean up test user: \(error)")
        }
    }
    
    // MARK: - Test Cases
    
    /// Tests the complete user lifecycle:
    /// 1. Create a user
    /// 2. Update user information
    /// 3. Delete the user
    @Test
    func testUserLifecycle() async throws {
        try skipIfNotRunningIntegrationTests()
        
        setUp()
        defer { tearDown() }
        
        // 1. Create user
        let user = try await service.createUser(
            email: "\(UUID().uuidString)@example.com", // Use unique email
            password: "SecurePassword123!",
            username: "testuser_\(Int(Date().timeIntervalSince1970))" // Use unique username
        )
        
        // Verify user was created
        #expect(!user.userId.isEmpty, "Should return a valid user ID")
        
        let userId = user.userId
        defer { Task { await cleanupTestData(userId: userId) } }
        
        // 2. Update user
        let updateResult = try await service.updateUser(
            username: "updated_\(user.userId)",
            email: "updated_\(UUID().uuidString)@example.com"
        )
        
        // Verify update was successful
        #expect(updateResult, "User update should succeed")
        
        // 3. Delete user
        let deleteResult = try await service.deleteUser(userId: userId)
        
        // Verify deletion was successful
        #expect(deleteResult, "User deletion should succeed")
    }
    
    /// Tests category operations:
    /// 1. Fetch all categories
    /// 2. Fetch a specific category by slug
    @Test
    func testCategoryOperations() async throws {
        try skipIfNotRunningIntegrationTests()
        
        setUp()
        defer { tearDown() }
        
        // 1. Fetch all categories
        let categories = try await service.fetchCategories()
        
        // Verify categories were returned
        #expect(!categories.isEmpty, "Should return at least one category")
        
        // 2. Fetch a specific category if available
        if let firstCategory = categories.first {
            let category = try await service.fetchCategory(slug: firstCategory.slug)
            
            // Verify category details
            #expect(category.id == firstCategory.id, "Should return the correct category")
            #expect(category.name == firstCategory.name, "Category name should match")
        }
    }
    
    /// Tests article operations:
    /// 1. Create a test user
    /// 2. Store an article
    /// 3. Fetch articles
    /// 4. Clean up
    @Test
    func testArticleOperations() async throws {
        try skipIfNotRunningIntegrationTests()
        
        setUp()
        defer { tearDown() }
        
        // 1. Create test user
        let userId = try await createTestUser()
        defer { Task { await cleanupTestData(userId: userId) } }
        
        // 2. Store an article
        let testArticle = Article(
            title: "Integration Test Article",
            url: URL(string: "https://example.com/test-article")!,
            duration: 120,
            category: "Technology"
        )
        
        let storedArticle = try await service.storeArticle(
            userId: userId,
            article: testArticle
        )
        
        // Verify article was stored
        #expect(storedArticle.title == testArticle.title, "Stored article title should match")
        
        // 3. Fetch articles
        let articles = try await service.fetchArticles(userId: userId)
        
        // Verify articles were returned
        #expect(!articles.isEmpty, "Should return at least one article")
        #expect(articles.contains { $0.title == testArticle.title }, "Should contain the stored article")
    }
    
    /// Tests gist operations:
    /// 1. Create a test user
    /// 2. Create a gist
    /// 3. Update gist status
    /// 4. Fetch gists
    /// 5. Delete gist
    /// 6. Clean up
    @Test
    func testGistOperations() async throws {
        try skipIfNotRunningIntegrationTests()
        
        setUp()
        defer { tearDown() }
        
        // 1. Create test user
        let userId = try await createTestUser()
        defer { Task { await cleanupTestData(userId: userId) } }
        
        // 2. Create a gist
        let testGist = GistRequest(
            title: "Integration Test Gist",
            link: "https://example.com/test-gist",
            imageUrl: "https://example.com/image.jpg",
            category: "Technology",
            segments: [
                GistSegment(
                    duration: 60,
                    title: "Test Segment",
                    audioUrl: "https://example.com/audio.mp3",
                    segmentIndex: 0
                )
            ],
            playbackDuration: 60
        )
        
        let createdGist = try await service.createGist(
            userId: userId,
            gist: testGist
        )
        
        // Verify gist was created
        #expect(createdGist.title == testGist.title, "Created gist title should match")
        
        // Store gist ID for later operations
        let gistId = createdGist.id.uuidString
        
        // 3. Update gist status
        let updateResult = try await service.updateGistStatus(
            userId: userId,
            gistId: gistId,
            status: GistStatus(inProduction: true, productionStatus: "In Production"),
            isPlayed: true,
            ratings: 5
        )
        
        // Verify update was successful
        #expect(updateResult, "Gist status update should succeed")
        
        // 4. Fetch gists
        let gists = try await service.fetchGists(userId: userId)
        
        // Verify gists were returned
        #expect(!gists.isEmpty, "Should return at least one gist")
        #expect(gists.contains { $0.title == testGist.title }, "Should contain the created gist")
        
        // 5. Delete gist
        let deleteResult = try await service.deleteGist(
            userId: userId,
            gistId: gistId
        )
        
        // Verify deletion was successful
        #expect(deleteResult, "Gist deletion should succeed")
    }
    
    // MARK: - Helper Functions
    
    /// Skips the test if integration tests are not enabled
    private func skipIfNotRunningIntegrationTests() throws {
        if !runIntegrationTests {
            throw XCTSkip("Skipping integration test. Set RUN_INTEGRATION_TESTS=YES to run.")
        }
    }
} 