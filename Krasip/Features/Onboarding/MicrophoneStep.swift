// MicrophoneStep.swift
// Krasip
// Setup step 2: allow the microphone.

import SwiftUI

struct MicrophoneStep: View {
    @Environment(AppController.self) private var app

    var body: some View {
        OnboardingStepLayout(symbol: "mic.fill", title: AppString.Onboarding.microphoneTitle, message: AppString.Onboarding.microphoneMessage) {
            PermissionRow(
                title: AppString.Permissions.microphone,
                detail: AppString.Permissions.microphoneDetail,
                status: app.permissions.microphone
            ) {
                Task { await app.permissions.requestMicrophone() }
            }
            .padding(14)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
