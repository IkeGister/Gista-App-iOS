# UI Components

## Overview

This document provides a comprehensive overview of the reusable UI components in the Gista iOS application. These components ensure consistency throughout the application and simplify the development of new features.

## Core Components

### Navigation Components

#### NavigationManager

The `NavigationManager` is a central class that manages navigation throughout the application.

**Key Features**:
- Path-based navigation using SwiftUI navigation paths
- Programmatic navigation between screens
- Support for deep linking
- Navigation history management

**Usage Example**:
```swift
// In a view
@EnvironmentObject private var navigationManager: NavigationManager

// Navigation action
Button("Go to Settings") {
    navigationManager.navigateToSettings()
}

// Applying navigation infrastructure to a view
ContentView()
    .withNavigationStack()
    .environmentObject(NavigationManager())
```

### Authentication Components

#### AppleSignInButton

A custom button that implements Apple Sign In functionality.

**Key Features**:
- Standard Apple design guidelines compliance
- Custom styling options
- Built-in authentication flow
- Error handling

**Usage Example**:
```swift
AppleSignInButton(
    onCompletion: { result in
        // Handle authentication result
    },
    onError: { error in
        // Handle error
    }
)
.frame(height: 50)
.cornerRadius(8)
```

### Content Display Components

#### MiniPlalyerView

A compact player view that appears when content is being played but the user is navigating elsewhere in the app.

**Key Features**:
- Minimized playback controls
- Drag-to-dismiss functionality
- Animation transitions
- Content metadata display

**Usage Example**:
```swift
ZStack {
    // Main content
    ContentView()
    
    // Mini player if content is active
    if viewModel.isPlaybackActive {
        MiniPlalyerView(
            title: viewModel.currentGist.title,
            onTap: {
                navigationManager.navigateToFullPlayback()
            },
            onDismiss: {
                viewModel.stopPlayback()
            }
        )
    }
}
```

#### LibraryView

The main content browsing interface that displays categorized content collections.

**Key Features**:
- Grid and list display options
- Category filtering
- Content card previews
- Pull-to-refresh functionality

**Usage Example**:
```swift
LibraryView()
    .environmentObject(libraryViewModel)
```

### Input Components

#### SearchView

A dedicated search interface for finding content.

**Key Features**:
- Real-time search suggestions
- History of recent searches
- Filter options
- Result categorization

**Usage Example**:
```swift
SearchView()
    .environmentObject(SearchViewModel())
```

### User Interface Components

#### UserProfile

Profile management interface for user information and settings.

**Key Features**:
- Profile photo management
- User information display and editing
- Settings access
- Sign-out functionality

**Usage Example**:
```swift
UserProfile()
    .environmentObject(userCredentials)
```

## Styling and Theming

### Color Scheme

The application uses a consistent color scheme defined in asset catalogs and extensions:

```swift
// Color extension examples
extension Color {
    static let primaryBackground = Color("PrimaryBackground")
    static let secondaryBackground = Color("SecondaryBackground")
    static let primaryText = Color("PrimaryText")
    static let accentColor = Color.yellow
}
```

**Usage**:
```swift
Text("Hello, World")
    .foregroundColor(.primaryText)
    .background(Color.primaryBackground)
```

### Typography

Consistent typography is maintained through extensions and modifiers:

```swift
// Text style extensions
extension View {
    func titleStyle() -> some View {
        self.font(.system(size: 24, weight: .bold))
            .foregroundColor(.primaryText)
    }
    
    func bodyStyle() -> some View {
        self.font(.system(size: 16, weight: .regular))
            .foregroundColor(.primaryText)
    }
}
```

**Usage**:
```swift
Text("Article Title")
    .titleStyle()

Text("Article content goes here...")
    .bodyStyle()
```

### Modifiers

Custom view modifiers encapsulate common style patterns:

```swift
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.secondaryBackground)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        self.modifier(CardStyle())
    }
}
```

**Usage**:
```swift
VStack {
    // Card contents
}
.cardStyle()
```

## Custom Controls

### PlaybackControls

Controls for audio/content playback.

**Key Features**:
- Play/pause button
- Progress indicator
- Time display
- Speed control

**Usage Example**:
```swift
PlaybackControls(
    isPlaying: $viewModel.isPlaying,
    progress: $viewModel.progress,
    duration: viewModel.duration,
    onPlayPause: {
        viewModel.togglePlayback()
    },
    onSeek: { position in
        viewModel.seek(to: position)
    }
)
```

### ContentActionBar

A bar of action buttons for operating on content.

**Key Features**:
- Share button
- Save button
- More options menu
- Custom action support

**Usage Example**:
```swift
ContentActionBar(
    onShare: {
        viewModel.shareContent()
    },
    onSave: {
        viewModel.saveContent()
    },
    onMore: {
        viewModel.showMoreOptions()
    }
)
```

## Animation and Transitions

### Standard Transitions

The application uses consistent transitions between views:

```swift
// Example transition
.transition(.asymmetric(
    insertion: .move(edge: .bottom).combined(with: .opacity),
    removal: .move(edge: .bottom).combined(with: .opacity)
))
```

### Loading States

Components for displaying loading states:

```swift
// Example loading state view
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
            Text("Loading...")
                .foregroundColor(.secondaryText)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primaryBackground.opacity(0.8))
    }
}
```

## Accessibility

Components are designed with accessibility in mind:

```swift
// Example accessibility implementation
Button(action: {
    viewModel.playContent()
}) {
    Image(systemName: "play.fill")
        .font(.system(size: 24))
        .foregroundColor(.accentColor)
}
.accessibilityLabel("Play content")
.accessibilityHint("Double tap to play the current article")
```

## Component Hierarchy

The application follows a component hierarchy for organizing UI elements:

1. **Screens**: Full-screen views like ContentView, LibraryView
2. **Sections**: Major sections within screens
3. **Cards/Panels**: Container components that group related elements
4. **Controls**: Interactive elements like buttons and inputs

## Best Practices for Component Usage

1. **Reuse Existing Components**: Before creating new UI elements, check if existing components can be adapted.
2. **Follow Design Patterns**: Maintain consistent styling and behavior.
3. **Implement Accessibility**: Ensure all components have appropriate accessibility labels and hints.
4. **Support Dark Mode**: Test components in both light and dark mode.
5. **Responsive Design**: Components should adapt to different screen sizes.

## Future Component Development

- Enhanced animation system for smoother transitions
- Component library documentation with usage examples
- Component previews for SwiftUI preview support
- Design system integration 