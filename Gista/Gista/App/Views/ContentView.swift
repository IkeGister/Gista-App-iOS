//
//  ContentView.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import SwiftUI
import SwiftData
import Shared

struct ContentView: View {
    @EnvironmentObject private var navigationManager: NavigationManager
    @State private var showTestView = false
    
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
                
                // Always show the debug button in simulator for testing
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showTestView = true
                    } label: {
                        Image(systemName: "hammer.circle")
                            .foregroundColor(.orange)
                    }
                }
            }
            .sheet(isPresented: $showTestView) {
                GistaServiceTestView()
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
