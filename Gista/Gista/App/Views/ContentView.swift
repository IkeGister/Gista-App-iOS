//
//  ContentView.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//
//  v1 (2026-07-25): auth de-gated per the ElevenLabs readout spec §11 —
//  the internal isAuthenticated branch and OnboardingView fallback are
//  removed; the toolbar shows the app name instead of a username, and the
//  GistaService test-view sheet hook is removed (spec §12). Onboarding and
//  auth code stays in the repo, compiled and dormant.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var navigationManager: NavigationManager

    var body: some View {
        LibraryView()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Gista")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
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
