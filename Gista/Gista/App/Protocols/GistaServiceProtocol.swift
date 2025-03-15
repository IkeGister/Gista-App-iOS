//
//  GistaServiceProtocol.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//


import Foundation
import Shared

public protocol GistaServiceProtocol {
    func createUser(email: String, password: String, username: String) async throws -> User
    func updateUser(userId: String, username: String, email: String) async throws -> Bool
    func deleteUser(userId: String) async throws -> Bool
    func storeArticle(userId: String, article: Article, autoCreateGist: Bool) async throws -> GistaServiceResponse
    func updateArticleGistStatus(userId: String, articleId: String, gistId: String, imageUrl: String, title: String) async throws -> Article
    func fetchArticles(userId: String) async throws -> [Article]
    func updateGistStatus(userId: String, gistId: String, status: GistStatus, isPlayed: Bool?, ratings: Int?) async throws -> Bool
    func updateGistProductionStatus(userId: String, gistId: String) async throws -> Bool
    func deleteGist(userId: String, gistId: String) async throws -> Bool
    func fetchGists(userId: String) async throws -> [Gist]
    func fetchCategories() async throws -> [GistCategory]
    func fetchCategory(slug: String) async throws -> GistCategory
    func createCategory(name: String, tags: [String]) async throws -> GistCategory
    func updateCategory(id: String, name: String?, tags: [String]?) async throws -> GistCategory
}
