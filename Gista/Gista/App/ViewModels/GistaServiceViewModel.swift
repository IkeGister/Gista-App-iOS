//
//  GistaServiceViewModel.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/7/25.
//

import Foundation
import SwiftUI
import Combine
import Shared

// MARK: - ViewModel
class GistaServiceViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var articles: [Article] = []
    @Published var gists: [Gist] = []
    @Published var categories: [Category] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Properties
    let gistaService: GistaServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var _userId: String?
    
    // Public getter for userId
    var userId: String? {
        return _userId
    }
    
    // Public setter for userId (for testing purposes)
    func setUserId(_ userId: String) {
        self._userId = userId
    }
    
    // MARK: - Initialization
    init(gistaService: GistaServiceProtocol = GistaService()) {
        self.gistaService = gistaService
    }
    
    // MARK: - User Management
    func createUser(email: String, password: String, username: String) async throws {
        var thrownError: Error?
        
        await executeTask { [weak self] in
            guard let self = self else { return nil }
            do {
                let user = try await self.gistaService.createUser(email: email, password: password, username: username)
                self._userId = user.userId
                return "User created successfully"
            } catch {
                thrownError = error
                throw error // Rethrow to be caught by executeTask
            }
        }
        
        if let error = thrownError {
            throw error
        }
    }
    
    func updateUser(username: String, email: String) async throws {
        var thrownError: Error?
        
        await executeTask { [weak self] in
            guard let self = self, let userId = self._userId else {
                let error = GistaError.unauthorized
                thrownError = error
                throw error
            }
            
            do {
                let success = try await self.gistaService.updateUser(userId: userId, username: username, email: email)
                return success ? "User updated successfully" : "Failed to update user"
            } catch {
                thrownError = error
                throw error
            }
        }
        
        if let error = thrownError {
            throw error
        }
    }
    
    func deleteUser() async throws {
        var thrownError: Error?
        
        await executeTask { [weak self] in
            guard let self = self, let userId = self._userId else {
                let error = GistaError.unauthorized
                thrownError = error
                throw error
            }
            
            do {
                let success = try await self.gistaService.deleteUser(userId: userId)
                if success {
                    self._userId = nil
                }
                return success ? "User deleted successfully" : "Failed to delete user"
            } catch {
                thrownError = error
                throw error
            }
        }
        
        if let error = thrownError {
            throw error
        }
    }
    
    // MARK: - Article Management
    func storeArticle(article: Article) async {
        await executeTask { [weak self] in
            guard let self = self, let userId = self._userId else {
                throw GistaError.unauthorized
            }
            let storedArticle = try await self.gistaService.storeArticle(
                userId: userId,
                article: article
            )
            await MainActor.run {
                self.articles.append(storedArticle)
            }
            return "Article stored successfully"
        }
    }
    
    func updateArticleGistStatus(articleId: String, gistId: String, imageUrl: String, title: String) async {
        await executeTask { [weak self] in
            guard let self = self, let userId = self._userId else {
                throw GistaError.unauthorized
            }
            let updatedArticle = try await self.gistaService.updateArticleGistStatus(
                userId: userId,
                articleId: articleId,
                gistId: gistId,
                imageUrl: imageUrl,
                title: title
            )
            
            await MainActor.run {
                if let index = self.articles.firstIndex(where: { $0.id.uuidString == articleId }) {
                    self.articles[index] = updatedArticle
                }
            }
            return "Article updated successfully"
        }
    }
    
    func fetchArticles() async {
        await executeTask { [weak self] in
            guard let self = self, let userId = self._userId else {
                throw GistaError.unauthorized
            }
            let fetchedArticles = try await self.gistaService.fetchArticles(userId: userId)
            await MainActor.run {
                self.articles = fetchedArticles
            }
            return "Articles fetched successfully"
        }
    }
    
    // MARK: - Gist Management
    func createGist(gist: GistRequest) async {
        await executeTask { [weak self] in
            guard let self = self, let userId = self._userId else {
                throw GistaError.unauthorized
            }
            let createdGist = try await self.gistaService.createGist(userId: userId, gist: gist)
            await MainActor.run {
                self.gists.append(createdGist)
            }
            return "Gist created successfully"
        }
    }
    
    func updateGistStatus(gistId: String, status: GistStatus, isPlayed: Bool? = nil, ratings: Int? = nil) async {
        await executeTask { [weak self] in
            guard let self = self, let userId = self._userId else {
                throw GistaError.unauthorized
            }
            let success = try await self.gistaService.updateGistStatus(
                userId: userId,
                gistId: gistId,
                status: status,
                isPlayed: isPlayed,
                ratings: ratings
            )
            
            if success {
                await self.fetchGists()
            }
            
            return success ? "Gist updated successfully" : "Failed to update gist"
        }
    }
    
    func updateGistProductionStatus(gistId: String) async {
        await executeTask { [weak self] in
            guard let self = self, let userId = self._userId else {
                throw GistaError.unauthorized
            }
            let success = try await self.gistaService.updateGistProductionStatus(
                userId: userId,
                gistId: gistId
            )
            
            if success {
                await self.fetchGists()
            }
            
            return success ? "Gist production status updated successfully" : "Failed to update gist production status"
        }
    }
    
    func deleteGist(gistId: String) async {
        await executeTask { [weak self] in
            guard let self = self, let userId = self._userId else {
                throw GistaError.unauthorized
            }
            let success = try await self.gistaService.deleteGist(userId: userId, gistId: gistId)
            
            if success {
                await MainActor.run {
                    self.gists.removeAll { $0.id.uuidString == gistId }
                }
            }
            
            return success ? "Gist deleted successfully" : "Failed to delete gist"
        }
    }
    
    func fetchGists() async {
        await executeTask { [weak self] in
            guard let self = self, let userId = self._userId else {
                throw GistaError.unauthorized
            }
            let fetchedGists = try await self.gistaService.fetchGists(userId: userId)
            await MainActor.run {
                self.gists = fetchedGists
            }
            return "Gists fetched successfully"
        }
    }
    
    // MARK: - Category Management
    func fetchCategories() async {
        await executeTask { [weak self] in
            guard let self = self else { return nil }
            let fetchedCategories = try await self.gistaService.fetchCategories()
            await MainActor.run {
                self.categories = fetchedCategories
            }
            return "Categories fetched successfully"
        }
    }
    
    func fetchCategory(slug: String) async -> Category? {
        var category: Category?
        await executeTask { [weak self] in
            guard let self = self else { return nil }
            category = try await self.gistaService.fetchCategory(slug: slug)
            return "Category fetched successfully"
        }
        return category
    }
    
    func createCategory(name: String, tags: [String]) async {
        await executeTask { [weak self] in
            guard let self = self else { return nil }
            let newCategory = try await self.gistaService.createCategory(name: name, tags: tags)
            await MainActor.run {
                self.categories.append(newCategory)
            }
            return "Category created successfully"
        }
    }
    
    func updateCategory(id: String, name: String?, tags: [String]?) async {
        await executeTask { [weak self] in
            guard let self = self else { return nil }
            let updatedCategory = try await self.gistaService.updateCategory(id: id, name: name, tags: tags)
            
            await MainActor.run {
                if let index = self.categories.firstIndex(where: { $0.id == id }) {
                    self.categories[index] = updatedCategory
                }
            }
            
            return "Category updated successfully"
        }
    }
    
    // MARK: - Helper Methods
    private func executeTask(_ task: @escaping () async throws -> String?) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.showError = false
        }
        
        do {
            let message = try await task()
            if let message = message {
                print(message)
            }
        } catch let error as GistaError {
            await MainActor.run {
                self.errorMessage = error.errorDescription
                self.showError = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Authentication
    var isAuthenticated: Bool {
        return _userId != nil
    }
    
    // MARK: - Reset
    func reset() {
        _userId = nil
        articles.removeAll()
        gists.removeAll()
        categories.removeAll()
        errorMessage = nil
        showError = false
    }
}

