// WelcomeStep.swift
// Krasip
// Setup step 1: what Krasip does, with the hold-to-talk shortcut front and center.

import SwiftUI

struct WelcomeStep: View {
    @Environment(AppController.self) private var app

    var body: some View {
        OnboardingStepLayout(symbol: "waveform", title: AppString.Onboarding.welcomeTitle, message: AppString.Onboarding.welcomeMessage) {
            HStack(spacing: 10) {
                KeyCap(text: "⌥ option")
                Text("+")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                KeyCap(text: "space")
            }
            .padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 10) {
                Label(AppString.Onboarding.welcomePoint1, systemImage: "hand.tap")
                Label(AppString.Onboarding.welcomePoint2, systemImage: "character.bubble")
                Label(AppString.Onboarding.welcomePoint3, systemImage: "text.book.closed")
            }
            .font(.body)
        }
    }
}

private struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.tertiary))
    }
}
