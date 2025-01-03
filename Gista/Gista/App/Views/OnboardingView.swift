//
//  OnboardingView.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var navigationManager: NavigationManager
    
    var body: some View {
        VStack(spacing: 24) {
            // Logo
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
            
            // Tagline
            Text("Listen to your saved articles")
                .font(.title2)
                .fontWeight(.bold)
            
            // Illustration
            Image("OnboardingIllustration")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding()
            
            // Quick steps
            VStack(alignment: .leading, spacing: 16) {
                StepView(number: 1, text: "Share an article")
                StepView(number: 2, text: "Convert to audio")
                StepView(number: 3, text: "Listen offline anywhere")
            }
            .padding()
            
            Spacer()
            
            // Get Started Button
            Button {
                navigationManager.navigateToLibrary()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct StepView: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)
                .overlay(
                    Text("\(number)")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                )
            
            Text(text)
                .font(.body)
        }
    }
}

