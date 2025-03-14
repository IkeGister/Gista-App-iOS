//
//  GistExtensions.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//

// MARK: - Preview Data
public extension Gist {
    static let previews: [Gist] = [
        Gist(
            title: "Tech Articles",
            category: "Technology",
            imageUrl: "https://example.com/image.jpg",
            link: "https://example.com/tech",
            playbackDuration: 120,
            publisher: "TechGista",
            segments: [
                GistSegment(duration: 60, title: "Intro", audioUrl: "https://example.com/audio1.mp3")
            ],
            status: GistStatus(inProduction: false, productionStatus: "Reviewing Content"),
            color: .blue
        ),
        Gist(
            title: "Business",
            category: "Business",
            imageUrl: "https://example.com/image.jpg",
            link: "https://example.com/business",
            playbackDuration: 180,
            publisher: "BizGista",
            segments: [
                GistSegment(duration: 90, title: "Market Update", audioUrl: "https://example.com/audio2.mp3")
            ],
            status: GistStatus(inProduction: false, productionStatus: "Reviewing Content"),
            color: .green
        )
    ]
}
