// MenuBarLabel.swift
// Krasip
// Menu bar icon that reflects the dictation state.

import SwiftUI

struct MenuBarLabel: View {
    @Environment(AppController.self) private var app

    var body: some View {
        Image(systemName: app.menuBarSymbol)
            .accessibilityLabel(AppString.Menu.iconLabel)
    }
}
