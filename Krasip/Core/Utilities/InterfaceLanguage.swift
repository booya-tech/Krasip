// InterfaceLanguage.swift
// Krasip
// The language Krasip's own windows are shown in, separate from the macOS system language.

import AppKit
import Foundation

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case thai = "th"

    var id: String { rawValue }

    /// macOS reads `AppleLanguages` once at launch, so a change only shows after a restart.
    private static let key = "AppleLanguages"

    private static var appDomain: [String: Any] {
        guard let bundleID = Bundle.main.bundleIdentifier else { return [:] }
        return UserDefaults.standard.persistentDomain(forName: bundleID) ?? [:]
    }

    /// What the running copy of Krasip was started with, so a new choice can offer a restart.
    static let atLaunch = current

    static var current: InterfaceLanguage {
        guard let codes = appDomain[key] as? [String], let first = codes.first else { return .system }
        return allCases.first { $0 != .system && first.hasPrefix($0.rawValue) } ?? .system
    }

    static func select(_ language: InterfaceLanguage) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: key)
        }
    }

    /// Starts a fresh copy a second after this one quits, so the two never fight over the hotkey.
    static func restart() {
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 1; open -n \"$0\"", Bundle.main.bundlePath]
        try? relaunch.run()
        NSApp.terminate(nil)
    }
}
