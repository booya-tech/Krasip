// PrivacySettingsView.swift
// Krasip
// Privacy tab: local text history, opt-in audio, retention, deletion, and where your voice goes.

import AppKit
import SwiftUI
import KrasipStorage

struct PrivacySettingsView: View {
    @Environment(AppController.self) private var app
    @State private var confirmingDeleteAll = false
    @State private var audioBytes: Int64 = 0

    private var staysOnMac: Bool {
        app.settings.engine == .appleOnDevice || (app.settings.engine == .openAI && app.settings.openAIConfiguration.isLocal)
    }

    var body: some View {
        @Bindable var settings = app.settings
        Form {
            Section {
                Toggle(isOn: $settings.saveHistory) {
                    Text(AppString.Privacy.saveHistory)
                    Text(AppString.Privacy.saveHistoryHelp)
                }
                Picker(AppString.Privacy.keepFor, selection: $settings.retention) {
                    ForEach(HistoryRetention.allCases) { retention in
                        Text(AppString.Privacy.retentionName(retention)).tag(retention)
                    }
                }
                .onChange(of: settings.retention) { _, retention in
                    app.history.enforceRetention(retention)
                }
                LabeledContent(AppString.Privacy.savedDictations) {
                    Text("\(app.history.stats.dictationCount)")
                        .monospacedDigit()
                }
                Button(AppString.Privacy.deleteAllHistory, role: .destructive) {
                    confirmingDeleteAll = true
                }
                .disabled(app.history.stats.dictationCount == 0)
            } header: {
                Text(AppString.Privacy.historySection)
            }

            Section {
                Toggle(isOn: $settings.keepAudio) {
                    Text(AppString.Privacy.keepAudio)
                    Text(AppString.Privacy.keepAudioHelp)
                }
                LabeledContent(AppString.Privacy.savedAudio) {
                    Text(ByteCountFormatter.string(fromByteCount: audioBytes, countStyle: .file))
                        .monospacedDigit()
                }
                Button(AppString.Privacy.deleteAudio, role: .destructive) {
                    app.history.deleteAllAudio()
                    audioBytes = app.audioArchive.totalSize
                }
                .disabled(audioBytes == 0)
            } header: {
                Text(AppString.Privacy.audioSection)
            }

            Section(AppString.Privacy.whereSection) {
                Label(AppString.Privacy.engineStatement(app.settings.engine, localServer: app.settings.openAIConfiguration.isLocal), systemImage: staysOnMac ? "lock.laptopcomputer" : "icloud")
                Label(AppString.Privacy.noRewriting, systemImage: "text.badge.checkmark")
                Label(AppString.Privacy.noPasswords, systemImage: "lock.shield")
                Label(AppString.Privacy.localStorage, systemImage: "internaldrive")
                Button(AppString.Privacy.showData) {
                    NSWorkspace.shared.activateFileViewerSelecting([KrasipStore.supportDirectory])
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { audioBytes = app.audioArchive.totalSize }
        .confirmationDialog(AppString.Privacy.deleteAllTitle, isPresented: $confirmingDeleteAll) {
            Button(AppString.Privacy.deleteAllConfirm, role: .destructive) {
                app.history.deleteAll()
                audioBytes = app.audioArchive.totalSize
            }
        } message: {
            Text(AppString.Privacy.deleteAllMessage)
        }
    }
}
