//
//  SearchViewModel.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/17/25.
//

import Foundation
import Shared

@MainActor
protocol SearchViewModelProtocol: ObservableObject {
    var categories: [GistCategory] { get }
    var isLoading: Bool { get }
    var error: Error? { get }
    
    func fetchCategoriesIfNeeded()
    func clearCache()
}

@MainActor
final class DefaultSearchViewModel: SearchViewModelProtocol {
    @Published private(set) var categories: [GistCategory] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let gistaService: GistaServiceProtocol
    private var hasFetchedCategories = false
    
    init(gistaService: GistaServiceProtocol = GistaService()) {
        self.gistaService = gistaService
    }
    
    func fetchCategoriesIfNeeded() {
        // Return if categories are already cached
        guard !hasFetchedCategories else { return }
        
        Task {
            await fetchCategories()
        }
    }
    
    private func fetchCategories() async {
        isLoading = true
        error = nil
        
        do {
            let fetchedCategories = try await gistaService.fetchCategories()
            await MainActor.run {
                self.categories = fetchedCategories
                self.hasFetchedCategories = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                print("Error fetching categories: \(error)")
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func clearCache() {
        Task { @MainActor in
            hasFetchedCategories = false
            categories = []
            error = nil
        }
    }
    
    // Testing purposes only
    #if DEBUG
    @MainActor
    func setCategories(_ newCategories: [GistCategory]) {
        categories = newCategories
        hasFetchedCategories = true
        error = nil
    }
    #endif
}
