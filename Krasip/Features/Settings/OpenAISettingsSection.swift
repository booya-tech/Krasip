// OpenAISettingsSection.swift
// Krasip
// API key (stored in Keychain), model, endpoint, and a connection test for cloud transcription.

import SwiftUI
import KrasipCore
import KrasipSystem

struct OpenAISettingsSection: View {
    @Environment(AppController.self) private var app
    @State private var apiKey = ""
    @State private var isTesting = false
    @State private var testResult: String?
    @State private var testSucceeded = false

    var body: some View {
        @Bindable var settings = app.settings
        Group {
            LabeledContent(AppString.Languages.apiKey) {
                HStack {
                    SecureField(AppString.Languages.apiKeyPlaceholder, text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 280)
                        .onSubmit(saveKey)
                    Button(AppString.Languages.saveKey, action: saveKey)
                        .disabled(apiKey == app.openAIKey)
                }
            }
            LabeledContent(AppString.Languages.model) {
                HStack {
                    TextField(AppString.Languages.model, text: $settings.openAIModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                    Menu {
                        ForEach(OpenAIConfiguration.suggestedModels, id: \.self) { model in
                            Button(model) { settings.openAIModel = model }
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            LabeledContent(AppString.Languages.endpoint) {
                TextField(AppString.Languages.endpoint, text: $settings.openAIBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
            }
            Toggle(isOn: $settings.openAISendsLanguageHint) {
                Text(AppString.Languages.languageHint)
                Text(AppString.Languages.languageHintHelp)
            }
            HStack {
                Button(AppString.Languages.testConnection, action: test)
                    .disabled(isTesting || (apiKey.isEmpty && !app.settings.openAIConfiguration.isLocal))
                if isTesting {
                    ProgressView()
                        .controlSize(.small)
                }
                if let testResult {
                    Label(testResult, systemImage: testSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(testSucceeded ? .green : .orange)
                        .font(.callout)
                }
            }
            Text(app.settings.openAIConfiguration.isLocal ? AppString.Languages.localServerPrivacy : AppString.Languages.openAIPrivacy)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { apiKey = app.openAIKey }
    }

    private func saveKey() {
        app.openAIKey = apiKey
        testResult = nil
    }

    private func test() {
        saveKey()
        isTesting = true
        testResult = nil
        let transcriber = OpenAITranscriber(configuration: app.settings.openAIConfiguration) { [keychain = app.keychain] in
            keychain.string(for: TranscriberFactory.openAIKeyAccount)
        }
        Task {
            let error = await transcriber.checkConnection()
            isTesting = false
            testSucceeded = error == nil
            testResult = error?.localizedDescription ?? AppString.Languages.connectionOK
        }
    }
}
