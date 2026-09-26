// GeneralSettingsView.swift
// Krasip
// General tab: shortcut, review behavior, insertion, per-app rules, sounds, login, permissions.

import SwiftUI
import KrasipCore
import KrasipSystem

struct GeneralSettingsView: View {
    @Environment(AppController.self) private var app
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?
    @State private var microphones: [AudioInputDevice] = []

    var body: some View {
        @Bindable var settings = app.settings
        Form {
            Section(AppString.General.shortcutSection) {
                LabeledContent(AppString.General.shortcut) {
                    ShortcutRecorder()
                }
                if let problem = app.hotkeyProblem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Toggle(isOn: $settings.handsFreeOnQuickTap) {
                    Text(AppString.General.handsFree)
                    Text(AppString.General.handsFreeHelp(settings.hotkey.displayString))
                }
            }

            Section(AppString.General.microphoneSection) {
                Picker(AppString.General.microphone, selection: microphone) {
                    Text(AppString.General.systemDefaultMicrophone).tag(String?.none)
                    ForEach(microphones) { device in
                        Text(device.name).tag(Optional(device.uid))
                    }
                    if let saved = app.settings.inputDeviceUID, !microphones.contains(where: { $0.uid == saved }) {
                        Text(AppString.General.disconnectedMicrophone).tag(Optional(saved))
                    }
                }
            }

            Section(AppString.General.afterSpeakingSection) {
                Picker(AppString.General.whenReady, selection: $settings.reviewBeforeInsert) {
                    Text(AppString.General.insertRightAway).tag(false)
                    Text(AppString.General.alwaysReview).tag(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    LabeledContent(AppString.General.lowConfidence) {
                        Text(settings.lowConfidenceThreshold, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                    }
                    Slider(value: $settings.lowConfidenceThreshold, in: 0...0.9, step: 0.05)
                    Text(AppString.General.lowConfidenceHelp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker(AppString.General.insertionMethod, selection: $settings.insertionMode) {
                    Text(AppString.General.insertionAutomatic).tag(TextInserter.Mode.automatic)
                    Text(AppString.General.insertionPaste).tag(TextInserter.Mode.pasteOnly)
                }
            }

            AppRulesSection()

            Section(AppString.General.feedbackSection) {
                Toggle(AppString.General.playSounds, isOn: $settings.playSounds)
                Toggle(AppString.General.launchAtLogin, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LaunchAtLogin.set(enabled)
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section(AppString.General.permissionsSection) {
                PermissionRow(
                    title: AppString.Permissions.microphone,
                    detail: AppString.Permissions.microphoneDetail,
                    status: app.permissions.microphone
                ) {
                    Task { await app.permissions.requestMicrophone() }
                }
                PermissionRow(
                    title: AppString.Permissions.accessibility,
                    detail: AppString.Permissions.accessibilityDetail,
                    status: app.permissions.accessibility
                ) {
                    app.permissions.requestAccessibility()
                }
                if app.settings.engine == .appleOnline {
                    PermissionRow(
                        title: AppString.Permissions.speech,
                        detail: AppString.Permissions.speechDetail,
                        status: app.permissions.speechRecognition
                    ) {
                        Task { await app.permissions.requestSpeechRecognition() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { microphones = AudioInputDevices.all() }
    }

    private var microphone: Binding<String?> {
        Binding {
            app.settings.inputDeviceUID
        } set: { uid in
            app.setInputDevice(uid)
        }
    }
}
