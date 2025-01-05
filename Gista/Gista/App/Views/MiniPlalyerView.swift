//
//  MiniPlalyerView.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var navigationManager: NavigationManager
    @State private var isPlaying = false
    @State private var progress: CGFloat = 0.3
    
    // These will come from your audio service/model later
    private let articleTitle = "How to Build SwiftUI Apps"
    private let duration = "12:34"
    private var currentArticleId: UUID? // Optional, since there might not be an article playing
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * progress, height: 2)
            }
            .frame(height: 2)
            
            // Main content
            HStack(spacing: 16) {
                // Article thumbnail
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                    )
                
                // Title and duration
                VStack(alignment: .leading, spacing: 2) {
                    Text(articleTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(duration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Playback controls
                HStack(spacing: 20) {
                    Button {
                        // Previous track action
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                    
                    Button {
                        // Next track action
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(
            Color(UIColor.systemBackground)
                .shadow(radius: 5, y: -5)
        )
        .onTapGesture {
            if let articleId = currentArticleId {
                navigationManager.navigateToPlayback(articleId: articleId)
            }
        }
    }
}

// Preview provider
struct MiniPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            MiniPlayerView()
        }
        .environmentObject(NavigationManager())
        .preferredColorScheme(.dark)

    }
}

