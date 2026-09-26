// OnDeviceModelRow.swift
// Krasip
// Status and download button for Apple's on-device Thai speech model.

import SwiftUI
import KrasipCore

struct OnDeviceModelRow: View {
    @Environment(AppController.self) private var app

    private var language: Language { Language.primary(of: app.settings.languages) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppString.Languages.modelTitle(language))
                    .fontWeight(.medium)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            switch app.speechModel.state {
            case .notInstalled, .failed:
                Button(AppString.Languages.downloadModel) {
                    Task { await app.speechModel.download(for: language) }
                }
            case .downloading(let fraction):
                ProgressView(value: fraction)
                    .frame(width: 120)
            case .checking:
                ProgressView()
                    .controlSize(.small)
            case .installed, .unsupported:
                EmptyView()
            }
        }
    }

    private var symbol: String {
        switch app.speechModel.state {
        case .installed: "checkmark.circle.fill"
        case .unsupported, .failed: "exclamationmark.triangle.fill"
        default: "arrow.down.circle"
        }
    }

    private var tint: Color {
        switch app.speechModel.state {
        case .installed: .green
        case .unsupported, .failed: .orange
        default: .secondary
        }
    }

    private var status: String {
        switch app.speechModel.state {
        case .checking: AppString.Languages.modelChecking
        case .unsupported: AppString.Languages.modelUnsupported
        case .notInstalled: AppString.Languages.modelNotInstalled
        case .downloading(let fraction): AppString.Languages.modelDownloading(fraction)
        case .installed: AppString.Languages.modelInstalled
        case .failed(let message): message
        }
    }
}
