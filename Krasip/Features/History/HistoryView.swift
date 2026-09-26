// HistoryView.swift
// Krasip
// History window: every dictation on this Mac, with details for the selected one.

import SwiftUI
import KrasipCore

struct HistoryView: View {
    @Environment(AppController.self) private var app

    var body: some View {
        @Bindable var history = app.history
        NavigationSplitView {
            HistorySidebar()
                .navigationSplitViewColumnWidth(min: 320, ideal: 360)
                .searchable(text: $history.searchText, placement: .sidebar, prompt: AppString.History.search)
        } detail: {
            if let record = history.selectedRecord {
                HistoryDetailView(record: record)
                    .id(record.id)
            } else {
                ContentUnavailableView(AppString.History.selectTitle, systemImage: "text.alignleft", description: Text(AppString.History.selectMessage))
            }
        }
        .frame(minWidth: 900, minHeight: 580)
        .onAppear {
            app.history.reload()
            if history.selection == nil {
                history.selection = history.records.first?.id
            }
        }
    }
}
