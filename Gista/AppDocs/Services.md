# Services

## Overview

This document provides detailed information about the service layer in the Gista iOS application. Services are responsible for handling specific functionality domains and implementing business logic independently from the view layer.

## Core Services

### GistaService

**Purpose**: Primary service for interacting with the Gista backend API.

**Key Responsibilities**:
- User management (creation, updates, deletion)
- Article and content management
- Gist creation and retrieval
- Content categorization

**Usage Example**:
```swift
// Storing an article
let article = Article(
    id: nil,
    title: "Understanding SwiftUI",
    url: URL(string: "https://example.com/swiftui-article")!,
    category: "Technology",
    userId: userCredentials.userId,
    createdAt: nil,
    updatedAt: nil,
    gistCreated: false,
    gistId: nil
)

do {
    let response = try await GistaService.shared.storeArticle(
        userId: userCredentials.userId,
        article: article
    )
    // Handle successful article storage
} catch {
    // Handle error
}
```

**Key Methods**:
- `createUser(email:password:username:)`
- `storeArticle(userId:article:autoCreateGist:)`
- `getArticles(userId:)`
- `getGist(gistId:)`
- `createGist(userId:article:)`

### FirebaseService

**Purpose**: Manages Firebase integration, primarily for authentication.

**Key Responsibilities**:
- Firebase initialization
- User authentication
- Token management
- User profile management

**Usage Example**:
```swift
// Initialize Firebase
FirebaseService.shared.initialize()

// Sign in with email and password
do {
    let result = try await FirebaseService.shared.signIn(
        email: email,
        password: password
    )
    // Handle successful sign-in
} catch {
    // Handle authentication error
}
```

**Key Methods**:
- `initialize()`
- `signIn(email:password:)`
- `signOut()`
- `createUser(email:password:)`
- `getCurrentUser()`

### SharedContentService

**Purpose**: Handles content sharing between applications and within the app.

**Key Responsibilities**:
- Processing shared content from external apps
- Managing the shared content queue
- Content validation and normalization
- Notifying the app of new shared content

**Usage Example**:
```swift
// Check for shared content when app becomes active
func applicationDidBecomeActive() {
    SharedContentService.shared.checkForSharedContent()
}

// Process a shared URL
SharedContentService.shared.processSharedURL(
    url: incomingURL,
    sourceApplication: "com.example.browser"
)
```

**Key Methods**:
- `checkForSharedContent()`
- `processSharedURL(url:sourceApplication:)`
- `shareContent(article:)`
- `clearProcessedItems()`

### FileManagerService

**Purpose**: Handles file operations and local storage.

**Key Responsibilities**:
- Storing and retrieving local files
- Caching mechanisms
- Temporary file management
- File format conversions

**Usage Example**:
```swift
// Store content to a local file
let fileURL = try FileManagerService.shared.storeContent(
    content: pdfData,
    fileName: "document.pdf",
    inDirectory: .documents
)

// Retrieve content from a local file
let content = try FileManagerService.shared.retrieveContent(from: fileURL)
```

**Key Methods**:
- `storeContent(content:fileName:inDirectory:)`
- `retrieveContent(from:)`
- `deleteFile(at:)`
- `fileExists(at:)`

### SubscriptionService

**Purpose**: Manages user subscriptions and premium features.

**Key Responsibilities**:
- In-app purchase integration
- Subscription state management
- Feature access control
- Receipt validation

**Usage Example**:
```swift
// Check if user has premium access
if SubscriptionService.shared.hasPremiumAccess() {
    // Show premium features
} else {
    // Show subscription options
}

// Purchase a subscription
SubscriptionService.shared.purchaseSubscription(productId: "com.gista.premium.monthly")
```

**Key Methods**:
- `hasPremiumAccess()`
- `purchaseSubscription(productId:)`
- `restorePurchases()`
- `validateReceipt()`

## Service Architecture

### Protocol-Based Design

Services are designed with protocol-based interfaces to enable testing and dependency injection:

```swift
protocol GistaServiceProtocol {
    func createUser(email: String, password: String, username: String) async throws -> User
    func storeArticle(userId: String, article: Article, autoCreateGist: Bool) async throws -> GistaServiceResponse
    // Additional methods
}
```

### Service Initialization

Services are typically implemented as singletons for easy access throughout the application:

```swift
public final class GistaService: GistaServiceProtocol {
    public static let shared = GistaService()
    
    private init() {
        // Private initialization logic
    }
    
    // Service implementation
}
```

### Error Handling

Services define domain-specific error types for comprehensive error handling:

```swift
enum GistaError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(String)
    case authenticationRequired
    case decodingError(Error)
    // Additional error cases
    
    var errorDescription: String? {
        // Human-readable error descriptions
    }
}
```

## Service Dependencies

### Service-to-Service Dependencies

Services may depend on other services to fulfill their responsibilities:

- `GistaService` depends on `NetworkService` for API communication
- `SharedContentService` depends on `GistaService` for storing shared content
- `FirebaseService` may trigger updates in other services after authentication

### Service-to-Model Dependencies

Services consume and produce model objects:

- `GistaService` works with `Article`, `Gist`, and `User` models
- `SharedContentService` works with `SharedItem` models
- `FileManagerService` works with file data and metadata

## Testing Services

Services are designed to be testable through mock implementations:

```swift
class MockGistaService: GistaServiceProtocol {
    var createUserCalled = false
    var storeArticleCalled = false
    
    func createUser(email: String, password: String, username: String) async throws -> User {
        createUserCalled = true
        return User(userId: "test-id", username: username, email: email, message: "Success")
    }
    
    // Additional mock implementations
}
```

## Future Service Enhancements

- **Analytics Service**: For tracking user behavior and application performance
- **Caching Service**: For improved offline capabilities
- **Notification Service**: For managing push notifications and in-app alerts
- **Synchronization Service**: For handling data synchronization between devices 