// BenchmarkSidebar.swift
// Krasip
// Benchmark sidebar: category filter, the sentence list, and how many are recorded.

import SwiftUI
import KrasipCore

struct BenchmarkSidebar: View {
    @Bindable var model: BenchmarkModel

    var body: some View {
        VStack(spacing: 0) {
            Picker(AppString.Benchmark.category, selection: $model.categoryFilter) {
                Text(AppString.Benchmark.allCategories).tag(BenchmarkCategory?.none)
                ForEach(BenchmarkCategory.allCases) { category in
                    Text(AppString.Benchmark.categoryName(category)).tag(Optional(category))
                }
            }
            .labelsHidden()
            .padding(10)
            List(model.items, selection: $model.selection) { item in
                BenchmarkItemRow(model: model, item: item)
                    .tag(item.id)
                    .contextMenu {
                        if model.isCustom(item) {
                            Button(AppString.Benchmark.deleteSentence, role: .destructive) { model.deleteCustom(item) }
                        }
                    }
            }
            Text(AppString.Benchmark.recordedCount(model.recordedCount, model.totalCount))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
        }
    }
}
