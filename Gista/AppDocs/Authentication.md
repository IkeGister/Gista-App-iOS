# Authentication System

## Overview

Gista uses a multi-provider authentication system, with Firebase as the primary authentication provider. The system supports email/password authentication as well as social sign-in methods like Apple Sign In.

## Key Components

### UserCredentials

The `UserCredentials` class is a singleton that manages the user's authentication state and credentials throughout the application.

```swift
// Key properties
var isAuthenticated: Bool = false
var userId: String = ""
var username: String = ""
var email: String = ""
var profilePictureUrl: String?
```

### OnboardingViewModel

The `OnboardingViewModel` manages the authentication flow, including:
- User registration
- User login
- Social authentication
- Credential validation
- Error handling

### FirebaseService

The `FirebaseService` handles interaction with Firebase Authentication, including:
- User creation
- Authentication
- Token management
- User profile updates

## User ID Format

Gista uses a consistent user ID format throughout the application:

```
username_UUID
```

This format:
- Ensures uniqueness across the system
- Makes IDs human-readable with the username prefix
- Allows consistent identification between the app and extensions
- Provides reliable user identification with the backend

The user ID is generated during user creation in `GistaService.createUser()` and maintained consistently across:
- Local storage via UserDefaults
- App Group shared storage for extensions
- Backend API communication

Example implementation:
```swift
// During user creation
let consistentUserId = "\(username)_\(UUID().uuidString)"
return CreateUserRequest(userId: consistentUserId, email: email, password: password, username: username)
```

## Authentication Flow

1. **Launch Screen**:
   - The app starts with a launch screen (`LaunchScreen.swift`)
   - Checks for existing authentication tokens

2. **Onboarding**:
   - If no valid authentication exists, the app shows the onboarding flow (`OnboardingView.swift`)
   - User can choose to sign in or register

3. **Registration**:
   - User provides email, username, and password
   - Validation is performed on inputs
   - `OnboardingViewModel` calls Firebase to create a new user
   - On success, a record is created in the Gista backend via `GistaService`

4. **Sign In**:
   - User provides credentials
   - Validation is performed
   - Firebase authentication is attempted
   - On success, user information is stored in `UserCredentials`

5. **Social Sign In**:
   - User selects social sign-in (Apple)
   - OAuth flow is handled
   - User information is retrieved and stored

6. **Token Management**:
   - Authentication tokens are stored securely
   - Tokens are refreshed as needed
   - Tokens are used for authenticated API requests

7. **Session Management**:
   - User session information is stored in UserDefaults
   - `UserCredentials` manages the active session
   - Automatic sign-in is supported for returning users

## Test Authentication

For testing purposes, the app provides a bypass authentication feature:

```swift
// From OnboardingViewModel.swift
func bypassAuthentication() async {
    // Create a temporary test user
    let username = "TestUser"
    let uuid = UUID().uuidString
    let testUserId = "\(username)_\(uuid)"
    
    // Create the user in the backend
    let backendUser = try await createTestUserInBackend(initialTestUser)
    
    // Use the backend-provided ID for consistent identification
    let finalUser = User(
        userId: backendUser.userId,
        message: backendUser.message,
        username: username,
        email: "test@example.com",
        isAuthenticated: true,
        lastLoginDate: Date()
    )
    
    // Save user to local storage with backend user ID
    saveUser(finalUser)
}
```

This approach:
- Creates a test user with a consistent user ID format
- Properly registers with the backend API
- Shares the same ID across app and extensions
- Avoids authentication issues in development

## Error Handling

Authentication errors are categorized and handled appropriately:
- Invalid credentials
- Network issues
- Account already exists
- Invalid email format
- Weak password
- Server errors

## Sign-Out Flow

1. User initiates sign-out from the profile section
2. `UserCredentials` clears stored credentials
3. Firebase sign-out is called
4. User is redirected to the onboarding flow

## Security Considerations

- Passwords are never stored in the app
- Authentication tokens are stored securely
- Sensitive operations require re-authentication
- Failed authentication attempts are limited

## Code Snippets

### Initializing Firebase Authentication

```swift
// From FirebaseService.swift
func initialize() {
    FirebaseApp.configure()
    // Additional setup as needed
}
```

### User Sign-In

```swift
// From OnboardingViewModel.swift
func signIn(email: String, password: String) async throws -> Bool {
    do {
        // Firebase authentication
        // Store credentials on success
        return true
    } catch {
        // Handle authentication errors
        throw error
    }
}
```

## Future Enhancements

- Additional social sign-in options (Google, Facebook)
- Biometric authentication
- Multi-factor authentication
- Enhanced session management
- Password reset flow improvements 