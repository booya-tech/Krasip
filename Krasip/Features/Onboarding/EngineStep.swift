// EngineStep.swift
// Krasip
// Setup step 4: choose how speech becomes text, and prepare that engine.

import SwiftUI
import KrasipCore

struct EngineStep: View {
    @Environment(AppController.self) private var app

    var body: some View {
        @Bindable var settings = app.settings
        OnboardingStepLayout(symbol: "character.bubble", title: AppString.Onboarding.engineTitle, message: AppString.Onboarding.engineMessage) {
            Picker(AppString.Languages.engine, selection: $settings.engine) {
                ForEach(SpeechEngine.available) { engine in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppString.Languages.engineName(engine))
                            .fontWeight(.medium)
                        Text(AppString.Languages.engineSummary(engine))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(engine)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Group {
                switch settings.engine {
                case .appleOnDevice:
                    OnDeviceModelRow()
                case .appleOnline:
                    PermissionRow(
                        title: AppString.Permissions.speech,
                        detail: AppString.Permissions.speechDetail,
                        status: app.permissions.speechRecognition
                    ) {
                        Task { await app.permissions.requestSpeechRecognition() }
                    }
                case .openAI:
                    Form {
                        OpenAISettingsSection()
                    }
                    .formStyle(.grouped)
                    .frame(maxHeight: 250)
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        }
        .task {
            await app.speechModel.refresh(for: Language.primary(of: app.settings.languages))
        }
    }
}
