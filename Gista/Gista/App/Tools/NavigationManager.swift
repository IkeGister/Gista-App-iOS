//
//  NavigationManager.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import SwiftUI

enum NavigationPath: Hashable {
    case library
    case onboarding
    case settings
    case userProfile
    case playback(articleId: UUID)
}

@MainActor
class NavigationManager: ObservableObject {
    @Published var path = NavigationPath.self
    @Published var navigationPath = [NavigationPath]()
    
    // Navigation state
    @Published var showingSettings = false
    @Published var showingProfile = false
    @Published var showingPlayback = false
    
    // Navigation methods
    func navigateToLibrary() {
        navigationPath.append(.library)
    }
    
    func navigateToOnboarding() {
        navigationPath.append(.onboarding)
    }
    
    func navigateToSettings() {
        showingSettings = true
    }
    
    func navigateToProfile() {
        showingProfile = true
    }
    
    func navigateToPlayback(articleId: UUID) {
        navigationPath.append(.playback(articleId: articleId))
    }
    
    func popToRoot() {
        navigationPath.removeAll()
    }
    
    func popBack() {
        navigationPath.removeLast()
    }
}

// Navigation View Modifier
struct NavigationStackContainer: ViewModifier {
    @StateObject private var navigationManager = NavigationManager()
    
    func body(content: Content) -> some View {
        NavigationStack(path: $navigationManager.navigationPath) {
            content
                .navigationDestination(for: NavigationPath.self) { path in
                    switch path {
                    case .library:
                        LibraryView()
                    case .onboarding:
                        OnboardingView()
                    case .settings:
                        Settings()
                    case .userProfile:
                        UserProfile()
                    case .playback(let articleId):
                        PlaybackView(articleId: articleId)
                    }
                }
                .sheet(isPresented: $navigationManager.showingSettings) {
                    Settings()
                }
                .sheet(isPresented: $navigationManager.showingProfile) {
                    UserProfile()
                }
        }
        .environmentObject(navigationManager)
    }
}

// View Extension for easy access
extension View {
    func withNavigationStack() -> some View {
        modifier(NavigationStackContainer())
    }
}

