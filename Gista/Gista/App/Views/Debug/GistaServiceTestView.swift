//
//  GistaServiceTestView.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/7/25.
//

import SwiftUI
import Shared

struct GistaServiceTestView: View {
    @StateObject private var viewModel = GistaServiceViewModel()
    
    // Form fields
    @State private var email: String
    @State private var password = "password123"
    @State private var username: String
    @State private var articleUrl = "https://example.com/article"
    @State private var articleTitle: String
    @State private var articleCategory = "Technology"
    
    // Test state
    @State private var logs: [LogEntry] = []
    @State private var currentUserId: String?
    @State private var currentArticleId: String?
    @State private var currentGistId: String?
    @State private var isCreatingUser: Bool = false
    @State private var isAddingArticle: Bool = false
    @State private var lastButtonTapTime: Date = Date(timeIntervalSince1970: 0)
    
    init() {
        // Generate timestamp for unique test identification
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // Get device name for identification
        let deviceName = UIDevice.current.name.replacingOccurrences(of: " ", with: "-")
        let safeDeviceName = deviceName.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "-")
        
        let emailValue = "ios-client-\(safeDeviceName)-\(timestamp)@example.com"
        let usernameValue = "ios-client-\(safeDeviceName)-\(timestamp)"
        let articleTitleValue = "iOS Client Test Article - \(safeDeviceName) - \(timestamp)"
        
        // Initialize the state properties
        _email = State(initialValue: emailValue)
        _username = State(initialValue: usernameValue)
        _articleTitle = State(initialValue: articleTitleValue)
        
        // Initialize currentUserId as nil - it will be set after user creation
        _currentUserId = State(initialValue: nil)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // User Information Section
                    GroupBox(label: Text("User Information").bold()) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Username", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    
                    // Article Information Section
                    GroupBox(label: Text("Article Information").bold()) {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("URL", text: $articleUrl)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.URL)
                            
                            TextField("Title", text: $articleTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Category", text: $articleCategory)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    
                    // Test Actions Section
                    GroupBox(label: Text("Test Actions").bold()) {
                        VStack(spacing: 12) {
                            // Debug buttons
                            Group {
                                Button(action: {
                                    Task {
                                        await checkAPIConnectivity()
                                    }
                                }) {
                                    Text("Check API Connectivity")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.purple)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    checkNetworkPermissions()
                                }) {
                                    Text("Check Network Permissions")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.purple)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    checkEnvironment()
                                }) {
                                    Text("Check Environment")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.purple)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                            
                            // User flow
                            Group {
                                Button(action: {
                                    // Debounce mechanism - ignore taps that are too close together
                                    let now = Date()
                                    if now.timeIntervalSince(lastButtonTapTime) < 1.0 {
                                        // Ignore taps that are less than 1 second apart
                                        return
                                    }
                                    lastButtonTapTime = now
                                    
                                    Task {
                                        await createUser()
                                    }
                                }) {
                                    Text("1. Create User in Database")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(viewModel.isLoading || isCreatingUser ? Color.gray : Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .disabled(viewModel.isLoading || isCreatingUser)
                                
                                Button(action: {
                                    Task {
                                        await updateUser()
                                    }
                                }) {
                                    Text("2. Update User in Database")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(viewModel.isLoading ? Color.gray : Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .disabled(viewModel.isLoading)
                            }
                            
                            // Content flow
                            Group {
                                Button(action: {
                                    // Debounce mechanism - ignore taps that are too close together
                                    let now = Date()
                                    if now.timeIntervalSince(lastButtonTapTime) < 1.0 {
                                        // Ignore taps that are less than 1 second apart
                                        return
                                    }
                                    lastButtonTapTime = now
                                    
                                    Task {
                                        await addArticle()
                                    }
                                }) {
                                    Text("3. Add Article to Database")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(viewModel.isLoading || isAddingArticle ? Color.gray : Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .disabled(viewModel.isLoading || isAddingArticle)
                                
                                Button(action: {
                                    Task {
                                        await createGist()
                                    }
                                }) {
                                    Text("4. Create Gist in Database")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(viewModel.isLoading ? Color.gray : Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .disabled(viewModel.isLoading)
                                
                                Button(action: {
                                    Task {
                                        await updateGist()
                                    }
                                }) {
                                    Text("5. Update Gist in Database")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(viewModel.isLoading ? Color.gray : Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .disabled(viewModel.isLoading)
                                
                                Button(action: {
                                    Task {
                                        await updateGistProductionStatus()
                                    }
                                }) {
                                    Text("5b. Update Gist Status (Signal)")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(viewModel.isLoading ? Color.gray : Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .disabled(viewModel.isLoading)
                            }
                            
                            // Additional actions
                            Group {
                                Button(action: {
                                    Task {
                                        await fetchCategories()
                                    }
                                }) {
                                    Text("Fetch Categories")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(viewModel.isLoading ? Color.gray : Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .disabled(viewModel.isLoading)
                                
                                Button(action: {
                                    Task {
                                        await deleteUser()
                                    }
                                }) {
                                    Text("6. Delete User from Database")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(viewModel.isLoading ? Color.gray : Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .disabled(viewModel.isLoading)
                                
                                Button(action: {
                                    debugState()
                                }) {
                                    Text("Debug State")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.purple)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    resetTest()
                                }) {
                                    Text("Reset Test")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    logs.removeAll()
                                }) {
                                    Text("Clear Logs")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    
                    // Status Section
                    GroupBox(label: Text("Status").bold()) {
                        VStack(alignment: .leading, spacing: 8) {
                            if viewModel.isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                    Text("Loading...")
                                        .padding(.leading, 8)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            if viewModel.showError, let errorMessage = viewModel.errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .padding(.vertical, 4)
                            }
                            
                            Text("User ID: \(currentUserId ?? "Not logged in")")
                            Text("Article ID: \(currentArticleId ?? "No article")")
                            Text("Gist ID: \(currentGistId ?? "No gist")")
                            
                            Divider()
                            
                            Text("Articles: \(viewModel.articles.count)")
                            Text("Gists: \(viewModel.gists.count)")
                            Text("Categories: \(viewModel.categories.count)")
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    
                    // Logs Section
                    GroupBox(label: Text("Logs").bold()) {
                        VStack(alignment: .leading, spacing: 8) {
                            if logs.isEmpty {
                                Text("No logs yet. Start testing to see logs here.")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(logs.prefix(10)) { log in
                                    LogEntryView(log: log)
                                }
                                
                                if logs.count > 10 {
                                    Text("+ \(logs.count - 10) more logs...")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Gista Service Test")
        }
    }
    
    // MARK: - Test Methods
    
    private func createUser() async {
        // Prevent multiple simultaneous calls
        if isCreatingUser {
            addLog(title: "User Creation In Progress", message: "Please wait for the current user creation to complete.", type: .info)
            return
        }
        
        // Set the flag to prevent multiple calls
        isCreatingUser = true
        
        addLog(title: "Creating User", message: "Email: \(email)\nUsername: \(username)")
        
        do {
            // Call the service directly
            let user = try await viewModel.gistaService.createUser(email: email, password: password, username: username)
            
            // Update the currentUserId with the one returned from the API
            currentUserId = user.userId
            
            addLog(title: "User Created Successfully", message: "User ID: \(user.userId)\nUser: \(username)\nEmail: \(email)", type: .success)
            
            // Removed automatic categories fetch
        } catch {
            addLog(title: "User Creation Error", message: "Error: \(error.localizedDescription)\nUser: \(username)\nEmail: \(email)", type: .error)
        }
        
        // Reset the flag after completion
        isCreatingUser = false
    }
    
    private func updateUser() async {
        // Check if we have a user ID
        guard let userId = currentUserId, !userId.isEmpty else {
            addLog(title: "User Required", message: "Please create a user first using the 'Create User in Database' button before updating.", type: .error)
            return
        }
        
        addLog(title: "Updating User", message: "User ID: \(userId)\nEmail: \(email)\nUsername: \(username)")
        
        // Directly call the service with the user ID
        do {
            let success = try await viewModel.gistaService.updateUser(
                userId: userId,
                username: username,
                email: email
            )
            
            if success {
                addLog(title: "User Updated", message: "User ID: \(userId)\nUser: \(username)\nEmail: \(email)", type: .success)
            } else {
                addLog(title: "User Update Failed", message: "Failed to update user with ID \(userId)", type: .error)
            }
        } catch {
            addLog(title: "User Update Error", message: "Error: \(error.localizedDescription)\nUser ID: \(userId)\nUser: \(username)\nEmail: \(email)", type: .error)
        }
    }
    
    private func addArticle() async {
        // Prevent multiple simultaneous calls
        if isAddingArticle {
            addLog(title: "Article Addition In Progress", message: "Please wait for the current article addition to complete.", type: .info)
            return
        }
        
        // Set the flag to prevent multiple calls
        isAddingArticle = true
        
        guard let url = URL(string: articleUrl) else {
            addLog(title: "Invalid URL", message: "Please enter a valid URL", type: .error)
            isAddingArticle = false
            return
        }
        
        // Check if we have a user ID
        guard let userId = currentUserId, !userId.isEmpty else {
            addLog(title: "User Required", message: "Please create a user first using the 'Create User in Database' button before adding an article.", type: .error)
            isAddingArticle = false
            return
        }
        
        let article = Article(
            title: articleTitle,
            url: url,
            duration: 120,
            category: articleCategory
        )
        
        addLog(title: "Adding Article", message: "Title: \(articleTitle)\nURL: \(articleUrl)\nCategory: \(articleCategory)\nUser ID: \(userId)")
        
        // Directly call the service with the user ID
        do {
            // Call the service
            let storedArticle = try await viewModel.gistaService.storeArticle(
                userId: userId,
                article: article
            )
            
            // Add the article to the view model's articles array
            await MainActor.run {
                viewModel.articles.append(storedArticle)
            }
            
            // Set the current article ID
            currentArticleId = storedArticle.id.uuidString
            
            // Log success with detailed information
            addLog(title: "Article Added Successfully", message: "Article ID: \(currentArticleId ?? "Unknown")\nTitle: \(storedArticle.title)\nCategory: \(storedArticle.category)\nLink ID: \(storedArticle.linkId ?? "Unknown")", type: .success)
            
            // Print debug info
            print("Article added successfully: \(storedArticle)")
        } catch {
            // Log the detailed error
            addLog(title: "Article Addition Error", message: "Error: \(error.localizedDescription)\nTitle: \(articleTitle)", type: .error)
            print("Error adding article: \(error)")
            
            // Try to extract more information about the error
            if let gistaError = error as? GistaError {
                print("GistaError: \(gistaError.errorDescription ?? "Unknown")")
                addLog(title: "Detailed Error", message: gistaError.errorDescription ?? "Unknown", type: .error)
            }
        }
        
        // Reset the flag after completion
        isAddingArticle = false
    }
    
    private func createGist() async {
        // Check if we have a user ID
        guard let userId = currentUserId, !userId.isEmpty else {
            addLog(title: "User Required", message: "Please create a user first using the 'Create User in Database' button before creating a gist.", type: .error)
            return
        }
        
        // Check if we have an article
        if currentArticleId == nil {
            addLog(title: "Article Required", message: "Please add an article first using the 'Add Article to Database' button before creating a gist.", type: .error)
            return
        }
        
        // Get the article
        guard let articleId = currentArticleId,
              let article = viewModel.articles.first(where: { $0.id.uuidString == articleId }) else {
            addLog(title: "Article Not Found", message: "The article with ID \(currentArticleId ?? "Unknown") was not found.", type: .error)
            return
        }
        
        // Get the link ID from the article's gistStatus
        guard let linkId = article.gistStatus?.articleId else {
            addLog(title: "Link ID Not Found", message: "The article does not have a valid link ID. Please try adding the article again.", type: .error)
            return
        }
        
        // Generate a unique gist ID
        let timestamp = Int(Date().timeIntervalSince1970)
        let gistId = "gist_\(timestamp)"
        
        let gistRequest = GistRequest(
            title: article.title,
            link: article.url.absoluteString,
            imageUrl: "https://example.com/image.jpg",
            category: article.category,
            segments: [
                GistSegment(
                    duration: 60,
                    title: "Test Segment",
                    audioUrl: "https://example.com/audio1.mp3",
                    segmentIndex: 0
                )
            ],
            playbackDuration: 180,
            linkId: linkId,
            gistId: gistId,
            isFinished: false,
            playbackTime: 0,
            status: GistStatus(
                inProduction: false,
                productionStatus: "Reviewing Content"
            )
        )
        
        addLog(title: "Creating Gist", message: "Title: \(gistRequest.title)\nCategory: \(gistRequest.category)\nSegments: \(gistRequest.segments.count)\nLink ID: \(linkId)\nGist ID: \(gistId)\nUser ID: \(userId)")
        
        // Add debug logging for the request
        print("Creating gist with request: \(gistRequest)")
        print("Segments: \(gistRequest.segments)")
        
        // Directly call the service with the user ID
        do {
            let createdGist = try await viewModel.gistaService.createGist(
                userId: userId,
                gist: gistRequest
            )
            
            // Add the gist to the view model's gists array
            await MainActor.run {
                viewModel.gists.append(createdGist)
            }
            
            currentGistId = createdGist.id.uuidString
            addLog(title: "Gist Created", message: "Gist ID: \(currentGistId ?? "Unknown")\nTitle: \(createdGist.title)\nCategory: \(createdGist.category)\nSegments: \(createdGist.segments.count)", type: .success)
            
            // Update the article with the gist information
            do {
                let updatedArticle = try await viewModel.gistaService.updateArticleGistStatus(
                    userId: userId,
                    articleId: articleId,
                    gistId: createdGist.id.uuidString,
                    imageUrl: "https://example.com/image.jpg",
                    title: article.title
                )
                
                // Update the article in the view model's articles array
                await MainActor.run {
                    if let index = viewModel.articles.firstIndex(where: { $0.id.uuidString == articleId }) {
                        viewModel.articles[index] = updatedArticle
                    }
                }
                
                addLog(title: "Article Updated", message: "Article ID: \(articleId)\nLinked to Gist ID: \(createdGist.id.uuidString)", type: .success)
            } catch {
                addLog(title: "Article Update Error", message: "Error: \(error.localizedDescription)\nArticle ID: \(articleId)", type: .error)
                print("Article update error details: \(error)")
            }
        } catch {
            addLog(title: "Gist Creation Error", message: "Error: \(error.localizedDescription)\nTitle: \(gistRequest.title)", type: .error)
            print("Gist creation error details: \(error)")
            
            // Try to extract more information about the error
            if let gistaError = error as? GistaError {
                print("GistaError: \(gistaError.errorDescription ?? "Unknown")")
                addLog(title: "Detailed Error", message: gistaError.errorDescription ?? "Unknown", type: .error)
            }
            
            // If it's a server error, try to extract the response
            if let serverError = error as? GistaError, case let .serverError(message) = serverError {
                print("Server error message: \(message)")
                addLog(title: "Server Error", message: message, type: .error)
            }
        }
    }
    
    private func updateGist() async {
        // Check if we have a user ID
        guard let userId = currentUserId, !userId.isEmpty else {
            addLog(title: "User Required", message: "Please create a user first using the 'Create User in Database' button before updating a gist.", type: .error)
            return
        }
        
        // Check if we have a gist
        if currentGistId == nil {
            addLog(title: "Gist Required", message: "Please create a gist first using the 'Create Gist in Database' button before updating it.", type: .error)
            return
        }
        
        let newStatus = GistStatus(
            inProduction: true,
            productionStatus: "In Production"
        )
        
        addLog(title: "Updating Gist", message: "Gist ID: \(currentGistId!)\nStatus: In Production\nIsPlayed: true\nRatings: 4\nUser ID: \(userId)")
        
        // Directly call the service with the user ID
        do {
            let success = try await viewModel.gistaService.updateGistStatus(
                userId: userId,
                gistId: currentGistId!,
                status: newStatus,
                isPlayed: true,
                ratings: 4
            )
            
            if success {
                // Fetch the updated gist
                let gists = try await viewModel.gistaService.fetchGists(userId: userId)
                
                // Update the view model's gists array
                await MainActor.run {
                    viewModel.gists = gists
                }
                
                // Find the updated gist
                if let updatedGist = gists.first(where: { $0.id.uuidString == currentGistId }) {
                    addLog(title: "Gist Updated", message: "Gist ID: \(currentGistId!)\nTitle: \(updatedGist.title)\nStatus: \(updatedGist.status.productionStatus)\nIsPlayed: \(updatedGist.isPlayed ? "Yes" : "No")\nRatings: \(updatedGist.ratings)", type: .success)
                } else {
                    addLog(title: "Gist Updated", message: "Status updated to In Production\nGist ID: \(currentGistId!)", type: .success)
                }
            } else {
                addLog(title: "Gist Update Failed", message: "Failed to update gist with ID \(currentGistId!)", type: .error)
            }
        } catch {
            addLog(title: "Gist Update Error", message: "Error: \(error.localizedDescription)\nGist ID: \(currentGistId!)", type: .error)
        }
    }
    
    private func updateGistProductionStatus() async {
        // Check if we have a user ID
        guard let userId = currentUserId, !userId.isEmpty else {
            addLog(title: "User Required", message: "Please create a user first using the 'Create User in Database' button before updating a gist.", type: .error)
            return
        }
        
        // Check if we have a gist
        guard let gistId = currentGistId, !gistId.isEmpty else {
            addLog(title: "Gist Required", message: "Please create a gist first using the 'Create Gist in Database' button before updating it.", type: .error)
            return
        }
        
        addLog(title: "Updating Gist Status (Signal)", message: "Gist ID: \(gistId)\nUser ID: \(userId)\nUsing signal-based approach (no request body)")
        
        // Set the viewModel's userId
        viewModel.setUserId(userId)
        
        // Call the ViewModel method
        await viewModel.updateGistProductionStatus(gistId: gistId)
        
        // Check for errors
        if viewModel.showError, let errorMessage = viewModel.errorMessage {
            addLog(title: "Gist Status Update Error", message: "Error: \(errorMessage)\nGist ID: \(gistId)", type: .error)
            return
        }
        
        // Find the updated gist
        if let updatedGist = viewModel.gists.first(where: { $0.id.uuidString == gistId }) {
            addLog(title: "Gist Status Updated (Signal)", message: "Gist ID: \(gistId)\nTitle: \(updatedGist.title)\nStatus: \(updatedGist.status.productionStatus)\nInProduction: \(updatedGist.status.inProduction ? "Yes" : "No")", type: .success)
        } else {
            addLog(title: "Gist Status Updated (Signal)", message: "Status updated to 'Reviewing Content'\nInProduction set to true\nGist ID: \(gistId)", type: .success)
        }
    }
    
    private func fetchCategories() async {
        addLog(title: "Fetching Categories", message: "Retrieving all categories from API")
        
        do {
            let fetchedCategories = try await viewModel.gistaService.fetchCategories()
            
            // Update the view model's categories array
            await MainActor.run {
                viewModel.categories = fetchedCategories
            }
            
            addLog(title: "Categories Fetched", message: "Retrieved \(fetchedCategories.count) categories", type: .success)
            
            // Log the categories
            if fetchedCategories.isEmpty {
                addLog(title: "Categories", message: "No categories found")
            } else {
                for (index, category) in fetchedCategories.enumerated() {
                    addLog(title: "Category \(index + 1)", message: "ID: \(category.id)\nName: \(category.name)\nSlug: \(category.slug)\nTags: \(category.tags.joined(separator: ", "))")
                }
            }
        } catch {
            addLog(title: "Categories Fetch Error", message: "Error: \(error.localizedDescription)", type: .error)
        }
    }
    
    private func deleteUser() async {
        // Check if we have a user ID
        guard let userId = currentUserId, !userId.isEmpty else {
            addLog(title: "User Required", message: "Please create a user first using the 'Create User in Database' button before deleting.", type: .error)
            return
        }
        
        addLog(title: "Deleting User", message: "User ID: \(userId)")
        
        do {
            let success = try await viewModel.gistaService.deleteUser(userId: userId)
            if success {
                addLog(title: "User Deleted", message: "User ID: \(userId)", type: .success)
                
                // Reset all IDs
                currentUserId = nil
                currentArticleId = nil
                currentGistId = nil
                
                // Clear the view model's data
                await MainActor.run {
                    viewModel.articles.removeAll()
                    viewModel.gists.removeAll()
                }
                
                // Generate new test data for the next test
                let timestamp = Int(Date().timeIntervalSince1970)
                let deviceName = UIDevice.current.name.replacingOccurrences(of: " ", with: "-")
                let safeDeviceName = deviceName.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "-")
                
                email = "ios-client-\(safeDeviceName)-\(timestamp)@example.com"
                username = "ios-client-\(safeDeviceName)-\(timestamp)"
                articleTitle = "iOS Client Test Article - \(safeDeviceName) - \(timestamp)"
                
                // Add log entry
                addLog(title: "Test Reset After Deletion", message: "All test data has been reset. New test data generated:\nEmail: \(email)\nUsername: \(username)", type: .info)
            } else {
                addLog(title: "User Deletion Failed", message: "Failed to delete user with ID \(userId)", type: .error)
            }
        } catch {
            addLog(title: "User Deletion Error", message: "Error: \(error.localizedDescription)\nUser ID: \(userId)", type: .error)
        }
    }
    
    // MARK: - Debug Methods
    
    private func checkAPIConnectivity() async {
        // Try both development and production URLs
        let devURL = URL(string: "http://localhost:5001/test")!
        let prodURL = URL(string: "https://us-central1-dof-ai.cloudfunctions.net/api/test")!
        
        addLog(title: "API Configuration", message: "Testing both development and production URLs")
        
        // Test development URL
        await testEndpoint(url: devURL, name: "Development")
        
        // Test production URL
        await testEndpoint(url: prodURL, name: "Production")
    }
    
    private func testEndpoint(url: URL, name: String) async {
        addLog(title: "Testing \(name) API", message: "URL: \(url.absoluteString)")
        
        do {
            let request = URLRequest(url: url, timeoutInterval: 10)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                
                if (200...299).contains(statusCode) {
                    addLog(title: "\(name) API Success", message: "Status: \(statusCode)\nResponse: \(responseString)", type: .success)
                } else {
                    addLog(title: "\(name) API Failed", message: "Status: \(statusCode)\nResponse: \(responseString)", type: .error)
                }
            }
        } catch {
            addLog(title: "\(name) API Error", message: "Error: \(error.localizedDescription)", type: .error)
        }
    }
    
    private func checkNetworkPermissions() {
        addLog(title: "Network Permissions Check", message: "Checking network permissions...", type: .info)
        
        // Check if we can make a simple network request to a reliable endpoint
        let url = URL(string: "https://www.apple.com")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.addLog(title: "Network Permission Error", message: "Error: \(error.localizedDescription)", type: .error)
                } else if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    if (200...299).contains(statusCode) {
                        self.addLog(title: "Network Permission Success", message: "Successfully connected to apple.com\nStatus: \(statusCode)", type: .success)
                        
                        // Check Info.plist settings
                        let infoPlistCheck = """
                        Reminder: For iOS apps, make sure your Info.plist includes:
                        
                        1. For non-secure connections (http://):
                           <key>NSAppTransportSecurity</key>
                           <dict>
                               <key>NSAllowsArbitraryLoads</key>
                               <true/>
                           </dict>
                        
                        2. For specific domains:
                           <key>NSAppTransportSecurity</key>
                           <dict>
                               <key>NSExceptionDomains</key>
                               <dict>
                                   <key>yourdomain.com</key>
                                   <dict>
                                       <key>NSExceptionAllowsInsecureHTTPLoads</key>
                                       <true/>
                                   </dict>
                               </dict>
                           </dict>
                        """
                        
                        self.addLog(title: "Info.plist Check", message: infoPlistCheck, type: .info)
                    } else {
                        self.addLog(title: "Network Permission Issue", message: "Connected but received status code: \(statusCode)", type: .error)
                    }
                }
            }
        }
        task.resume()
    }
    
    private func checkEnvironment() {
        addLog(title: "Environment Check", message: "Checking current environment...", type: .info)
        
        // Try to create a simple user with a unique email to see which environment responds
        let testEmail = "env-test-\(Int(Date().timeIntervalSince1970))@example.com"
        let testPassword = "password123"
        let testUsername = "env-test-\(Int(Date().timeIntervalSince1970))"
        
        // Try development environment
        Task {
            addLog(title: "Testing Development Environment", message: "Attempting to connect to development environment...")
            
            do {
                let url = URL(string: "http://localhost:5001/auth/create_user")!
                var request = URLRequest(url: url, timeoutInterval: 5)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body: [String: Any] = [
                    "email": testEmail,
                    "password": testPassword,
                    "username": testUsername
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        addLog(title: "Development Environment Responsive", message: "The app appears to be using the development environment", type: .success)
                    } else {
                        addLog(title: "Development Environment Not Responsive", message: "Status code: \(httpResponse.statusCode)", type: .info)
                    }
                }
            } catch {
                addLog(title: "Development Environment Error", message: "Error: \(error.localizedDescription)", type: .info)
            }
        }
        
        // Try production environment
        Task {
            addLog(title: "Testing Production Environment", message: "Attempting to connect to production environment...")
            
            do {
                let url = URL(string: "https://us-central1-dof-ai.cloudfunctions.net/api/auth/create_user")!
                var request = URLRequest(url: url, timeoutInterval: 5)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body: [String: Any] = [
                    "email": testEmail,
                    "password": testPassword,
                    "username": testUsername
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        addLog(title: "Production Environment Responsive", message: "The app appears to be using the production environment", type: .success)
                    } else {
                        addLog(title: "Production Environment Not Responsive", message: "Status code: \(httpResponse.statusCode)", type: .info)
                    }
                }
            } catch {
                addLog(title: "Production Environment Error", message: "Error: \(error.localizedDescription)", type: .info)
            }
        }
        
        addLog(title: "Environment Check Complete", message: "Check the logs above to see which environment responded successfully", type: .info)
    }
    
    // MARK: - Logging
    
    private func addLog(title: String, message: String, type: LogType = .info) {
        let log = LogEntry(title: title, message: message, type: type, timestamp: Date())
        DispatchQueue.main.async {
            logs.insert(log, at: 0)
        }
    }
    
    private func resetTest() {
        // Reset article and gist IDs but keep the user ID
        currentArticleId = nil
        currentGistId = nil
        
        // Generate new test data
        let timestamp = Int(Date().timeIntervalSince1970)
        let deviceName = UIDevice.current.name.replacingOccurrences(of: " ", with: "-")
        let safeDeviceName = deviceName.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "-")
        
        email = "ios-client-\(safeDeviceName)-\(timestamp)@example.com"
        username = "ios-client-\(safeDeviceName)-\(timestamp)"
        articleTitle = "iOS Client Test Article - \(safeDeviceName) - \(timestamp)"
        
        // Clear logs and reset viewModel's articles and gists, but keep the user ID
        logs.removeAll()
        viewModel.articles.removeAll()
        viewModel.gists.removeAll()
        
        // Add log entry
        let userIdMessage = currentUserId != nil ? "Using existing user ID: \(currentUserId!)" : "No user ID set. Please create a user first."
        addLog(title: "UI State Reset", message: "The UI state has been reset. Note: This does not delete any data from the database.\n\nNew test data generated:\nEmail: \(email)\nUsername: \(username)\n\n\(userIdMessage)", type: .info)
    }
    
    private func debugState() {
        let stateInfo = """
        === Current State ===
        currentUserId: \(currentUserId ?? "nil")
        viewModel.userId: \(viewModel.userId ?? "nil")
        viewModel.isAuthenticated: \(viewModel.isAuthenticated)
        currentArticleId: \(currentArticleId ?? "nil")
        currentGistId: \(currentGistId ?? "nil")
        Articles count: \(viewModel.articles.count)
        Gists count: \(viewModel.gists.count)
        Categories count: \(viewModel.categories.count)
        """
        
        print(stateInfo)
        addLog(title: "Debug State", message: stateInfo, type: .info)
    }
}

// MARK: - Log Models

struct LogEntry: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let type: LogType
    let timestamp: Date
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

enum LogType {
    case info
    case success
    case error
    
    var color: Color {
        switch self {
        case .info:
            return .primary
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

// MARK: - Supporting Views

struct LogEntryView: View {
    let log: LogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(log.type.color)
                    .frame(width: 10, height: 10)
                
                Text(log.title)
                    .font(.headline)
                    .foregroundColor(log.type.color)
                
                Spacer()
                
                Text(log.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(log.message)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 16)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(log.type.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

struct GistaServiceTestView_Previews: PreviewProvider {
    static var previews: some View {
        GistaServiceTestView()
    }
} 