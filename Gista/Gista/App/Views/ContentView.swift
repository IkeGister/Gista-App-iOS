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
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                navigationManager.navigateToProfile()
                            } label: {
                                HStack(alignment: .center, spacing: 6) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 26))
                                        .foregroundColor(.yellow)
                                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                    
                                    Text(userCredentials.username)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.yellow)
                                }
                                .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                navigationManager.navigateToSearch()
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 20))
                                    .foregroundColor(.yellow)
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
