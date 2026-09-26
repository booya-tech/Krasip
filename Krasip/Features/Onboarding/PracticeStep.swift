// PracticeStep.swift
// Krasip
// Setup step 5: try a real dictation into a practice box, using the primary success sentence.

import SwiftUI

struct PracticeStep: View {
    @Environment(AppController.self) private var app
    @State private var practiceText = ""
    @FocusState private var focused: Bool

    var body: some View {
        OnboardingStepLayout(symbol: "text.cursor", title: AppString.Onboarding.practiceTitle, message: AppString.Onboarding.practiceMessage(app.settings.hotkey.displayString)) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AppString.Onboarding.practiceSay)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(verbatim: "วันนี้จะต้องกลับบ้านไปทำ side project")
                    .font(.title3.weight(.medium))
                    .textSelection(.enabled)
            }
            TextEditor(text: $practiceText)
                .font(.title3)
                .focused($focused)
                .frame(height: 110)
                .padding(8)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(focused ? Color.accentColor : Color.secondary.opacity(0.3)))
            if let problem = app.hotkeyProblem {
                HStack {
                    Label(problem, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Button(AppString.Onboarding.changeShortcut) { app.showSettings(.general) }
                }
            } else if !app.permissions.isReady(for: app.settings.engine) {
                Label(AppString.Onboarding.practiceNeedsPermissions, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if practiceText.contains("side-project") {
                Label(AppString.Onboarding.practiceSuccess, systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
        }
        .onAppear { focused = true }
    }
}
