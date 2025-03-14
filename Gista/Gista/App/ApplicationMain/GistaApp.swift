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
    
    // Set this to true to start the app in test mode
    private let startInTestMode = false
    
    init() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("Notification permission granted: \(granted)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if startInTestMode {
                // Start with the test view
                GistaServiceTestView()
            } else {
                // Start with the normal app
                ContentView()
                    .environmentObject(sharedContentService)
                    .environmentObject(navigationManager)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        sharedContentService.checkForSharedContent()
                    }
            }
        }
    }
}
