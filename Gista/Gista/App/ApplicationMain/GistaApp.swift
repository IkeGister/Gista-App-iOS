//
//  GistaApp.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//
//  v1 (2026-07-25): auth de-gated per the ElevenLabs readout spec §11 —
//  launch screen → ContentView unconditionally, no credential check.
//  Firebase is no longer initialized and no notification permission is
//  requested (v1 sends no notifications). Auth/Firebase/onboarding code
//  stays in the repo, compiled and dormant.
//

import SwiftUI

@main
struct GistaApp: App {
    @StateObject private var sharedContentService = SharedContentService.shared
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var onboardingViewModel = OnboardingViewModel()

    var body: some Scene {
        WindowGroup {
            if onboardingViewModel.showLaunchScreen {
                // Branded splash only in v1 — auto-dismisses into content.
                // (LaunchScreen's tap-to-launch buttons appear after 3 s;
                // we dismiss before then, so it is purely a splash.)
                LaunchScreen.withOnboardingViewModel()
                    .environmentObject(onboardingViewModel)
                    .preferredColorScheme(ColorScheme.dark)
                    .task {
                        try? await Task.sleep(for: .seconds(1.5))
                        onboardingViewModel.dismissLaunchScreen()
                    }
            } else {
                ContentView()
                    .withNavigationStack()
                    .environmentObject(sharedContentService)
                    .environmentObject(navigationManager)
                    .environmentObject(onboardingViewModel)
                    .onAppear {
                        sharedContentService.checkForSharedContent()
                    }
                    .preferredColorScheme(ColorScheme.dark)
            }
        }
        .modelContainer(GistaModelContainer.shared)
    }
}
