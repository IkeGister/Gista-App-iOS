//
//  AppleSignInButton.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct AppleSignInButton<ViewModel: OnboardingViewModelProtocol>: View {
    @EnvironmentObject private var viewModel: ViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    // Store strong references to the delegate and presentation context provider
    @State private var signInDelegate: AppleSignInDelegate<ViewModel>?
    @State private var presentationContextProvider = AppleSignInPresentationContext()
    
    var body: some View {
        Button(action: {
            handleAppleSignIn()
        }) {
            HStack {
                Image(systemName: "apple.logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(.white)
                
                Text("Sign in with Apple")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
        }
    }
    
    @MainActor
    private func handleAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        // Generate a nonce for secure authentication
        let nonce = viewModel.prepareForAppleSignIn()
        request.nonce = sha256(nonce)
        
        // Create and store a strong reference to the delegate
        signInDelegate = AppleSignInDelegate(viewModel: viewModel)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = signInDelegate
        authorizationController.presentationContextProvider = presentationContextProvider
        authorizationController.performRequests()
    }
    
    // Helper function to hash the nonce
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// Apple Sign In Delegate
@MainActor
class AppleSignInDelegate<ViewModel: OnboardingViewModelProtocol>: NSObject, ASAuthorizationControllerDelegate {
    private var viewModel: ViewModel
    
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
           let appleIDToken = appleIDCredential.identityToken,
           let idTokenString = String(data: appleIDToken, encoding: .utf8) {
            
            // Process the Apple ID credential
            Task {
                await viewModel.signInWithApple(idTokenString: idTokenString, fullName: appleIDCredential.fullName)
                
                // If we have a name, update the user's profile
                if let fullName = appleIDCredential.fullName,
                   let givenName = fullName.givenName,
                   let familyName = fullName.familyName {
                    // You can update the user's display name here if needed
                    print("User name: \(givenName) \(familyName)")
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error
        viewModel.setError(error.localizedDescription)
    }
}

// Presentation Context Provider
class AppleSignInPresentationContext: NSObject, ASAuthorizationControllerPresentationContextProviding {
    @MainActor
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the active window scene and its first window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            // Fallback for older iOS versions or if no window is found
            return UIWindow()
        }
        return window
    }
}

// Type eraser for AppleSignInButton to use with OnboardingViewModel in the app
extension AppleSignInButton where ViewModel == OnboardingViewModel {
    static func withOnboardingViewModel() -> some View {
        AppleSignInButton<OnboardingViewModel>()
    }
}

#Preview("Apple Sign In Button") {
    AppleSignInButton<MockOnboardingViewModel>()
        .environmentObject(MockOnboardingViewModel())
        .preferredColorScheme(.dark)
        .padding()
} 
