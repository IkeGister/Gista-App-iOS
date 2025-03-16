//
//  GistaApp.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import SwiftUI
import UserNotifications

@main
struct GistaApp: App {
    @StateObject private var sharedContentService = SharedContentService.shared
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var userCredentials = UserCredentials.shared
    
    // Set this to true to start the app in test mode
    private let startInTestMode = false
    
    init() {
        // Initialize Firebase
        FirebaseService.shared.initialize()
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("Notification permission granted: \(granted)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if onboardingViewModel.showLaunchScreen {
                LaunchScreen.withOnboardingViewModel()
                    .environmentObject(onboardingViewModel)
                    .preferredColorScheme(ColorScheme.dark)
            } else if !userCredentials.isAuthenticated {
                OnboardingView.withOnboardingViewModel()
                    .environmentObject(onboardingViewModel)
                    .preferredColorScheme(ColorScheme.dark)
            } else {
                ContentView()
                    .environmentObject(sharedContentService)
                    .environmentObject(navigationManager)
                    .environmentObject(onboardingViewModel)
                    .onAppear {
                        sharedContentService.checkForSharedContent()
                    }
                    .preferredColorScheme(ColorScheme.dark)
            }
        }
    }
}
