// AppRuleRow.swift
// Krasip
// One per-app rule: app icon and name, punctuation override, auto-insert toggle, remove.

import AppKit
import SwiftUI
import KrasipCore

struct AppRuleRow: View {
    @Environment(AppController.self) private var app
    let style: AppStyle

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 20, height: 20)
            Text(style.appName ?? style.bundleID)
                .lineLimit(1)
            Spacer()
            Picker(AppString.General.punctuation, selection: punctuation) {
                Text(AppString.General.punctuationDefault).tag(PunctuationMode?.none)
                ForEach(PunctuationMode.allCases) { mode in
                    Text(AppString.Languages.punctuationName(mode)).tag(Optional(mode))
                }
            }
            .labelsHidden()
            .frame(width: 170)
            Toggle(AppString.General.autoInsert, isOn: autoInsert)
                .toggleStyle(.checkbox)
            Button {
                app.appStyles.delete(style.bundleID)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help(AppString.General.removeRule)
        }
    }

    private var icon: NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: style.bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }

    private var punctuation: Binding<PunctuationMode?> {
        Binding {
            style.punctuationMode
        } set: { newValue in
            var updated = style
            updated.punctuationMode = newValue
            app.appStyles.save(updated)
        }
    }

    private var autoInsert: Binding<Bool> {
        Binding {
            style.autoInsert
        } set: { newValue in
            var updated = style
            updated.autoInsert = newValue
            app.appStyles.save(updated)
        }
    }
}
