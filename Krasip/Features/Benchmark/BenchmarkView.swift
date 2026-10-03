// BenchmarkView.swift
// Krasip
// Benchmark window: record the sentences, run engines, compare term preservation and transliteration.

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import KrasipCore

struct BenchmarkView: View {
    @Environment(AppController.self) private var app
    @Bindable var model: BenchmarkModel
    @State private var addingSentence = false

    var body: some View {
        NavigationSplitView {
            BenchmarkSidebar(model: model)
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BenchmarkSummaryView(model: model)
                    controls
                    if let item = model.selectedItem {
                        Divider()
                        BenchmarkItemDetail(model: model, item: item)
                    }
                }
                .padding(20)
                .frame(maxWidth: 820, alignment: .leading)
            }
        }
        .frame(minWidth: 980, minHeight: 640)
        .sheet(isPresented: $addingSentence) {
            AddBenchmarkSentenceSheet(model: model)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Text(AppString.Benchmark.engines)
                    .fontWeight(.medium)
                ForEach(SpeechEngine.available) { engine in
                    Toggle(AppString.Languages.engineName(engine), isOn: engineBinding(engine))
                        .toggleStyle(.checkbox)
                }
            }
            Toggle(AppString.Benchmark.useMyGlossary, isOn: $model.useMyGlossary)
                .toggleStyle(.checkbox)
            HStack {
                if model.isRunning {
                    Button(AppString.Benchmark.stop) { model.cancelRun() }
                } else {
                    Button(AppString.Benchmark.run) { model.run() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.recordedCount == 0 || model.selectedEngines.isEmpty)
                }
                Button(AppString.Benchmark.synthesize) { model.generateSyntheticRecordings() }
                    .disabled(model.isGenerating || model.recordedCount == model.totalCount)
                    .help(AppString.Benchmark.synthesizeHelp)
                Button(AppString.Benchmark.exportCSV, action: export)
                    .disabled(model.results.isEmpty)
                Button(AppString.Benchmark.showFolder) { model.revealFolder() }
                Spacer()
            }
            HStack {
                Button(AppString.Benchmark.addSentence) { addingSentence = true }
                Button(AppString.Benchmark.importSentences, action: importSentences)
                Button(AppString.Benchmark.exportSentences, action: exportSentences)
                Spacer()
            }
            if model.isRunning || model.isGenerating {
                ProgressView(value: model.progress)
            }
            if let status = model.status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func engineBinding(_ engine: SpeechEngine) -> Binding<Bool> {
        Binding {
            model.selectedEngines.contains(engine)
        } set: { isOn in
            if isOn {
                model.selectedEngines.insert(engine)
            } else {
                model.selectedEngines.remove(engine)
            }
        }
    }

    private func importSentences() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.importCustomItems(from: url)
    }

    private func exportSentences() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Krasip Benchmark Sentences.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? model.exportAllItems(to: url)
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "Krasip Benchmark.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? model.exportCSV(to: url)
    }
}
