// AccessibilityStep.swift
// Krasip
// Setup step 3: allow Accessibility so Krasip can type into other apps, with plain instructions.

import SwiftUI

struct AccessibilityStep: View {
    @Environment(AppController.self) private var app

    var body: some View {
        OnboardingStepLayout(symbol: "keyboard.badge.ellipsis", title: AppString.Onboarding.accessibilityTitle, message: AppString.Onboarding.accessibilityMessage) {
            PermissionRow(
                title: AppString.Permissions.accessibility,
                detail: AppString.Permissions.accessibilityDetail,
                status: app.permissions.accessibility
            ) {
                app.permissions.requestAccessibility()
            }
            .padding(14)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))

            if app.permissions.accessibility != .granted {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppString.Onboarding.accessibilityStepsTitle)
                        .font(.headline)
                    Text(AppString.Onboarding.accessibilitySteps)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Label(AppString.Onboarding.accessibilityDone, systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}
