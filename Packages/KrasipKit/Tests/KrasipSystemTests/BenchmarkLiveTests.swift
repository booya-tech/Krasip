// BenchmarkLiveTests.swift
// KrasipSystemTests
// Optional: runs the 50-sentence benchmark through Apple's on-device recognizer using the system Thai voice.

import Foundation
import Testing
@testable import KrasipCore
@testable import KrasipSystem

/// Runs only when KRASIP_LIVE_ASR=1 (needs macOS 26, the Thai speech model, and the "Kanya"
/// voice). The robot voice reads English words with a Thai accent, so this is a smoke test of
/// the whole pipeline and a rough baseline, not a measure of real accuracy.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["KRASIP_LIVE_ASR"] == "1"))
struct BenchmarkLiveTests {
    @Test func syntheticBenchmarkOnDevice() async throws {
        guard #available(macOS 26.0, *) else { return }
        let set = try BenchmarkSet.bundled()
        let glossary = Glossary(set.glossary)
        let transcriber = AppleOnDeviceTranscriber()
        var scores: [BenchmarkScore] = []
        var lines: [String] = []

        for item in set.items {
            let clip = try synthesize(item.script)
            let started = Date()
            let transcript = try await transcriber.transcribe(clip, languages: [.thai, .english], vocabulary: glossary.vocabularyHints)
            let final = TextPolicy().finalize(transcript.rawText, glossary: glossary)
            let score = BenchmarkScore.score(
                item: item,
                providerID: transcriber.id.rawValue,
                rawText: transcript.rawText,
                finalText: final.text,
                latency: Date().timeIntervalSince(started)
            )
            scores.append(score)
            lines.append("\(item.id)\t\(score.exactMatch ? "EXACT" : String(format: "CER %.2f", score.characterErrorRate))\tmissing: \(score.missingTerms.joined(separator: ", "))\n\tsaid:  \(item.script)\n\theard: \(transcript.rawText)\n\tfinal: \(final.text)")
        }

        let summary = BenchmarkSummary(providerID: transcriber.id.rawValue, scores: scores)
        let report = """
        Synthetic benchmark (Apple on-device, system Thai voice)
        items: \(summary.count)
        term preservation: \(summary.termPreservationRate.map { String(format: "%.0f%%", $0 * 100) } ?? "-")
        unwanted transliteration: \(summary.unwantedTransliterationRate.map { String(format: "%.0f%%", $0 * 100) } ?? "-")
        mean CER: \(summary.meanCharacterErrorRate.map { String(format: "%.0f%%", $0 * 100) } ?? "-")
        exact match: \(summary.exactMatchRate.map { String(format: "%.0f%%", $0 * 100) } ?? "-")
        median latency: \(summary.medianLatency.map { String(format: "%.2fs", $0) } ?? "-")

        \(lines.joined(separator: "\n"))
        """
        let output = ProcessInfo.processInfo.environment["KRASIP_BENCHMARK_REPORT"]
            .map(URL.init(fileURLWithPath:)) ?? FileManager.default.temporaryDirectory.appending(path: "krasip-benchmark.txt")
        try report.write(to: output, atomically: true, encoding: .utf8)
        #expect(summary.count == 50)
    }

    private func synthesize(_ text: String) throws -> AudioClip {
        let aiff = FileManager.default.temporaryDirectory.appending(path: "krasip-\(UUID().uuidString).aiff")
        defer { try? FileManager.default.removeItem(at: aiff) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = ["-v", "Kanya", "-o", aiff.path, text]
        try process.run()
        process.waitUntilExit()
        return try AudioFileCodec.read(aiff)
    }
}
