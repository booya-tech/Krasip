// OverlayView.swift
// Krasip
// Root of the floating overlay: shows the card for the live phase and reports its size to the panel.

import SwiftUI
import KrasipCore

struct OverlayView: View {
    @Environment(AppController.self) private var app
    let onSizeChange: (CGSize) -> Void

    var body: some View {
        OverlayCardView(phase: app.flow.phase)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                onSizeChange(size)
            }
    }
}
