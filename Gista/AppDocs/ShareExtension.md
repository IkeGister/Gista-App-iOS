# Share Extension Integration

## Overview

The Gista Share Extension allows users to save content directly from other applications into their Gista library. This integration facilitates seamless content sharing and gist creation without requiring users to manually copy and paste links.

## Key Components

### ShareViewController

The `ShareViewController` is the entry point for the share extension, responsible for:
- Processing shared content (URLs, text, PDFs)
- Providing UI for previewing and confirming shared content
- Handling user interactions
- Communicating with the main application

### ShareViewControllerVM

The view model that manages the business logic for the share extension:
- Validates shared content
- Authenticates the user
- Sends content to the backend
- Handles errors and retries

### LinkSender

A service class that handles the API communication for creating gists from shared content:
- Makes API requests to the backend
- Formats request payloads
- Processes API responses
- Implements retry logic

## App Group Integration

The share extension communicates with the main application through an App Group:

```swift
// App Group identifier
static let appGroupId = "group.com.5dof.Gista"
```

### User Authentication

The share extension accesses the user's authentication details through the App Group:

```swift
// From ShareViewControllerVM.swift
private func loadUserId() {
    let userDefaults = UserDefaults(suiteName: AppConstants.appGroupId)
    if let storedUserId = userDefaults?.string(forKey: AppConstants.userIdKey) {
        // Verify the format (username_UUID)
        if storedUserId.contains("_") {
            self.userId = storedUserId
        } else {
            Logger.log("Warning: User ID found but not in expected format", level: .warning)
        }
    }
}
```

### Diagnostic Logging

The share extension includes enhanced logging to troubleshoot integration issues:

```swift
// Verify app group access
let diagnosticMessage = AppGroupConstants.verifyAppGroupAccess(source: "ShareExtension")
Logger.log(diagnosticMessage, level: .debug)

// Log user ID format
Logger.log("User ID format check - contains underscore: \(userId.contains("_"))", level: .debug)
```

## User ID Format Verification

The share extension verifies that the user ID follows the expected format:

```swift
// Verify the format if we expect "username_UUID"
if storedUserId.contains("_") {
    self.userId = storedUserId
    Logger.log("User ID appears to be in expected format", level: .debug)
} else {
    Logger.log("Warning: User ID found but not in expected format (username_UUID)", level: .warning)
}
```

This verification ensures that:
1. The user ID format is consistent with the main app
2. The backend will recognize the user ID
3. Any issues with ID format are logged for debugging

## Content Processing Flow

1. **Content Retrieval**:
   - Extension receives shared content from other apps
   - Content is validated and normalized

2. **Authentication Check**:
   - User ID is retrieved from App Group storage
   - Format is verified (username_UUID)
   - Authentication status is logged

3. **API Request**:
   - Content is formatted for API request
   - Request includes user ID in expected format
   - Request is sent to backend API

4. **Response Handling**:
   - Success/failure is determined from API response
   - User is shown appropriate feedback
   - Errors are logged for troubleshooting

## Error Handling

The share extension implements robust error handling for various scenarios:

```swift
func processSharedURL(_ url: URL, title: String? = nil) async -> Result<LinkResponse, LinkError> {
    // Validate user authentication
    guard let userId = self.userId else {
        return .failure(.unauthorized)
    }
    
    // Check if userId looks valid
    if !userId.contains("_") {
        return .failure(.unauthorized)
    }
    
    // Process with validated ID...
}
```

Common errors include:
- No user ID available (not authenticated)
- Invalid user ID format
- Network connectivity issues
- API errors (including "user doesn't exist")
- Content validation failures

## Implementation Example

### Sending Content to Backend

```swift
// From LinkSender.swift
func sendLink(userId: String, url: URL, title: String, category: String) async -> Result<LinkResponse, LinkError> {
    // Log the userId for debugging
    Logger.log("LinkSender: Request body - userId: \(userId)", level: .debug)
    Logger.log("LinkSender: User ID format check - contains underscore: \(userId.contains("_"))", level: .debug)
    
    // Create the request body
    let requestBody: [String: Any] = [
        "userId": userId,
        "article": [
            "category": category,
            "url": url.absoluteString,
            "title": title
        ],
        "autoCreateGist": true
    ]
    
    // Send request...
}
```

## Testing the Integration

The share extension can be tested through:
1. Using the bypass authentication feature in the main app
2. Sharing content from Safari or other apps
3. Monitoring logs for user ID format and app group access
4. Verifying that gists appear in the main app after sharing

## Troubleshooting

Common issues and solutions:
- **"User not found" errors**: Ensure the user is authenticated in the main app with the consistent ID format
- **App Group access failures**: Verify entitlements and provisioning profiles
- **Missing content**: Check logs for content validation failures
- **Network errors**: Verify connectivity and backend API status

## Future Enhancements

- Offline content queueing
- Rich content previews
- Content categorization improvements
- Multi-account support
- Enhanced error recovery 