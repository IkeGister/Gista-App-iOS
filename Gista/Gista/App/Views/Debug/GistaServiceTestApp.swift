//
//  GistaServiceTestApp.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/7/25.
//

import SwiftUI

// Note: Remove @main to avoid conflicts with the main app
// To use this for testing, temporarily add @main here and comment out
// the @main attribute in the main app's App struct
struct GistaServiceTestApp: App {
    var body: some Scene {
        WindowGroup {
            GistaServiceTestView()
        }
    }
} 