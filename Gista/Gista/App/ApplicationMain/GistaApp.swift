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
        // Clear UserDefaults for testing purposes
        // Comment this out for production
        UserDefaults.standard.removeObject(forKey: "com.gista.user")
        UserDefaults.standard.removeObject(forKey: "isSignedIn")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "profilePictureUrl")
        
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
    }
}
