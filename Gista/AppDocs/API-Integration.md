# API Integration

## Overview

Gista communicates with backend services through a RESTful API architecture. The application uses a structured networking layer to handle API requests, responses, error handling, and data serialization.

## API Architecture

### Base URL

The API uses different base URLs depending on the environment:

```swift
// Development environment
URL(string: "https://us-central1-dof-ai.cloudfunctions.net/api")!

// Production environment
URL(string: "https://us-central1-dof-ai.cloudfunctions.net/api")!
```

### Network Layer Components

1. **NetworkService**: Core service that handles network requests
2. **NetworkServiceProtocol**: Interface defining network operations
3. **HTTPMethod**: Enum representing HTTP methods (GET, POST, PUT, DELETE)
4. **NetworkError**: Error types for network operations
5. **RequestModels**: Data structures for API requests

## User ID Format

Gista uses a consistent user ID format across all API integrations:

```
username_UUID
```

This format is critical for API operations because:

1. **Identification Consistency**: Ensures the same user ID is used across:
   - Main app API requests
   - Share extension API requests 
   - Backend database storage

2. **API Request Format**: User ID is included in request bodies:

```swift
// Example of createUser request body
let body = CreateUserRequest(
    userId: "\(username)_\(UUID().uuidString)",  // Consistent format
    email: email,
    password: password,
    username: username
)
```

3. **Error Prevention**: Many API errors are related to inconsistent user IDs:
   - "User doesn't exist" errors in share extension
   - Authentication failures
   - Content retrieval failures

4. **Implementation Locations**:
   - User creation in `GistaService.swift`
   - User ID verification in `ShareViewControllerVM.swift`
   - Test user creation in `OnboardingViewModel.swift`

## Authentication

API requests that require authentication include an Authorization header with a Bearer token:

```swift
// Adding auth token to request
if let token = authToken {
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
}
```

## Key Endpoints

### User Management

- **Create User**: `/users` (POST)
- **Update User**: `/users/{userId}` (PUT)
- **Delete User**: `/users/{userId}` (DELETE)

### Content Management

- **Store Article**: `/store-link` (POST)
- **Get User's Articles**: `/links/{userId}` (GET)
- **Get Gist**: `/gists/{gistId}` (GET)
- **Create Gist**: `/gists` (POST)
- **Delete Gist**: `/gists/{gistId}` (DELETE)

## Request/Response Models

### User

```swift
struct User: Codable {
    let userId: String
    let username: String
    let email: String
    let message: String
    // Additional properties
}
```

### Article

```swift
struct Article: Codable {
    let id: String?
    let title: String
    let url: URL
    let category: String
    // Additional properties
}
```

### Gist

```swift
struct Gist: Codable {
    let id: String
    let title: String
    let content: String
    let userId: String
    let sourceUrl: URL?
    // Additional properties
}
```

## Error Handling

The application uses a comprehensive error handling system for API responses:

```swift
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
    case unauthorized
    case serverError(String)
    case unknown
    
    var errorDescription: String? {
        // Error descriptions
    }
}
```

## Request Implementation

### Network Service Implementation

The `NetworkService` class implements the `NetworkServiceProtocol` and provides the core functionality for making requests:

```swift
func performRequest<T: Decodable>(_ endpoint: String,
                                 method: HTTPMethod,
                                 headers: [String: String]? = nil,
                                 body: Encodable? = nil,
                                 queryItems: [URLQueryItem]? = nil) async throws -> T {
    // Request implementation with retry logic
}
```

### GistaService Implementation

The `GistaService` class provides domain-specific API operations:

```swift
func storeArticle(userId: String, article: Article, autoCreateGist: Bool = true) async throws -> GistaServiceResponse {
    let endpoint = Endpoint.storeLink(
        userId: userId,
        category: article.category,
        url: article.url.absoluteString,
        title: article.title,
        autoCreateGist: autoCreateGist
    )
    
    // Make the request and handle the response
}
```

## Cross-Process API Integration

### Share Extension Integration

The share extension uses the same API endpoints but must handle user ID retrieval differently:

```swift
// From ShareViewControllerVM.swift
func processSharedURL(_ url: URL, title: String? = nil) async -> Result<LinkResponse, LinkError> {
    // Retrieve user ID from App Group
    guard let userId = self.userId else {
        return .failure(.unauthorized)
    }
    
    // Verify proper format
    if !userId.contains("_") {
        Logger.log("User ID format invalid: \(userId)", level: .error)
        return .failure(.unauthorized)
    }
    
    // Make API request with verified user ID
    let result = await linkSender.sendLink(
        userId: userId,
        url: url,
        title: sanitizedTitle,
        category: category
    )
}
```

This integration ensures:
1. Consistent user identification across app components
2. Successful API operations from all entry points
3. Proper error handling for authentication issues

## Retry Logic

The application implements retry logic for handling transient network issues:

```swift
// From NetworkService.swift
for attempt in 0...NetworkConstants.maxRetryAttempts {
    do {
        // Attempt request
    } catch {
        // Handle error and retry if appropriate
        // Wait before retrying
        try? await Task.sleep(nanoseconds: UInt64(NetworkConstants.retryDelay * 1_000_000_000))
    }
}
```

## Network Monitoring

The application includes a `NetworkMonitor` class to track network connectivity:

```swift
class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private(set) var isConnected: Bool = true
    
    func startMonitoring() {
        // Implementation would use NWPathMonitor
    }
    
    func stopMonitoring() {
        // Stop monitoring
    }
}
```

## Testing Network Operations

The application uses protocols and dependency injection to facilitate testing of network operations. The `URLSessionProtocol` allows for mocking network responses in tests.

## API Response Caching

The application supports configurable caching policies for API responses:

```swift
// From GistaService.swift
public struct RequestConfig {
    let timeout: TimeInterval
    let cachePolicy: URLRequest.CachePolicy
    
    public static let `default` = RequestConfig(
        timeout: 30.0,
        cachePolicy: .useProtocolCachePolicy
    )
}
```

## Future API Considerations

- Implementing a comprehensive token refresh mechanism
- Adding support for WebSocket connections for real-time updates
- Expanding caching strategies for improved offline experience
- Implementing more robust API versioning support 