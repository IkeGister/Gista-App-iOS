//
//  PlaybackView.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import SwiftUI

struct PlaybackView: View {
    let articleId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var isPlaying = false
    @State private var progress: Double = 0.3
    @State private var playbackSpeed: Double = 1.0
    @State private var volume: Double = 0.8
    @State private var showingInfo = false
    
    // These will come from your audio service later
    private let article = Article(
        id: UUID(),
        title: "How to Build SwiftUI Apps",
        url: URL(string: "https://example.com")!,
        dateAdded: Date(),
        duration: 754 // seconds
    )
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Artwork/Thumbnail
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 240)
                    .overlay(
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    )
                    .padding(.horizontal)
                
                // Title and metadata
                VStack(spacing: 8) {
                    Text(article.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Added \(article.dateAdded.relativeFormatted())")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Progress bar and time
                VStack(spacing: 8) {
                    Slider(value: $progress)
                        .tint(.blue)
                    
                    HStack {
                        Text(formatTime(current: progress * Double(article.duration)))
                        Spacer()
                        Text(formatTime(current: Double(article.duration)))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Playback controls
                HStack(spacing: 40) {
                    Button {
                        // Skip backward 15 seconds
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.title)
                    }
                    
                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                    }
                    
                    Button {
                        // Skip forward 15 seconds
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.title)
                    }
                }
                .foregroundColor(.primary)
                
                // Additional controls
                VStack(spacing: 24) {
                    // Playback speed
                    HStack {
                        Image(systemName: "speedometer")
                        Slider(value: $playbackSpeed, in: 0.5...2.0, step: 0.25)
                        Text("\(playbackSpeed, specifier: "%.2f")x")
                    }
                    
                    // Volume
                    HStack {
                        Image(systemName: "speaker.wave.2")
                        Slider(value: $volume)
                        Image(systemName: "speaker.wave.3")
                    }
                }
                .font(.subheadline)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingInfo) {
                ArticleInfoView(article: article)
            }
        }
    }
    
    private func formatTime(current: Double) -> String {
        let minutes = Int(current) / 60
        let seconds = Int(current) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Article Info Sheet
struct ArticleInfoView: View {
    let article: Article
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    LabeledContent("Title", value: article.title)
                    LabeledContent("Date Added", value: article.dateAdded.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Duration", value: formatDuration(seconds: article.duration))
                }
                
                Section {
                    Button {
                        if let url = URL(string: article.url.absoluteString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("View Original Article")
                    }
                }
            }
            .navigationTitle("Article Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDuration(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// Article Model (Move to Models folder later)
struct Article: Identifiable {
    let id: UUID
    let title: String
    let url: URL
    let dateAdded: Date
    let duration: Int // in seconds
}

// Preview
struct PlaybackView_Previews: PreviewProvider {
    static var previews: some View {
        PlaybackView(articleId: UUID())
            .preferredColorScheme(.dark)
    }
}

extension Date {
    func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

