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
    
    // MARK: - Private Properties
    private let gistaViewModel: GistaServiceViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(gistaViewModel: GistaServiceViewModel = GistaServiceViewModel()) {
        self.gistaViewModel = gistaViewModel
    }
    
    // MARK: - Authentication Methods
    func createAccount() async {
        guard validateSignupForm() else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            showError = false
        }
        
        do {
            try await gistaViewModel.createUser(email: email, password: password, username: username)
            
            await MainActor.run {
                isAuthenticated = gistaViewModel.isAuthenticated
                if isAuthenticated {
                    currentStep = .complete
                }
            }
        } catch let error as NetworkError {
            await MainActor.run {
                errorMessage = error.errorDescription
                showError = true
            }
        } catch let error as GistaError {
            await MainActor.run {
                errorMessage = error.errorDescription
                showError = true
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        
        await MainActor.run {
            isLoading = false
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
        case .complete:
            // Handle completion, perhaps by setting a user defaults flag
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
    }
    
    func previousStep() {
        switch currentStep {
        case .signup:
            currentStep = .welcome
        case .complete:
            currentStep = .signup
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
    
    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Onboarding Steps
enum OnboardingStep {
    case welcome
    case signup
    case complete
}

