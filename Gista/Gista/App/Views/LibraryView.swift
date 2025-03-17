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
    @StateObject private var userCredentials = UserCredentials.shared
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
        appearance.configureWithTransparentBackground() // Remove default background
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.stackedLayoutAppearance.normal.iconColor = .white.withAlphaComponent(0.6)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.6)]
        appearance.stackedLayoutAppearance.selected.iconColor = .systemYellow
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemYellow]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            mainContent
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            MyStudioView()
                .tabItem {
                    Label("My Studio", systemImage: "slider.horizontal.3")
                }
                .tag(1)
            
            MyResourcesView()
                .tabItem {
                    Label("Resources", systemImage: "link.circle")
                }
                .tag(2)
            
            Settings()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
    
    private var miniPlayerBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.95),  // Vibrant orange
                Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.95)  // Bright yellow
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Main Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Your Gists Section
                    Section(header: SectionHeaderView(title: "Your Gists")) {
                        LazyVStack(spacing: 16) {
                            ForEach(articles) { article in
                                ArticleRowView(article: article)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .padding(.bottom, 85)
            }
            
            // Mini Player above TabBar
            VStack(spacing: 0) {
                MiniPlayerView()
                    .frame(maxHeight: 80)
                    .frame(height: 65)
                    .background(miniPlayerBackground)
                    .clipShape(Capsule())
                    .padding(.horizontal)
            }
            .padding(.bottom, 8)
        }
        .background(Color("extBackgroundColor").gradient)
        .navigationTitle("Your Library")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    navigationManager.showingProfile = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(Color.yellow)
                            .font(.system(size: 20))
                        
                        // Add username text
                        let displayName = userCredentials.username.isEmpty || userCredentials.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Guest" : userCredentials.username
                        Text(displayName)
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            
            if selectedTab == 0 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        navigationManager.navigateToSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.yellow)
                            .font(.system(size: 17))
                    }
                }
            }
        }
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
            Image("GisterLogo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
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

