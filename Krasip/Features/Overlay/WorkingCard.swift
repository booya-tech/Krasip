// WorkingCard.swift
// Krasip
// Overlay card while Krasip transcribes or inserts.

import SwiftUI

struct WorkingCard: View {
    let title: String
    let appName: String?
    let showsCancel: Bool

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                if let appName {
                    Text(AppString.Overlay.into(appName))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if showsCancel {
                KeyHint(key: "esc", label: AppString.Overlay.cancel)
            }
        }
    }
}
