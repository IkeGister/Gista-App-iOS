//
//  LaunchScreen.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/14/25.
//

//Use asset image: GisterLogo as full screen image
//OnAppear + 3 seconds Present Test APIs and Launch App Buttons - 
//Onboarding related views will use asset color: extBackgroundColor for background
//

import SwiftUI

// Protocol that defines the interface needed by LaunchScreen
protocol LaunchScreenViewModel: ObservableObject {
    func launchApp(useTestAPI: Bool)
    func bypassAuthentication() async
    
    // Add loading state
    var isLoading: Bool { get }
}

// Make OnboardingViewModel conform to LaunchScreenViewModel
extension OnboardingViewModel: LaunchScreenViewModel {}

struct LaunchScreen<ViewModel: LaunchScreenViewModel>: View {
    @EnvironmentObject private var viewModel: ViewModel
    @State private var showButtons = false
    
    var body: some View {
        ZStack {
            // Background color
            Color("extBackgroundColor")
                .ignoresSafeArea()
            
            // Logo image and name
            VStack {
                Spacer()
                
                logoView()
                appNameView()
                
                Spacer()
            }
            .padding(.bottom, 100) // Push the entire logo+text up a bit to center better
            
            // Buttons at the lower third
            buttonsView()
            
            // Loading overlay
            if viewModel.isLoading {
                loadingOverlay()
            }
        }
        .onAppear {
            // Show buttons after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showButtons = true
                }
            }
        }
    }
    
    // MARK: - Component Views
    
    @ViewBuilder
    private func logoView() -> some View {
        Image("GisterLogo")
            .resizable()
            .scaledToFit()
            .frame(width: UIScreen.main.bounds.width * 0.7)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.7), radius: 20, x: 0, y: 10)
            .shadow(color: .white.opacity(0.05), radius: 3, x: 0, y: -1)
    }
    
    @ViewBuilder
    private func appNameView() -> some View {
        Text("GISTA")
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.top, 24)
            .shadow(color: .black.opacity(0.8), radius: 5, x: 0, y: 3)
    }
    
    @ViewBuilder
    private func buttonsView() -> some View {
        VStack {
            Spacer()
            
            if showButtons {
                VStack(spacing: 12) {
                    actionButton(title: "Test APIs", color: .blue) {
                        viewModel.launchApp(useTestAPI: true)
                    }
                    
                    actionButton(title: "Launch App", color: .green) {
                        viewModel.launchApp(useTestAPI: false)
                    }
                    
                    actionButton(title: "Skip Sign Up", color: .orange) {
                        Task {
                            await viewModel.bypassAuthentication()
                        }
                    }
                }
                .padding(.bottom, 50)
                .transition(.opacity)
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.6 : 1.0)
            }
        }
    }
    
    @ViewBuilder
    private func loadingOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("Creating Test User...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(25)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.7))
            )
        }
        .transition(.opacity)
    }
    
    @ViewBuilder
    private func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 180)
                .padding(.vertical, 10)
                .background(color)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 4)
        }
    }
}

// Simple mock view model for preview
class MockLaunchScreenViewModel: LaunchScreenViewModel {
    var isLoading = false
    
    func launchApp(useTestAPI: Bool) {
        print("Launch app with useTestAPI: \(useTestAPI)")
    }
    
    func bypassAuthentication() async {
        print("Bypassing authentication")
    }
}

// Type eraser for LaunchScreen to use with OnboardingViewModel in the app
extension LaunchScreen where ViewModel == OnboardingViewModel {
    static func withOnboardingViewModel() -> some View {
        LaunchScreen<OnboardingViewModel>()
    }
}

#Preview {
    LaunchScreen<MockLaunchScreenViewModel>()
        .environmentObject(MockLaunchScreenViewModel())
}
