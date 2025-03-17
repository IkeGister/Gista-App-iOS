//
//  UserProfile.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import SwiftUI

struct UserProfile: View {
    @EnvironmentObject private var navigationManager: NavigationManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userCredentials = UserCredentials.shared
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        if let profileUrl = userCredentials.profilePictureUrl.isEmpty ? nil : userCredentials.profilePictureUrl,
                           let url = URL(string: profileUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading) {
                            let displayName = userCredentials.username.isEmpty || userCredentials.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Guest" : userCredentials.username
                            Text(displayName)
                                .font(.headline)
                            let displayEmail = userCredentials.userEmail.isEmpty ? "Not signed in" : userCredentials.userEmail
                            Text(displayEmail)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Statistics") {
                    StatRow(title: "Articles Saved", value: "42")
                    StatRow(title: "Listening Time", value: "3.5 hours")
                    StatRow(title: "Storage Used", value: "128 MB")
                }
                
                Section {
                    Button(role: .destructive) {
                        // Handle sign out
                    } label: {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Profile")
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

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

