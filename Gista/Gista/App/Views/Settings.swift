//
//  Settings.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import SwiftUI

struct Settings: View {
    @EnvironmentObject private var navigationManager: NavigationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    NavigationLink("Subscription", destination: Text("Subscription"))
                    NavigationLink("Storage", destination: Text("Storage"))
                }
                
                Section("Playback") {
                    NavigationLink("Audio Quality", destination: Text("Audio Quality"))
                    NavigationLink("Download Settings", destination: Text("Download Settings"))
                }
                
                Section("About") {
                    NavigationLink("Privacy Policy", destination: Text("Privacy Policy"))
                    NavigationLink("Terms of Service", destination: Text("Terms of Service"))
                    NavigationLink("About Gista", destination: Text("About"))
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

