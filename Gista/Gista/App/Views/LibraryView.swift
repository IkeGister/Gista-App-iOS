//
//  LibraryView.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import SwiftUI
import Shared

struct LibraryView: View {
    @EnvironmentObject private var navigationManager: NavigationManager
    @State private var selectedTab = 0
    
    let articles: [Article]
    let gists: [Gist]
    
    init(
        articles: [Article] = [],
        gists: [Gist] = []
    ) {
        self.articles = articles
        self.gists = gists
        
        // Customize Tab Bar appearance
        let appearance = UITabBarAppearance()
        appearance.backgroundColor = .systemBackground
        appearance.shadowColor = .clear // Remove default shadow
        appearance.stackedLayoutAppearance.normal.iconColor = .gray
        appearance.stackedLayoutAppearance.selected.iconColor = .blue
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            mainContent
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(0)
            
            MyResourcesView()
                .tabItem {
                    Label("Resources", systemImage: "link.circle")
                }
                .tag(1)
            
            UserProfile()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(2)
            
            Settings()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
    
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Main Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Gists Section
                    Section(header: SectionHeaderView(title: "Your Gists")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(gists) { gist in
                                    GistCardView(gist: gist)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // All Items Section
                    Section(header: SectionHeaderView(title: "All Items")) {
                        LazyVStack(spacing: 16) {
                            ForEach(articles) { article in
                                ArticleRowView(article: article)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .padding(.bottom, 85) // Adjusted to account for new spacing (65 + 8 + small buffer)
            }
            
            // Mini Player above TabBar
            VStack(spacing: 0) {
                Divider()
                    .background(Color.gray.opacity(0.3))
                MiniPlayerView()
                    .frame(maxHeight: 80)
                    .frame(height: 65)
                    .background(.regularMaterial)
                    .clipShape(Rectangle())
            }
            .padding(.bottom, 8)
        }
        .navigationTitle("Your Library")
    }
}

#if DEBUG
// Preview Data
extension Article {
    static let previews: [Article] = [
        Article(
            id: UUID(),
            title: "SwiftUI Best Practices for 2024",
            url: URL(string: "https://example.com/swiftui")!,
            dateAdded: Date().addingTimeInterval(-3600),
            duration: 845
        ),
        Article(
            id: UUID(),
            title: "The Future of iOS Development",
            url: URL(string: "https://example.com/ios")!,
            dateAdded: Date().addingTimeInterval(-7200),
            duration: 1256
        ),
        Article(
            id: UUID(),
            title: "Understanding Swift Concurrency",
            url: URL(string: "https://example.com/swift")!,
            dateAdded: Date().addingTimeInterval(-86400),
            duration: 923
        )
    ]
}


// Preview Provider
struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                LibraryView(
                    articles: Article.previews,
                    gists: Gist.previews
                )
            }
            .environmentObject(NavigationManager())
            .previewDisplayName("Dark Mode")
            .preferredColorScheme(.dark)
            
            NavigationStack {
                LibraryView(
                    articles: Article.previews,
                    gists: Gist.previews
                )
            }
            .environmentObject(NavigationManager())
            .previewDisplayName("Light Mode")
            .preferredColorScheme(.light)
        }
    }
}
#endif



struct GistCardView: View {
    @EnvironmentObject private var navigationManager: NavigationManager
    let gist: Gist
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(gist.title)
                .font(.headline)
            Text("\(gist.segments.count) items")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 160, height: 100)
        .background(gist.color.opacity(0.1))
        .cornerRadius(12)
        .onTapGesture {
            // We can add navigation to Gist detail view later
            // navigationManager.navigateToGistDetail(gistId: gist.id)
        }
    }
}

struct ArticleRowView: View {
    @EnvironmentObject private var navigationManager: NavigationManager
    let article: Article
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "doc.text")
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.headline)
                    .lineLimit(2)
                Text("Added \(article.dateAdded.relativeFormatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            navigationManager.navigateToPlayback(articleId: article.id)
        }
    }
}

struct SectionHeaderView: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.title2)
            .fontWeight(.bold)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }
}

