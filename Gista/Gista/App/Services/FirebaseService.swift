//
//  FirebaseService.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import Combine
import GoogleSignIn
import GoogleSignInSwift
import CryptoKit
import AuthenticationServices

protocol FirebaseAuthServiceProtocol {
    func initialize()
    func signUp(email: String, password: String) async throws -> FirebaseAuth.User
    func signIn(email: String, password: String) async throws -> FirebaseAuth.User
    func signOut() throws
    func getCurrentUser() -> FirebaseAuth.User?
    func isUserAuthenticated() -> Bool
    func deleteAccount() async throws
    func resetPassword(email: String) async throws
    func updateEmail(to email: String) async throws
    func updatePassword(to password: String) async throws
    func signInWithGoogle(presenting viewController: UIViewController) async throws -> FirebaseAuth.User
    func signInWithApple(nonce: String, idTokenString: String) async throws -> FirebaseAuth.User
    func createNonce() -> String
}

class FirebaseService: FirebaseAuthServiceProtocol {
    static let shared = FirebaseService()
    
    private init() {}
    
    func initialize() {
        FirebaseApp.configure()
    }
    
    func signUp(email: String, password: String) async throws -> FirebaseAuth.User {
        let authDataResult = try await Auth.auth().createUser(withEmail: email, password: password)
        return authDataResult.user
    }
    
    func signIn(email: String, password: String) async throws -> FirebaseAuth.User {
        let authDataResult = try await Auth.auth().signIn(withEmail: email, password: password)
        return authDataResult.user
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func getCurrentUser() -> FirebaseAuth.User? {
        return Auth.auth().currentUser
    }
    
    func isUserAuthenticated() -> Bool {
        return Auth.auth().currentUser != nil
    }
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        try await user.delete()
    }
    
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    func updateEmail(to email: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        
        try await user.sendEmailVerification(beforeUpdatingEmail: email)
    }
    
    func updatePassword(to password: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "FirebaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user is signed in"])
        }
        try await user.updatePassword(to: password)
    }
    
    @MainActor
    func signInWithGoogle(presenting viewController: UIViewController) async throws -> FirebaseAuth.User {
        // Get Google Sign In configuration
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "FirebaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No client ID found"])
        }
        
        // Create Google Sign In configuration object
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Start the sign in flow
        let result: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result else {
                    continuation.resume(throwing: NSError(domain: "FirebaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No result returned from Google Sign In"]))
                    return
                }
                
                continuation.resume(returning: result)
            }
        }
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "FirebaseService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No ID token returned from Google Sign In"])
        }
        
        // Create a Firebase credential with the Google ID token
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
        
        // Sign in with Firebase using the Google credential
        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user
    }
    
    @MainActor
    func signInWithApple(nonce: String, idTokenString: String) async throws -> FirebaseAuth.User {
        // Create a Firebase credential with the Apple ID token
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: nil
        )
        
        // Sign in with Firebase using the Apple credential
        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user
    }
    
    func createNonce() -> String {
        let length = 32
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
}

