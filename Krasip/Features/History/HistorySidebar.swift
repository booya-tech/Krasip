// HistorySidebar.swift
// Krasip
// History sidebar: quality stats, repeated-correction offers, and the list of dictations.

import SwiftUI
import KrasipCore

struct HistorySidebar: View {
    @Environment(AppController.self) private var app

    var body: some View {
        @Bindable var history = app.history
        VStack(spacing: 0) {
            QualityStatsView(stats: history.stats)
                .padding([.horizontal, .top], 12)
                .padding(.bottom, 8)
            if !history.offers.isEmpty {
                OffersBanner(offers: history.offers)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            List(selection: $history.selection) {
                ForEach(history.records) { record in
                    HistoryRow(record: record)
                        .tag(record.id)
                        .contextMenu {
                            Button(AppString.History.copy) { app.inserter.copyToClipboard(record.finalText) }
                            Button(AppString.History.delete, role: .destructive) { app.history.delete(record.id) }
                        }
                }
            }
            .overlay {
                if history.records.isEmpty {
                    ContentUnavailableView(
                        history.searchText.isEmpty ? AppString.History.emptyTitle : AppString.History.noResults,
                        systemImage: "waveform",
                        description: Text(history.searchText.isEmpty ? AppString.History.emptyMessage(app.settings.hotkey.displayString) : "")
                    )
                }
            }
        }
    }
}
