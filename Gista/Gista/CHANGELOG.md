# Changelog

## [Unreleased] - 2025-03-14

### Added
- LaunchScreen with full-screen logo and buttons at the lower third
- Firebase authentication integration
- User model converted from struct to class with additional properties
- User persistence using UserDefaults
- OnboardingViewModel with Firebase authentication support
- OnboardingView with welcome, sign-up, sign-in, and completion screens
- Updated GistaApp to handle the onboarding flow

### Changed
- User model is now a class instead of a struct
- User model now includes additional properties like username, email, isAuthenticated, and lastLoginDate
- OnboardingViewModel now uses Firebase for authentication
- GistaApp now initializes Firebase and handles the onboarding flow

### Folder Changes
- `/Gista/Gista/App/Services/FirebaseService.swift`: Implemented Firebase authentication service
- `/Gista/Gista/App/User/User.swift`: Converted from struct to class and added persistence
- `/Gista/Gista/App/ViewModels/OnboardingViewModel.swift`: Updated to use Firebase authentication
- `/Gista/Gista/App/Views/Onboarding/LaunchScreen.swift`: Implemented full-screen logo with buttons
- `/Gista/Gista/App/Views/Onboarding/OnboardingView.swift`: Created new file for onboarding flow
- `/Gista/App/GistaApp.swift`: Updated to initialize Firebase and handle onboarding 
