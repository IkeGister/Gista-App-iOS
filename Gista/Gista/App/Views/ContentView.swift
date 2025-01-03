//
//  ContentView.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var navigationManager: NavigationManager
    
    var body: some View {
        LibraryView()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        navigationManager.navigateToSettings()
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        navigationManager.navigateToProfile()
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
    }
} 
