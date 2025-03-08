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
    
    // Shared test user data
    private let testEmail = "gista_test_\(Int(Date().timeIntervalSince1970))@example.com"
    private let testPassword = "TestPassword123!"
    private let testUsername = "gista_test_\(Int(Date().timeIntervalSince1970))"
    private var testUserId: String?
    
    // Shared test data IDs for cleanup
    private var createdArticleIds: [String] = []
    private var createdGistIds: [String] = []
    
    /// Sets up the test environment and creates a shared test user
    func setUp() async throws {
        // Initialize service without auth token initially
        service = GistaService(
            environment: .development // Use development environment for testing
        )
        
        // Create a shared test user if needed
        if testUserId == nil {
            let user = try await service.createUser(
                email: testEmail,
                password: testPassword,
                username: testUsername
            )
            testUserId = user.userId
            print("Created test user with ID: \(user.userId)")
        }
    }
    
    /// Tears down the test environment and cleans up all test data
    func tearDown() async throws {
        // Clean up all created gists
        if let userId = testUserId {
            for gistId in createdGistIds {
                do {
                    let deleted = try await service.deleteGist(userId: userId, gistId: gistId)
                    print("Deleted gist \(gistId): \(deleted)")
                } catch {
                    print("Warning: Failed to delete gist \(gistId): \(error)")
                }
            }
            
            // Finally delete the test user
            do {
                let deleted = try await service.deleteUser(userId: userId)
                print("Deleted test user \(userId): \(deleted)")
                testUserId = nil
            } catch {
                print("Warning: Failed to delete test user \(userId): \(error)")
            }
        }
        
        // Clear tracking arrays
        createdArticleIds = []
        createdGistIds = []
        
        // Clear service
        service = nil
    }
    
    // MARK: - Comprehensive Integration Test
    
    /// Runs a comprehensive test of the Gista API:
    /// 1. Create user (in setUp)
    /// 2. Store an article
    /// 3. Create a gist
    /// 4. Update gist status
    /// 5. Fetch gists and articles
    /// 6. Clean up (in tearDown)
    @Test
    func testGistaWorkflow() async throws {
        try skipIfNotRunningIntegrationTests()
        
        // Setup test environment
        try await setUp()
        defer { try? await tearDown() }
        
        guard let userId = testUserId else {
            throw XCTSkip("Test user creation failed")
        }
        
        print("Running integration test with user ID: \(userId)")
        
        // 1. Store an article
        let testArticle = Article(
            title: "Integration Test Article \(Date())",
            url: URL(string: "https://example.com/test-article")!,
            duration: 120,
            category: "Technology"
        )
        
        let storedArticle = try await service.storeArticle(
            userId: userId,
            article: testArticle
        )
        
        print("Stored article: \(storedArticle.title)")
        if let articleId = storedArticle.gistStatus?.articleId {
            createdArticleIds.append(articleId)
            print("Tracking article ID for cleanup: \(articleId)")
        }
        
        // Verify article was stored
        #expect(storedArticle.title == testArticle.title, "Stored article title should match")
        
        // 2. Create a gist
        let testGist = GistRequest(
            title: "Integration Test Gist \(Date())",
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
        
        print("Created gist: \(createdGist.title)")
        let gistId = createdGist.id.uuidString
        createdGistIds.append(gistId)
        print("Tracking gist ID for cleanup: \(gistId)")
        
        // Verify gist was created
        #expect(createdGist.title == testGist.title, "Created gist title should match")
        
        // 3. Update gist status
        let updateResult = try await service.updateGistStatus(
            userId: userId,
            gistId: gistId,
            status: GistStatus(inProduction: true, productionStatus: "In Production"),
            isPlayed: true,
            ratings: 5
        )
        
        print("Updated gist status: \(updateResult)")
        
        // Verify update was successful
        #expect(updateResult, "Gist status update should succeed")
        
        // 4. Fetch gists
        let gists = try await service.fetchGists(userId: userId)
        
        print("Fetched \(gists.count) gists")
        
        // Verify gists were returned
        #expect(!gists.isEmpty, "Should return at least one gist")
        #expect(gists.contains { $0.title == testGist.title }, "Should contain the created gist")
        
        // 5. Fetch articles
        let articles = try await service.fetchArticles(userId: userId)
        
        print("Fetched \(articles.count) articles")
        
        // Verify articles were returned
        #expect(!articles.isEmpty, "Should return at least one article")
        #expect(articles.contains { $0.title == testArticle.title }, "Should contain the stored article")
        
        // 6. Fetch categories (doesn't require user)
        let categories = try await service.fetchCategories()
        
        print("Fetched \(categories.count) categories")
        
        // Verify categories were returned
        #expect(!categories.isEmpty, "Should return at least one category")
        
        // Cleanup happens in tearDown
    }
    
    // MARK: - Helper Functions
    
    /// Skips the test if integration tests are not enabled
    private func skipIfNotRunningIntegrationTests() throws {
        if !runIntegrationTests {
            throw XCTSkip("Skipping integration test. Set RUN_INTEGRATION_TESTS=YES to run.")
        }
    }
} 