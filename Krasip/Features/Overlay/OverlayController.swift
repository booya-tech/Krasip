// OverlayController.swift
// Krasip
// Shows, sizes, and positions the overlay panel for each dictation phase.

import AppKit
import SwiftUI
import KrasipCore

@MainActor
final class OverlayController {
    private let panel = OverlayPanel()
    private unowned let app: AppController
    private var cardSize = CGSize(width: 340, height: 72)
    private var screen: NSScreen?

    var isEditing: Bool { app.isEditingOverlay }

    init(app: AppController) {
        self.app = app
        let root = OverlayView { [weak self] size in
            self?.resize(to: size)
        }
        .environment(app)
        panel.contentView = FirstMouseHostingView(rootView: AnyView(root))
    }

    var isVisible: Bool { panel.isVisible }

    #if DEBUG
    var debugPanel: NSPanel { panel }
    #endif

    func update(for phase: FlowPhase) {
        if case .review = phase {} else {
            endEditing()
        }
        if phase == .idle {
            panel.orderOut(nil)
            screen = nil
        } else {
            if !panel.isVisible {
                screen = Self.screenUnderPointer()
            }
            place()
            panel.orderFrontRegardless()
        }
    }

    /// Lets the overlay take keyboard focus so the user can edit the text.
    func beginEditing() {
        guard !isEditing else { return }
        app.isEditingOverlay = true
        panel.allowsKey = true
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        app.refreshKeyBindings()
    }

    func endEditing() {
        guard isEditing else { return }
        app.isEditingOverlay = false
        panel.allowsKey = false
        if panel.isKeyWindow {
            panel.resignKey()
        }
        app.refreshKeyBindings()
    }

    /// Called during SwiftUI layout, so the window frame is updated on the next turn of the
    /// run loop instead of in the middle of a layout pass.
    private func resize(to size: CGSize) {
        guard size.width > 1, size.height > 1, size != cardSize else { return }
        cardSize = size
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel.isVisible else { return }
            self.place()
        }
    }

    private func place() {
        guard let visible = (screen ?? NSScreen.main)?.visibleFrame else { return }
        let origin = CGPoint(
            x: (visible.midX - cardSize.width / 2).rounded(),
            y: (visible.minY + 64).rounded()
        )
        panel.setFrame(CGRect(origin: origin, size: cardSize), display: true)
        panel.invalidateShadow()
    }

    private static func screenUnderPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
    }
}
