// AppRulesSection.swift
// Krasip
// Per-app rules (AppStyle): punctuation and whether to insert right away, e.g. no trailing period in Slack.

import AppKit
import SwiftUI
import KrasipCore

struct AppRulesSection: View {
    @Environment(AppController.self) private var app

    var body: some View {
        Section {
            if app.appStyles.styles.isEmpty {
                Text(AppString.General.noAppRules)
                    .foregroundStyle(.secondary)
            }
            ForEach(app.appStyles.styles) { style in
                AppRuleRow(style: style)
            }
        } header: {
            HStack {
                Text(AppString.General.appRulesSection)
                Spacer()
                Menu(AppString.General.addApp) {
                    ForEach(candidates, id: \.bundleID) { candidate in
                        Button(candidate.name) {
                            app.appStyles.save(AppStyle(bundleID: candidate.bundleID, appName: candidate.name))
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(candidates.isEmpty)
            }
        } footer: {
            Text(AppString.General.appRulesHelp)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Running apps plus apps the user dictated into, minus apps that already have a rule.
    private var candidates: [(bundleID: String, name: String)] {
        let existing = Set(app.appStyles.styles.map(\.bundleID))
        var seen = existing
        var result: [(String, String)] = []
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (String, String)? in
                guard let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return nil }
                return (id, app.localizedName ?? id)
            }
        for candidate in app.history.recentApps.map({ ($0.bundleID, $0.name) }) + running where seen.insert(candidate.0).inserted {
            result.append(candidate)
        }
        return result.sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
            .map { (bundleID: $0.0, name: $0.1) }
    }
}
