// KrasipApp.swift
// Krasip
// App entry point: a menu bar utility. Windows are opened by WindowManager.

import SwiftUI

@main
struct KrasipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environment(appDelegate.controller)
        } label: {
            MenuBarLabel()
                .environment(appDelegate.controller)
        }
        .menuBarExtraStyle(.menu)
    }
}
