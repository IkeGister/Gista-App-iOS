//
//  OnboardingView.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

// Protocol that defines the interface needed by OnboardingView
protocol OnboardingViewModelProtocol: ObservableObject {
    // Published properties
    var email: String { get set }
    var password: String { get set }
    var confirmPassword: String { get set }
    var username: String { get set }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var showError: Bool { get set }
    var currentStep: OnboardingStep { get }
    
    // Methods
    func nextStep()
    func previousStep()
    func goToSignIn()
    func goToSignUp()
    func signInWithGoogle(presenting rootViewController: UIViewController) async
    func prepareForAppleSignIn() -> String
    func signInWithApple(idTokenString: String, fullName: PersonNameComponents?) async
    func setError(_ message: String)
}

// Make OnboardingViewModel conform to OnboardingViewModelProtocol
extension OnboardingViewModel: OnboardingViewModelProtocol {}

struct OnboardingView<ViewModel: OnboardingViewModelProtocol>: View {
    @EnvironmentObject private var viewModel: ViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color("extBackgroundColor")
                    .ignoresSafeArea()
                
                // Content
                VStack {
                    switch viewModel.currentStep {
                    case .welcome:
                        WelcomeView<ViewModel>()
                            .environmentObject(viewModel)
                    case .signup:
                        SignUpView<ViewModel>()
                            .environmentObject(viewModel)
                    case .signIn:
                        SignInView<ViewModel>()
                            .environmentObject(viewModel)
                    case .complete:
                        CompletionView<ViewModel>()
                            .environmentObject(viewModel)
                    }
                }
            }
            .alert(isPresented: $viewModel.showError) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        ProgressView()
                            .scaleEffect(1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: 100, height: 100)
                            )
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// Type eraser for OnboardingView to use with OnboardingViewModel in the app
extension OnboardingView where ViewModel == OnboardingViewModel {
    static func withOnboardingViewModel() -> some View {
        OnboardingView<OnboardingViewModel>()
    }
}

// MARK: - Welcome View
struct WelcomeView<ViewModel: OnboardingViewModelProtocol>: View {
    @EnvironmentObject private var viewModel: ViewModel
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)
                
                // Logo - smaller version
                Image("GisterLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width * 0.45)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.7), radius: 20, x: 0, y: 10)
                    .shadow(color: .white.opacity(0.05), radius: 3, x: 0, y: -1)
                
                // App Name
                Text("GISTA")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 5)
                    .shadow(color: .black.opacity(0.8), radius: 5, x: 0, y: 3)
                
                // Social Sign In Buttons
                VStack(spacing: 14) {
                    // Apple Sign In Button
                    AppleSignInButton<ViewModel>()
                        .environmentObject(viewModel)
                        .frame(height: 42)
                    
                    // Google Sign In Button
                    Button(action: {
                        Task {
                            if let rootViewController = getRootViewController() {
                                await viewModel.signInWithGoogle(presenting: rootViewController)
                            } else {
                                viewModel.setError("Could not find root view controller")
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            // Google Logo
                            Image("googleLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            
                            Text("Sign in with Google")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 15)
                
                // Divider with "OR" text
                HStack {
                    VStack { Divider().background(Color.white.opacity(0.5)) }.padding(.horizontal, 20)
                    Text("OR")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    VStack { Divider().background(Color.white.opacity(0.5)) }.padding(.horizontal, 20)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 40)
                
                // Email/Password Fields
                VStack(spacing: 14) {
                    // Username field
                    TextField("", text: $viewModel.username)
                        .placeholder(when: viewModel.username.isEmpty) {
                            Text("username").foregroundColor(Color.gray.opacity(0.7))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Email field
                    TextField("", text: $viewModel.email)
                        .placeholder(when: viewModel.email.isEmpty) {
                            Text("email").foregroundColor(Color.gray.opacity(0.7))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Password field
                    SecureField("", text: $viewModel.password)
                        .placeholder(when: viewModel.password.isEmpty) {
                            Text("Password").foregroundColor(Color.gray.opacity(0.7))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Sign In Button
                    Button(action: {
                        viewModel.nextStep()
                    }) {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.7))
                            )
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .padding(.top, 5)
                }
                .padding(.horizontal, 40)
                
                // Create Account Button
                Button(action: {
                    viewModel.goToSignUp()
                }) {
                    Text("Create New Account")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 15)
                }
                
                Spacer()
            }
            .padding(.bottom, 30)
        }
    }
}

// Extension for placeholder text
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Sign Up View
struct SignUpView<ViewModel: OnboardingViewModelProtocol>: View {
    @EnvironmentObject private var viewModel: ViewModel
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 25) {
                // Header
                Text("Create Account")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                
                // Logo - smaller version
                Image("GisterLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width * 0.25)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                
                // Form Fields
                VStack(spacing: 14) {
                    // Username field
                    TextField("", text: $viewModel.username)
                        .placeholder(when: viewModel.username.isEmpty) {
                            Text("Username").foregroundColor(Color.gray.opacity(0.7))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Email field
                    TextField("", text: $viewModel.email)
                        .placeholder(when: viewModel.email.isEmpty) {
                            Text("email").foregroundColor(Color.gray.opacity(0.7))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Password field
                    SecureField("", text: $viewModel.password)
                        .placeholder(when: viewModel.password.isEmpty) {
                            Text("Password").foregroundColor(Color.gray.opacity(0.7))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Confirm Password field
                    SecureField("", text: $viewModel.confirmPassword)
                        .placeholder(when: viewModel.confirmPassword.isEmpty) {
                            Text("Confirm Password").foregroundColor(Color.gray.opacity(0.7))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 40)
                
                // Buttons
                VStack(spacing: 14) {
                    // Create Account Button
                    Button(action: {
                        viewModel.nextStep()
                    }) {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.7))
                            )
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    
                    // Back Button
                    Button(action: {
                        viewModel.previousStep()
                    }) {
                        Text("Back")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)
                
                Spacer()
            }
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Sign In View
struct SignInView<ViewModel: OnboardingViewModelProtocol>: View {
    @EnvironmentObject private var viewModel: ViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 25) {
                // Header
                Text("Sign In")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                
                // Logo - smaller version
                Image("GisterLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width * 0.25)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                
                // Social Sign In Buttons
                VStack(spacing: 14) {
                    // Apple Sign In Button
                    AppleSignInButton<ViewModel>()
                        .environmentObject(viewModel)
                        .frame(height: 42)
                    
                    // Google Sign In Button
                    Button(action: {
                        Task {
                            if let rootViewController = getRootViewController() {
                                await viewModel.signInWithGoogle(presenting: rootViewController)
                            } else {
                                viewModel.setError("Could not find root view controller")
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            // Google Logo
                            Image("googleLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            
                            Text("Sign in with Google")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)
                
                // Divider with "OR" text
                HStack {
                    VStack { Divider().background(Color.white.opacity(0.5)) }.padding(.horizontal, 20)
                    Text("OR")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    VStack { Divider().background(Color.white.opacity(0.5)) }.padding(.horizontal, 20)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 40)
                
                // Email/Password Fields
                VStack(spacing: 14) {
                    // Email field
                    TextField("", text: $viewModel.email)
                        .placeholder(when: viewModel.email.isEmpty) {
                            Text("email").foregroundColor(Color.gray.opacity(0.7))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Password field
                    SecureField("", text: $viewModel.password)
                        .placeholder(when: viewModel.password.isEmpty) {
                            Text("Password").foregroundColor(Color.gray.opacity(0.7))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Sign In Button
                    Button(action: {
                        viewModel.nextStep()
                    }) {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.7))
                            )
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .padding(.top, 5)
                }
                .padding(.horizontal, 40)
                
                // Create Account Button
                Button(action: {
                    viewModel.goToSignUp()
                }) {
                    Text("Create New Account")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 15)
                }
                
                // Back Button
                Button(action: {
                    viewModel.previousStep()
                }) {
                    Text("Back")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 5)
                }
                
                Spacer()
            }
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Completion View
struct CompletionView<ViewModel: OnboardingViewModelProtocol>: View {
    @EnvironmentObject private var viewModel: ViewModel
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 25) {
                Spacer().frame(height: 20)
                
                // Success Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 100, height: 100)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .foregroundColor(.green)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                
                // Welcome Text
                Text("Welcome to Gista!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                
                // Success Message
                Text("You're all set up and ready to go.")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Get Started Button
                Button(action: {
                    // This will trigger the app to show the main content view
                    viewModel.nextStep()
                }) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.7))
                        )
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                Spacer()
            }
            .padding(.bottom, 30)
        }
    }
}

// Mock view model for preview
class MockOnboardingViewModel: OnboardingViewModelProtocol {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var username: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showError: Bool = false
    @Published var currentStep: OnboardingStep = .welcome
    
    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .signup
        case .signup:
            currentStep = .signIn
        case .signIn:
            currentStep = .complete
        case .complete:
            print("Completed onboarding")
        }
    }
    
    func previousStep() {
        switch currentStep {
        case .signup, .signIn:
            currentStep = .welcome
        case .complete:
            currentStep = .signIn
        default:
            break
        }
    }
    
    func goToSignIn() {
        currentStep = .signIn
    }
    
    func goToSignUp() {
        currentStep = .signup
    }
    
    func signInWithGoogle(presenting rootViewController: UIViewController) async {
        print("Mock sign in with Google")
    }
    
    func prepareForAppleSignIn() -> String {
        // Mock implementation that returns a dummy nonce
        return "mock_nonce_for_apple_sign_in_123456789"
    }
    
    func signInWithApple(idTokenString: String, fullName: PersonNameComponents?) async {
        print("Mock sign in with Apple using token: \(idTokenString)")
        // Simulate successful sign-in
        self.currentStep = .complete
    }
    
    func setError(_ message: String) {
        self.errorMessage = message
        self.showError = true
    }
}

// Preview helpers
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = MockOnboardingViewModel()
        OnboardingView<MockOnboardingViewModel>()
            .environmentObject(mockViewModel)
    }
}

// Helper function to get root view controller
@MainActor
private func getRootViewController() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootViewController = windowScene.windows.first?.rootViewController else {
        return nil
    }
    return rootViewController
}
