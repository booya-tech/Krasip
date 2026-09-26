// OnboardingStepLayout.swift
// Krasip
// Shared layout for setup steps: big icon, title, plain-language explanation, then the step's controls.

import SwiftUI

struct OnboardingStepLayout<Content: View>: View {
    let symbol: String
    let title: String
    let message: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.tint)
                .frame(height: 48)
            Text(title)
                .font(.largeTitle.weight(.bold))
            Text(message)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
