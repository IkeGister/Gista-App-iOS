# Data Models

## Overview

This document provides an overview of the core data models in the Gista iOS application and their relationships. Understanding these models is essential for working with the application's data layer.

## Core Models

### User

The `User` model represents a user in the application.

```swift
struct User: Codable {
    let userId: String
    let username: String
    let email: String
    let message: String
    let createdAt: Date?
    let updatedAt: Date?
}
```

**Key Properties**:
- `userId`: Unique identifier for the user
- `username`: User's display name
- `email`: User's email address
- `message`: Message from the server (often used for status messages)

**Usage**:
- Authentication responses
- User profile information
- User management operations

### Article

The `Article` model represents content that users can save and interact with.

```swift
struct Article: Codable {
    let id: String?
    let title: String
    let url: URL
    let category: String
    let userId: String
    let createdAt: Date?
    let updatedAt: Date?
    let gistCreated: Bool?
    let gistId: String?
}
```

**Key Properties**:
- `id`: Unique identifier for the article
- `title`: Article title
- `url`: URL to the original content
- `category`: Category classification
- `userId`: ID of the user who saved the article
- `gistCreated`: Whether a gist has been created for this article
- `gistId`: ID of the associated gist if available

**Usage**:
- Content library displays
- Content recommendation
- Search results

### Gist

The `Gist` model represents a summarized version of an article's content.

```swift
struct Gist: Codable {
    let id: String
    let title: String
    let content: String
    let userId: String
    let sourceUrl: URL?
    let category: String?
    let createdAt: Date?
    let updatedAt: Date?
}
```

**Key Properties**:
- `id`: Unique identifier for the gist
- `title`: Gist title (often derived from the article)
- `content`: The summarized content
- `userId`: ID of the user who owns the gist
- `sourceUrl`: Original URL the gist was created from
- `category`: Category classification

**Usage**:
- Content consumption
- Offline access
- Sharing functionality

### SharedItem

The `SharedItem` model represents content that has been shared with or by the user.

```swift
struct SharedItem: Codable, Identifiable {
    let id: String
    let url: String
    let title: String?
    let sourceApplication: String?
    let createdAt: Date
    var processed: Bool
}
```

**Key Properties**:
- `id`: Unique identifier for the shared item
- `url`: URL of the shared content
- `title`: Optional title of the shared content
- `sourceApplication`: Application that initiated the share
- `processed`: Flag indicating whether the item has been processed

**Usage**:
- App extensions
- Content sharing between applications
- Shared content processing queue

## Model Relationships

### User to Articles

- One-to-many relationship
- A user can have multiple articles
- Articles belong to a single user
- Relationship defined by the `userId` property in the `Article` model

### Articles to Gists

- One-to-one relationship
- An article can have one associated gist
- A gist is typically associated with one article
- Relationship defined by the `gistId` property in the `Article` model

### User to Gists

- One-to-many relationship
- A user can have multiple gists
- Gists belong to a single user
- Relationship defined by the `userId` property in the `Gist` model

## Data Persistence

### UserDefaults

Used for storing simple user preferences and basic authentication state:

```swift
// Example from UserCredentials
UserDefaults.standard.set(isAuthenticated, forKey: "isSignedIn")
UserDefaults.standard.set(userId, forKey: "userId")
UserDefaults.standard.set(username, forKey: "username")
UserDefaults.standard.set(email, forKey: "userEmail")
```

### SwiftData

Used for more complex data structures and relationships.

**Key Model Schema**:
- Models are defined using the `@Model` macro for SwiftData integration
- Relationships between models are defined using properties with appropriate types
- Persistence operations handled through `ModelContext`

## API Responses

API responses are structured to map to the data models described above:

### Request Models

```swift
struct CreateUserRequest: Codable {
    let email: String
    let password: String
    let username: String
}

struct StoreArticleRequest: Codable {
    let userId: String
    let url: String
    let title: String
    let category: String
    let autoCreateGist: Bool
}
```

### Response Models

```swift
struct GistaServiceResponse: Codable {
    let message: String
    let linkId: String?
    let gistId: String?
    let gistCreated: Bool?
}

struct UserResponse: Codable {
    let userId: String
    let username: String
    let email: String
    let message: String
}
```

## Data Transformations

The application includes utilities for transforming between model formats:

```swift
// Example transformation from API response to local model
extension Article {
    static func from(response: ArticleResponse) -> Article {
        return Article(
            id: response.id,
            title: response.title,
            url: URL(string: response.url)!,
            category: response.category,
            userId: response.userId,
            createdAt: ISO8601DateFormatter().date(from: response.createdAt),
            updatedAt: ISO8601DateFormatter().date(from: response.updatedAt),
            gistCreated: response.gistCreated,
            gistId: response.gistId
        )
    }
}
```

## Future Considerations

- Implementation of full Core Data stack for complex persistence requirements
- Enhanced offline capability through local caching of models
- Improved conflict resolution for concurrent model updates
- Support for model versioning and migration
- Real-time synchronization of models using server events 