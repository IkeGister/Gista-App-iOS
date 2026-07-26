//
//  GistaModelContainer.swift
//  Gista
//
//  Composition root for the SwiftData store (spec §6). The store lives in
//  the app container at the default location — NOT the app group. The share
//  extension never opens the store; its only channel is the ShareQueue
//  app-group defaults, which keeps SwiftData single-process (decided).
//
//  Exposed as a shared container (rather than only `.modelContainer(for:)`)
//  so later waves can hand `mainContext` / background contexts to
//  GistPipeline and PlayerEngine without going through the SwiftUI
//  environment.
//

import Foundation
import SwiftData

enum GistaModelContainer {
    /// Schema version 1 — clean slate, no legacy data, no migration story
    /// (spec §6: the old library was sample structs; nothing persisted).
    static let shared: ModelContainer = {
        let schema = Schema([GistSource.self, GistRendition.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Unrecoverable: a local store that cannot open means no app.
            // Same failure mode as SwiftUI's `.modelContainer(for:)`.
            fatalError("Failed to create Gista ModelContainer: \(error)")
        }
    }()

    /// In-memory container for unit tests and previews
    /// (`ModelConfiguration(isStoredInMemoryOnly: true)`, spec §10).
    static func inMemory() throws -> ModelContainer {
        let schema = Schema([GistSource.self, GistRendition.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
