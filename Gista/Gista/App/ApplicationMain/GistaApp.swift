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
    
    init() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("Notification permission granted: \(granted)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sharedContentService)
                .preferredColorScheme(.dark)
                .onAppear {
                    sharedContentService.checkForSharedContent()
                }
        }
    }
}
