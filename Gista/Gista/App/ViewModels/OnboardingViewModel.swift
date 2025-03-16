//
//  OnboardingViewModel.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import Foundation
import SwiftUI
import Combine
import Shared
import FirebaseAuth

class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var username: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isAuthenticated: Bool = false
    @Published var user: User?
    @Published var showLaunchScreen: Bool = true
    @Published var useTestAPI: Bool = false
    @Published var currentNonce: String? // For Apple Sign In
    
    // MARK: - Private Properties
    private let gistaViewModel: GistaServiceViewModel
    private let firebaseService: FirebaseAuthServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(gistaViewModel: GistaServiceViewModel = GistaServiceViewModel(), 
         firebaseService: FirebaseAuthServiceProtocol = FirebaseService.shared) {
        self.gistaViewModel = gistaViewModel
        self.firebaseService = firebaseService
        
        // Check if user is already authenticated
        checkAuthenticationStatus()
    }
    
    // MARK: - Authentication Methods
    private func checkAuthenticationStatus() {
        if let savedUser = UserConfiguration.shared.loadUser(), savedUser.isAuthenticated {
            self.user = savedUser
            self.isAuthenticated = true
            self.currentStep = .complete
            
            // Update UserCredentials
            UserCredentials.shared.updateFrom(user: savedUser)
        }
        
        // Always show the launch screen during development
        // This ensures the debug options are always available on startup
        self.showLaunchScreen = true
    }
    
    func createAccount() async {
        @MainActor func updateLoadingState(isLoading: Bool, errorMessage: String? = nil, showError: Bool = false) {
            self.isLoading = isLoading
            self.errorMessage = errorMessage
            self.showError = showError
        }
        
        @MainActor func updateUserState(user: User) {
            self.user = user
            self.isAuthenticated = true
            self.currentStep = .complete
            
            // Save user to local storage
            saveUser(user)
        }
        
        guard validateSignupForm() else { return }
        
        // Set loading state
        await updateLoadingState(isLoading: true)
        
        do {
            // Create user in Firebase
            let firebaseUser = try await firebaseService.signUp(email: email, password: password)
            
            // Create a profile change request to set the display name
            let changeRequest = firebaseUser.createProfileChangeRequest()
            changeRequest.displayName = username
            try await changeRequest.commitChanges()
            
            // Create user in Gista backend
            try await gistaViewModel.createUser(email: email, password: password, username: username)
            
            // Create and save user object
            let user = User(
                userId: firebaseUser.uid,
                message: "Account created successfully",
                username: username,
                email: email,
                isAuthenticated: true,
                lastLoginDate: Date()
            )
            
            // Update user state on main actor
            await updateUserState(user: user)
        } catch let error as NSError {
            await updateLoadingState(isLoading: false, errorMessage: error.localizedDescription, showError: true)
        } catch let error as NetworkError {
            await updateLoadingState(isLoading: false, errorMessage: error.errorDescription, showError: true)
        } catch let error as GistaError {
            await updateLoadingState(isLoading: false, errorMessage: error.errorDescription, showError: true)
        } catch {
            await updateLoadingState(isLoading: false, errorMessage: error.localizedDescription, showError: true)
        }
    }
    
    func signIn() async {
        @MainActor func updateLoadingState(isLoading: Bool, errorMessage: String? = nil, showError: Bool = false) {
            self.isLoading = isLoading
            self.errorMessage = errorMessage
            self.showError = showError
        }
        
        @MainActor func updateUserState(user: User) {
            self.user = user
            self.isAuthenticated = true
            self.currentStep = .complete
            
            // Save user to local storage
            saveUser(user)
        }
        
        guard validateSignInForm() else { return }
        
        // Set loading state
        await updateLoadingState(isLoading: true)
        
        do {
            // Sign in with Firebase
            let firebaseUser = try await firebaseService.signIn(email: email, password: password)
            
            // Create and save user object
            let user = User(
                userId: firebaseUser.uid,
                message: "Signed in successfully",
                username: firebaseUser.displayName ?? "",
                email: email,
                isAuthenticated: true,
                lastLoginDate: Date()
            )
            
            // Update user state on main actor
            await updateUserState(user: user)
        } catch {
            // Handle error on main actor
            await updateLoadingState(isLoading: false, errorMessage: error.localizedDescription, showError: true)
        }
    }
    
    func signOut() async {
        @MainActor func updateAuthState(isAuthenticated: Bool, errorMessage: String? = nil, showError: Bool = false) {
            if !isAuthenticated {
                self.user = nil
                self.isAuthenticated = false
                self.currentStep = .welcome
                
                // Clear user from local storage
                clearUser()
            }
            
            if let errorMessage = errorMessage {
                self.errorMessage = errorMessage
                self.showError = showError
            }
        }
        
        do {
            try firebaseService.signOut()
            await updateAuthState(isAuthenticated: false)
        } catch {
            await updateAuthState(isAuthenticated: true, errorMessage: error.localizedDescription, showError: true)
        }
    }
    
    // MARK: - Launch Screen Methods
    func dismissLaunchScreen() {
        showLaunchScreen = false
    }
    
    func launchApp(useTestAPI: Bool = false) {
        self.useTestAPI = useTestAPI
        
        // Explicitly dismiss the launch screen when a button is tapped
        dismissLaunchScreen()
        
        // Set the appropriate next step
        if isAuthenticated {
            currentStep = .complete
        } else {
            currentStep = .welcome
        }
    }
    
    // MARK: - Navigation Methods
    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .signup
        case .signup:
            Task {
                await createAccount()
            }
        case .signIn:
            Task {
                await signIn()
            }
        case .complete:
            // Handle completion, perhaps by setting a user defaults flag
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
    }
    
    func goToSignIn() {
        currentStep = .signIn
    }
    
    func goToSignUp() {
        currentStep = .signup
    }
    
    func previousStep() {
        switch currentStep {
        case .signup, .signIn:
            currentStep = .welcome
        case .complete:
            // This shouldn't happen in normal flow
            break
        default:
            break
        }
    }
    
    // MARK: - Validation Methods
    private func validateSignupForm() -> Bool {
        // Email validation
        guard !email.isEmpty else {
            setError("Email cannot be empty")
            return false
        }
        
        guard email.contains("@") && email.contains(".") else {
            setError("Please enter a valid email address")
            return false
        }
        
        // Password validation
        guard !password.isEmpty else {
            setError("Password cannot be empty")
            return false
        }
        
        guard password.count >= 8 else {
            setError("Password must be at least 8 characters")
            return false
        }
        
        guard password == confirmPassword else {
            setError("Passwords do not match")
            return false
        }
        
        // Username validation
        guard !username.isEmpty else {
            setError("Username cannot be empty")
            return false
        }
        
        guard username.count >= 3 else {
            setError("Username must be at least 3 characters")
            return false
        }
        
        return true
    }
    
    private func validateSignInForm() -> Bool {
        // Email validation
        guard !email.isEmpty else {
            setError("Email cannot be empty")
            return false
        }
        
        guard email.contains("@") && email.contains(".") else {
            setError("Please enter a valid email address")
            return false
        }
        
        // Password validation
        guard !password.isEmpty else {
            setError("Password cannot be empty")
            return false
        }
        
        return true
    }
    
    func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    // MARK: - Social Authentication Methods
    func signInWithGoogle() async {
        @MainActor func updateLoadingState(isLoading: Bool, errorMessage: String? = nil, showError: Bool = false) {
            self.isLoading = isLoading
            self.errorMessage = errorMessage
            self.showError = showError
        }
        
        @MainActor func updateUserState(user: User) {
            self.user = user
            self.isAuthenticated = true
            self.currentStep = .complete
            
            // Save user to local storage
            saveUser(user)
        }
        
        @MainActor func getRootViewController() throws -> UIViewController {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                throw NSError(domain: "OnboardingViewModel", code: 0, userInfo: [NSLocalizedDescriptionKey: "No root view controller found"])
            }
            return rootViewController
        }
        
        // Set loading state
        await updateLoadingState(isLoading: true)
        
        do {
            // Get the root view controller using the modern approach
            let rootViewController = try await getRootViewController()
            
            // Sign in with Google
            let firebaseUser = try await firebaseService.signInWithGoogle(presenting: rootViewController)
            
            // Create and save user object
            let user = User(
                userId: firebaseUser.uid,
                message: "Signed in with Google successfully",
                username: firebaseUser.displayName ?? "",
                email: firebaseUser.email ?? "",
                isAuthenticated: true,
                lastLoginDate: Date()
            )
            
            // Update UI on main actor
            await updateLoadingState(isLoading: false)
            
            // Update user state on main actor
            await updateUserState(user: user)
        } catch {
            // Handle error on main actor
            await updateLoadingState(isLoading: false, errorMessage: error.localizedDescription, showError: true)
        }
    }
    
    func prepareForAppleSignIn() -> String {
        let nonce = firebaseService.createNonce()
        currentNonce = nonce
        return nonce
    }
    
    func signInWithApple(idTokenString: String, fullName: PersonNameComponents? = nil) async {
        @MainActor func updateLoadingState(isLoading: Bool, errorMessage: String? = nil, showError: Bool = false) {
            self.isLoading = isLoading
            self.errorMessage = errorMessage
            self.showError = showError
        }
        
        @MainActor func updateUserState(user: User) {
            self.user = user
            self.isAuthenticated = true
            self.currentStep = .complete
            
            // Save user to local storage
            saveUser(user)
        }
        
        guard let nonce = currentNonce else {
            await updateLoadingState(isLoading: false, errorMessage: "Invalid state: A login callback was received, but no login request was sent.", showError: true)
            return
        }
        
        // Set loading state
        await updateLoadingState(isLoading: true)
        
        do {
            // Sign in with Apple
            let firebaseUser = try await firebaseService.signInWithApple(nonce: nonce, idTokenString: idTokenString, fullName: fullName)
            
            // Create and save user object
            let user = User(
                userId: firebaseUser.uid,
                message: "Signed in with Apple successfully",
                username: firebaseUser.displayName ?? "",
                email: firebaseUser.email ?? "",
                isAuthenticated: true,
                lastLoginDate: Date()
            )
            
            // Update UI on main actor
            await updateLoadingState(isLoading: false)
            
            // Update user state on main actor
            await updateUserState(user: user)
        } catch {
            // Handle error on main actor
            await updateLoadingState(isLoading: false, errorMessage: error.localizedDescription, showError: true)
        }
    }
    
    // MARK: - Apple Sign In
    func processAppleSignInResult(userId: String, email: String?, fullName: PersonNameComponents?) {
        // Create a username from the full name if available
        let username = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        // Create a user object
        let user = User(
            userId: userId,
            message: "User authenticated with Apple",
            username: username,
            email: email ?? "",
            isAuthenticated: true,
            lastLoginDate: Date()
        )
        
        // Update the view model
        self.user = user
        self.isAuthenticated = true
        self.currentStep = .complete
        
        // Save user to local storage
        saveUser(user)
        
        print("Saved Apple user with name: \(username)")
    }
    
    // MARK: - Helper Methods
    private func saveUser(_ user: User) {
        UserConfiguration.shared.saveUser(user)
        UserCredentials.shared.updateFrom(user: user)
    }
    
    private func clearUser() {
        UserConfiguration.shared.clearUser()
        UserCredentials.shared.clearCredentials()
    }
}

// MARK: - Onboarding Steps
enum OnboardingStep {
    case welcome
    case signup
    case signIn
    case complete
}

