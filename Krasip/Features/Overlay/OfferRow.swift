// OfferRow.swift
// Krasip
// "You fixed this twice — always write it this way?" offer, shown after a repeated correction.

import SwiftUI
import KrasipCore

struct OfferRow: View {
    @Environment(AppController.self) private var app
    let offer: LearningOffer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text(AppString.Learning.offerTitle(offer.occurrences))
                    .font(.callout.weight(.semibold))
            }
            HStack(spacing: 6) {
                Text(offer.suggestion.alias)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(offer.suggestion.preferredOutput)
                    .fontWeight(.medium)
            }
            .font(.callout)
            .lineLimit(1)
            HStack(spacing: 8) {
                Button(AppString.Learning.addRule) { app.accept(offer) }
                    .buttonStyle(.borderedProminent)
                Button(AppString.Learning.notNow) { app.decline(offer, forever: false) }
                Button(AppString.Learning.never) { app.decline(offer, forever: true) }
                    .buttonStyle(.borderless)
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}
