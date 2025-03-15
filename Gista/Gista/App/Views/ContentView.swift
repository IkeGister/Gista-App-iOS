//
//  ContentView.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import SwiftUI
import SwiftData
import Shared

struct ContentView: View {
    @EnvironmentObject private var navigationManager: NavigationManager
    @State private var showTestView = false
    
    // Using UserCredentials to manage user authentication state
    @StateObject private var userCredentials = UserCredentials.shared
    
    var body: some View {
        VStack {
            // Switch statement to determine which view to show
            if userCredentials.isAuthenticated {
                // User is signed in and has a username
                LibraryView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                navigationManager.navigateToSettings()
                            } label: {
                                Image(systemName: "gear")
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                navigationManager.navigateToProfile()
                            } label: {
                                Image(systemName: "person.circle")
                            }
                        }
                        
                        // Always show the debug button in simulator for testing
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                showTestView = true
                            } label: {
                                Image(systemName: "hammer.circle")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .sheet(isPresented: $showTestView) {
                        GistaServiceTestView()
                    }
            } else {
                // User is not signed in or doesn't have a username
                OnboardingView.withOnboardingViewModel()
                    .onDisappear {
                        // When onboarding completes, sync with UserConfiguration
                        userCredentials.syncWithUserConfiguration()
                    }
            }
        }
        .onAppear {
            // Sync with UserConfiguration when view appears
            userCredentials.syncWithUserConfiguration()
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(NavigationManager())
            .preferredColorScheme(ColorScheme.dark)
    }
} 
