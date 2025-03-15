import SwiftUI
import UserNotifications

@main
struct GistaApp: App {
    @StateObject private var sharedContentService = SharedContentService()
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var userCredentials = UserCredentials.shared
    
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
                    .environmentObject(onboardingViewModel)
                    .onAppear {
                        sharedContentService.checkForSharedContent()
                    }
                    .preferredColorScheme(ColorScheme.dark)
            }
        }
    }
} 