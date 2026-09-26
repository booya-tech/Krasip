// WindowManager.swift
// Krasip
// Opens Krasip's windows from anywhere (menu, overlay, first launch) and shows the Dock icon while one is open.

import AppKit
import SwiftUI

enum AppWindow: String, CaseIterable {
    case settings
    case history
    case onboarding
    case benchmark
}

@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    private var windows: [AppWindow: NSWindow] = [:]
    private let makeContent: (AppWindow) -> AnyView

    init(makeContent: @escaping (AppWindow) -> AnyView) {
        self.makeContent = makeContent
    }

    func show(_ kind: AppWindow) {
        let window = windows[kind] ?? makeWindow(kind)
        windows[kind] = window
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func close(_ kind: AppWindow) {
        windows[kind]?.close()
    }

    func isVisible(_ kind: AppWindow) -> Bool {
        windows[kind]?.isVisible == true
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        let othersVisible = windows.values.contains { $0 !== closing && $0.isVisible }
        if !othersVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func makeWindow(_ kind: AppWindow) -> NSWindow {
        let hosting = NSHostingController(rootView: makeContent(kind))
        let window = NSWindow(contentViewController: hosting)
        window.title = title(for: kind)
        window.isReleasedWhenClosed = false
        window.delegate = self
        switch kind {
        case .settings:
            window.styleMask = [.titled, .closable, .miniaturizable]
        case .onboarding:
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        case .history, .benchmark:
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        }
        window.setFrameAutosaveName("Krasip.\(kind.rawValue)")
        if !window.setFrameUsingName("Krasip.\(kind.rawValue)") {
            window.center()
        }
        return window
    }

    private func title(for kind: AppWindow) -> String {
        switch kind {
        case .settings: AppString.Settings.windowTitle
        case .history: AppString.History.windowTitle
        case .onboarding: AppString.Onboarding.windowTitle
        case .benchmark: AppString.Benchmark.windowTitle
        }
    }
}
