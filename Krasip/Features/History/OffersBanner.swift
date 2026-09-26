// OffersBanner.swift
// Krasip
// Corrections you have repeated, offered as glossary rules you can add with one click.

import SwiftUI
import KrasipCore

struct OffersBanner: View {
    @Environment(AppController.self) private var app
    let offers: [LearningOffer]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(AppString.Learning.bannerTitle, systemImage: "sparkles")
                .font(.callout.weight(.semibold))
            ForEach(offers.prefix(3)) { offer in
                HStack(spacing: 6) {
                    Text(offer.suggestion.alias)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                    Text(offer.suggestion.preferredOutput)
                        .fontWeight(.medium)
                    Text(AppString.Learning.times(offer.occurrences))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 4)
                    Button(AppString.Learning.addRule) {
                        app.glossary.apply(offer.suggestion)
                        app.history.markAccepted(offer)
                    }
                    .controlSize(.small)
                    Button {
                        app.history.dismiss(offer)
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .help(AppString.Learning.never)
                }
                .font(.callout)
                .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
