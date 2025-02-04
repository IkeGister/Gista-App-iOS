import SwiftUI
import UserNotifications

@main
struct GistaApp: App {
    @StateObject private var sharedContentService = SharedContentService()
    
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
                .onAppear {
                    sharedContentService.checkForSharedContent()
                }
        }
    }
} 