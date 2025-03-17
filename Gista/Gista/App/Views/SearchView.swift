//
//  SearchView.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/17/25.
//

import SwiftUI
import Shared

struct SearchView<ViewModel: SearchViewModelProtocol>: View {
    @StateObject private var viewModel: ViewModel
    @EnvironmentObject private var navigationManager: NavigationManager
    @State private var selectedCategories: Set<String> = []
    
    init(viewModel: ViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    categoriesSection
                }
                
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchCategoriesIfNeeded()
        }
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                Text("Categories")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.categories) { category in
                    CategoryCardView(
                        category: category,
                        isSelected: selectedCategories.contains(category.id),
                        onTap: {
                            toggleCategory(category.id)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func toggleCategory(_ categoryId: String) {
        withAnimation {
            if selectedCategories.contains(categoryId) {
                selectedCategories.remove(categoryId)
            } else {
                selectedCategories.insert(categoryId)
            }
        }
    }
}

struct CategoryCardView: View {
    let category: GistCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    // Generate unique colors for categories
    private var categoryColor: Color {
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .red, .yellow, .mint, .indigo, .teal
        ]
        
        // Use hash of category ID to get consistent color
        let index = abs(category.id.hashValue) % colors.count
        let baseColor = colors[index]
        
        // Vary the opacity to create different shades
        let opacity = Double((abs(category.id.hashValue) % 4) + 6) / 10.0 // Will give values between 0.6 and 0.9
        
        return baseColor.opacity(opacity)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(category.name)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : .primary)
            if !category.tags.isEmpty {
                Text(category.tags.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .frame(height: 55)
        .background(isSelected ? categoryColor : categoryColor.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(categoryColor, lineWidth: isSelected ? 0 : 1)
        )
        .onTapGesture(perform: onTap)
    }
}

#if DEBUG
// Preview Helper
@MainActor
final class MockSearchViewModel: SearchViewModelProtocol {
    @Published private(set) var categories: [GistCategory] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    init() {
        setupMockData()
    }
    
    func fetchCategoriesIfNeeded() {
        // Mock data is already set in init
    }
    
    func clearCache() {
        categories = []
        error = nil
    }
    
    private func setupMockData() {
        categories = [
            GistCategory(id: "1", name: "Technology", slug: "technology", tags: ["iOS", "SwiftUI", "Programming"]),
            GistCategory(id: "2", name: "Business", slug: "business", tags: ["Startups", "Marketing"]),
            GistCategory(id: "3", name: "Design", slug: "design", tags: ["UI/UX", "Graphics"]),
            GistCategory(id: "4", name: "Science", slug: "science", tags: ["Physics", "Biology", "Chemistry"]),
            GistCategory(id: "5", name: "Health", slug: "health", tags: ["Fitness", "Nutrition", "Wellness"]),
            GistCategory(id: "6", name: "Education", slug: "education", tags: ["Learning", "Teaching"]),
            GistCategory(id: "7", name: "Finance", slug: "finance", tags: ["Investment", "Banking"]),
            GistCategory(id: "8", name: "Arts", slug: "arts", tags: ["Music", "Visual Arts"])
        ]
    }
}

extension SearchView where ViewModel == MockSearchViewModel {
    static func withMockData() -> some View {
        SearchView(viewModel: MockSearchViewModel())
            .environmentObject(NavigationManager())
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                SearchView.withMockData()
            }
            .previewDisplayName("Light Mode")
            
            NavigationStack {
                SearchView.withMockData()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}
#endif
