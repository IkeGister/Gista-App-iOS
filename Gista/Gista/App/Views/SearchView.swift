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
        .background(Color("extBackgroundColor").gradient)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
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
            
            CapsuleFlowLayout(items: viewModel.categories) { category in
                CategoryCardView(
                    category: category,
                    isSelected: selectedCategories.contains(category.id),
                    onTap: {
                        toggleCategory(category.id)
                    }
                )
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
    
    private var selectedGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.95),  // Vibrant orange
                Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.95)  // Bright yellow
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        Group {
            if isSelected {
                Text(category.name)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedGradient)
                    .clipShape(Capsule())
            } else {
                Text(category.name)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.clear)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.yellow, lineWidth: 1)
                    )
            }
        }
        .onTapGesture(perform: onTap)
    }
}

// Flow layout for capsules that automatically wraps to next line
struct CapsuleFlowLayout<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Identifiable & Hashable, Content: View {
    let items: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    
    init(items: Data, spacing: CGFloat = 8, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            FlowLayoutView(
                width: geometry.size.width,
                items: items,
                spacing: spacing,
                content: content
            )
        }
        .frame(minHeight: 50)
    }
}

struct FlowLayoutView<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Identifiable & Hashable, Content: View {
    let width: CGFloat
    let items: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    
    @State private var elementsSize: [Data.Element.ID: CGSize] = [:]
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(computeRows(), id: \.self) { rowElements in
                HStack(spacing: spacing) {
                    ForEach(rowElements) { element in
                        content(element)
                            .fixedSize()
                            .background(
                                GeometryReader { geo in
                                    Color.clear.onAppear {
                                        elementsSize[element.id] = geo.size
                                    }
                                }
                            )
                    }
                }
            }
        }
    }
    
    private func computeRows() -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentRow = 0
        var remainingWidth = width
        
        for element in items {
            let elementSize = elementsSize[element.id] ?? CGSize(width: 0, height: 0)
            
            if remainingWidth - (elementSize.width + spacing) >= 0 {
                rows[currentRow].append(element)
                remainingWidth -= elementSize.width + spacing
            } else {
                currentRow += 1
                rows.append([element])
                remainingWidth = width - elementSize.width
            }
        }
        
        return rows
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
