// BenchmarkModel.swift
// Krasip
// Records the Thai-English benchmark, runs each speech engine on it, and scores the results.

import AppKit
import Foundation
import Observation
import KrasipCore
import KrasipStorage
import KrasipSystem

@MainActor
@Observable
final class BenchmarkModel {
    let benchmarkSet: BenchmarkSet?
    private(set) var loadError: String?
    var selection: String?
    var categoryFilter: BenchmarkCategory?
    var selectedEngines: Set<SpeechEngine>
    /// Include the user's own glossary on top of the benchmark's rules.
    var useMyGlossary = true

    /// Sentences the user added to grow the set toward the spec's 200-utterance plan.
    private(set) var customItems: [BenchmarkItem] = []
    private(set) var recordedIDs: Set<String> = []
    private(set) var syntheticIDs: Set<String> = []
    private(set) var recordingItemID: String?
    private(set) var results: [SpeechEngine: [String: BenchmarkScore]] = [:]
    private(set) var isRunning = false
    private(set) var isGenerating = false
    private(set) var progress = 0.0
    private(set) var status: String?

    @ObservationIgnored private let recorder = MicrophoneRecorder()
    @ObservationIgnored private unowned let app: AppController
    @ObservationIgnored private var runTask: Task<Void, Never>?
    @ObservationIgnored let directory = KrasipStore.supportDirectory.appending(path: "Benchmark", directoryHint: .isDirectory)

    init(app: AppController) {
        self.app = app
        selectedEngines = [app.settings.engine]
        do {
            benchmarkSet = try BenchmarkSet.bundled()
        } catch {
            benchmarkSet = nil
            loadError = error.localizedDescription
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        loadCustomItems()
        scanRecordings()
        loadResults()
        selection = benchmarkSet?.items.first?.id
    }

    /// The shipped sentences followed by the user's own.
    var allItems: [BenchmarkItem] {
        (benchmarkSet?.items ?? []) + customItems
    }

    var items: [BenchmarkItem] {
        guard let categoryFilter else { return allItems }
        return allItems.filter { $0.category == categoryFilter }
    }

    var selectedItem: BenchmarkItem? {
        allItems.first { $0.id == selection }
    }

    var recordedCount: Int { recordedIDs.intersection(allItems.map(\.id)).count }
    var totalCount: Int { allItems.count }

    func isCustom(_ item: BenchmarkItem) -> Bool {
        customItems.contains { $0.id == item.id }
    }

    // MARK: - Your own sentences

    func addCustom(category: BenchmarkCategory, script: String, expected: String, keyTerms: [String], note: String?) {
        let number = (customItems.compactMap { Int($0.id.dropFirst()) }.max() ?? 0) + 1
        let item = BenchmarkItem(
            id: String(format: "U%03d", number),
            category: category,
            script: script.trimmingCharacters(in: .whitespacesAndNewlines),
            expected: expected.trimmingCharacters(in: .whitespacesAndNewlines),
            keyTerms: keyTerms,
            note: note
        )
        customItems.append(item)
        saveCustomItems()
        selection = item.id
    }

    func deleteCustom(_ item: BenchmarkItem) {
        customItems.removeAll { $0.id == item.id }
        try? FileManager.default.removeItem(at: recordingURL(for: item.id))
        for engine in results.keys {
            results[engine]?[item.id] = nil
        }
        saveCustomItems()
        saveResults()
        scanRecordings()
        if selection == item.id {
            selection = allItems.first?.id
        }
    }

    /// Adds sentences from a JSON file: a list of items, or a whole benchmark set.
    func importCustomItems(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let imported: [BenchmarkItem]
            if let items = try? decoder.decode([BenchmarkItem].self, from: data) {
                imported = items
            } else {
                imported = try decoder.decode(BenchmarkSet.self, from: data).items
            }
            for item in imported {
                addCustom(category: item.category, script: item.script, expected: item.expected, keyTerms: item.keyTerms, note: item.note)
            }
            status = AppString.Benchmark.imported(imported.count)
        } catch {
            status = AppString.Benchmark.importFailed(error.localizedDescription)
        }
    }

    func exportAllItems(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(allItems).write(to: url, options: .atomic)
    }

    private var customURL: URL { directory.appending(path: "custom.json") }

    private func loadCustomItems() {
        guard let data = try? Data(contentsOf: customURL) else { return }
        customItems = (try? JSONDecoder().decode([BenchmarkItem].self, from: data)) ?? []
    }

    private func saveCustomItems() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(customItems) {
            try? data.write(to: customURL, options: .atomic)
        }
    }

    func summary(for engine: SpeechEngine) -> BenchmarkSummary? {
        guard let scores = results[engine], !scores.isEmpty else { return nil }
        return BenchmarkSummary(providerID: engine.rawValue, scores: Array(scores.values))
    }

    func score(for item: BenchmarkItem, engine: SpeechEngine) -> BenchmarkScore? {
        results[engine]?[item.id]
    }

    // MARK: - Recording

    func recordingURL(for id: String) -> URL {
        directory.appending(path: "\(id).m4a")
    }

    func toggleRecording(_ item: BenchmarkItem) {
        if recordingItemID == item.id {
            stopRecording()
        } else {
            startRecording(item)
        }
    }

    private func startRecording(_ item: BenchmarkItem) {
        if recordingItemID != nil {
            recorder.cancel()
        }
        recordingItemID = item.id
        status = nil
        Task {
            do {
                try await recorder.start()
            } catch {
                recordingItemID = nil
                status = error.localizedDescription
            }
        }
    }

    private func stopRecording() {
        guard let id = recordingItemID else { return }
        Task {
            defer { recordingItemID = nil }
            do {
                let clip = try await recorder.stop()
                try AudioFileCodec.writeM4A(clip, to: recordingURL(for: id))
                syntheticIDs.remove(id)
                saveSyntheticList()
                scanRecordings()
                selectNextUnrecorded(after: id)
            } catch {
                status = error.localizedDescription
            }
        }
    }

    func play(_ item: BenchmarkItem) {
        NSSound(contentsOf: recordingURL(for: item.id), byReference: true)?.play()
    }

    func deleteRecording(_ item: BenchmarkItem) {
        try? FileManager.default.removeItem(at: recordingURL(for: item.id))
        syntheticIDs.remove(item.id)
        saveSyntheticList()
        scanRecordings()
    }

    private func selectNextUnrecorded(after id: String) {
        let items = allItems
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let next = items[(index + 1)...].first(where: { !recordedIDs.contains($0.id) }) {
            selection = next.id
        }
    }

    /// Fills missing recordings with the system Thai voice, as a smoke test only.
    func generateSyntheticRecordings() {
        let items = allItems
        guard !items.isEmpty, !isGenerating else { return }
        isGenerating = true
        status = nil
        Task {
            let missing = items.filter { !recordedIDs.contains($0.id) }
            for (index, item) in missing.enumerated() {
                progress = Double(index) / Double(max(missing.count, 1))
                do {
                    let clip = try await Self.synthesize(item.script)
                    try AudioFileCodec.writeM4A(clip, to: recordingURL(for: item.id))
                    syntheticIDs.insert(item.id)
                } catch {
                    status = error.localizedDescription
                    break
                }
            }
            saveSyntheticList()
            scanRecordings()
            progress = 0
            isGenerating = false
        }
    }

    private static func synthesize(_ text: String) async throws -> AudioClip {
        let url = FileManager.default.temporaryDirectory.appending(path: "krasip-say-\(UUID().uuidString).aiff")
        defer { try? FileManager.default.removeItem(at: url) }
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            process.arguments = ["-v", "Kanya", "-o", url.path, text]
            try process.run()
            process.waitUntilExit()
        }.value
        return try AudioFileCodec.read(url)
    }

    // MARK: - Running

    func run() {
        guard let benchmarkSet, !isRunning else { return }
        let engines = SpeechEngine.available.filter(selectedEngines.contains)
        let recorded = allItems.filter { recordedIDs.contains($0.id) }
        guard !engines.isEmpty, !recorded.isEmpty else {
            status = AppString.Benchmark.nothingToRun
            return
        }
        isRunning = true
        status = nil
        progress = 0
        let glossary = Glossary(benchmarkSet.glossary + (useMyGlossary ? app.glossary.entries : []))
        let languages = app.settings.languages
        let style = app.settings.textStyle

        runTask = Task {
            let total = Double(engines.count * recorded.count)
            var done = 0.0
            for engine in engines {
                let transcriber = TranscriberFactory.make(engine, settings: app.settings, keychain: app.keychain)
                var scores = results[engine] ?? [:]
                for item in recorded {
                    guard !Task.isCancelled else { break }
                    status = AppString.Benchmark.running(AppString.Languages.engineName(engine), item.id)
                    do {
                        let clip = try AudioFileCodec.read(recordingURL(for: item.id))
                        let started = Date()
                        let transcript = try await transcriber.transcribe(clip, languages: languages, vocabulary: glossary.vocabularyHints)
                        let final = TextPolicy().finalize(transcript.rawText, glossary: glossary, style: style)
                        scores[item.id] = BenchmarkScore.score(
                            item: item,
                            providerID: engine.rawValue,
                            rawText: transcript.rawText,
                            finalText: final.text,
                            latency: Date().timeIntervalSince(started)
                        )
                    } catch {
                        scores[item.id] = BenchmarkScore.score(item: item, providerID: engine.rawValue, rawText: "", finalText: "", latency: nil)
                        status = AppString.Benchmark.itemFailed(item.id, error.localizedDescription)
                    }
                    done += 1
                    progress = done / total
                    results[engine] = scores
                }
            }
            saveResults()
            isRunning = false
            if !Task.isCancelled {
                status = AppString.Benchmark.finished
            }
        }
    }

    func cancelRun() {
        runTask?.cancel()
        isRunning = false
        status = AppString.Benchmark.cancelled
    }

    func clearResults() {
        results = [:]
        saveResults()
    }

    // MARK: - Export

    func exportCSV(to url: URL) throws {
        var lines = ["engine,item,category,expected,raw,final,key_terms,preserved,missing,transliterated,cer,exact,latency_s,synthetic"]
        for engine in SpeechEngine.allCases {
            guard let scores = results[engine] else { continue }
            for item in allItems {
                guard let score = scores[item.id] else { continue }
                let fields: [String] = [
                    engine.rawValue, item.id, item.category.rawValue, item.expected, score.rawText, score.finalText,
                    "\(score.keyTermsTotal)", "\(score.preservedTerms.count)", score.missingTerms.joined(separator: "|"),
                    score.transliteratedTerms.joined(separator: "|"), String(format: "%.3f", score.characterErrorRate),
                    score.exactMatch ? "1" : "0", score.latency.map { String(format: "%.2f", $0) } ?? "",
                    syntheticIDs.contains(item.id) ? "1" : "0"
                ]
                lines.append(fields.map(Self.csvEscape).joined(separator: ","))
            }
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func csvEscape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    func revealFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    // MARK: - Persistence

    private var resultsURL: URL { directory.appending(path: "results.json") }
    private var syntheticURL: URL { directory.appending(path: "synthetic.json") }

    private func scanRecordings() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        recordedIDs = Set(files.filter { $0.hasSuffix(".m4a") }.map { String($0.dropLast(4)) })
        if let data = try? Data(contentsOf: syntheticURL), let ids = try? JSONDecoder().decode([String].self, from: data) {
            syntheticIDs = Set(ids).intersection(recordedIDs)
        }
    }

    private func saveSyntheticList() {
        if let data = try? JSONEncoder().encode(Array(syntheticIDs).sorted()) {
            try? data.write(to: syntheticURL, options: .atomic)
        }
    }

    private func loadResults() {
        guard let data = try? Data(contentsOf: resultsURL),
              let saved = try? JSONDecoder().decode([String: [String: BenchmarkScore]].self, from: data) else { return }
        results = Dictionary(uniqueKeysWithValues: saved.compactMap { key, value in
            SpeechEngine(rawValue: key).map { ($0, value) }
        })
    }

    private func saveResults() {
        let encodable = Dictionary(uniqueKeysWithValues: results.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(encodable) {
            try? data.write(to: resultsURL, options: .atomic)
        }
    }
}
