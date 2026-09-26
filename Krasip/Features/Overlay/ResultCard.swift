// ResultCard.swift
// Krasip
// Overlay card after a dictation: where the text went, the text itself, what changed, and learning offers.

import SwiftUI
import KrasipCore

struct ResultCard: View {
    @Environment(AppController.self) private var app
    let finished: FlowPhase.Finished

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button {
                    app.inserter.copyToClipboard(finished.text)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help(AppString.Overlay.copy)
            }

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(finished.text)
                .font(.system(size: 15))
                .lineLimit(5)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            ChangeList(changes: finished.changes, limit: 3)

            ForEach(finished.offers) { offer in
                OfferRow(offer: offer)
            }

            if needsAccessibility {
                Button(AppString.Overlay.turnOnAccessibility) {
                    app.permissions.requestAccessibility()
                }
                .controlSize(.small)
            }
        }
        .onHover { hovering in
            if hovering {
                app.flow.holdResult()
            } else {
                app.flow.releaseResult()
            }
        }
    }

    private var needsAccessibility: Bool {
        finished.result == .copiedToClipboard(.accessibilityNotTrusted)
    }

    private var symbol: String {
        switch finished.result {
        case .inserted: "checkmark.circle.fill"
        case .copiedToClipboard(.secureField): "lock.fill"
        case .copiedToClipboard: "doc.on.clipboard.fill"
        case .cancelled: "xmark.circle"
        }
    }

    private var tint: Color {
        switch finished.result {
        case .inserted: .green
        case .copiedToClipboard(.userChoseCopy): .green
        default: .orange
        }
    }

    private var title: String {
        switch finished.result {
        case .inserted(.pasteUnconfirmed): AppString.Overlay.pastedUnconfirmed(finished.appName)
        case .inserted: AppString.Overlay.inserted(finished.appName)
        case .copiedToClipboard(.userChoseCopy): AppString.Overlay.copied
        case .copiedToClipboard: AppString.Overlay.copiedFallback
        case .cancelled: AppString.Overlay.cancelled
        }
    }

    private var detail: String? {
        switch finished.result {
        case .copiedToClipboard(.secureField): AppString.Overlay.secureFieldDetail
        case .copiedToClipboard(.accessibilityNotTrusted): AppString.Overlay.accessibilityDetail
        case .copiedToClipboard(.noFocusedField): AppString.Overlay.noFieldDetail
        case .copiedToClipboard(.appRejected): AppString.Overlay.appRejectedDetail
        case .inserted(.pasteUnconfirmed): AppString.Overlay.unconfirmedDetail
        default: nil
        }
    }
}
