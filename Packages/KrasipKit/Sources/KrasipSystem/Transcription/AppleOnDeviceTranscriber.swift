// AppleOnDeviceTranscriber.swift
// KrasipKit
// Transcription adapter for macOS 26 SpeechAnalyzer + DictationTranscriber: Thai recognized fully on this Mac.

import AVFoundation
import Speech
import KrasipCore

/// On-device Thai and English recognition. Audio never leaves the Mac. The language model is
/// downloaded once by the system (see `prepareModel`).
@available(macOS 26.0, *)
public final class AppleOnDeviceTranscriber: Transcriber {
    public let id: TranscriberID = .appleOnDevice

    public init() {}

    public enum ModelState: Equatable, Sendable {
        case unsupported
        case notInstalled
        case downloading
        case installed
    }

    public static func isSupported(_ language: Language) async -> Bool {
        await supportedLocale(for: language) != nil
    }

    public static func modelState(for language: Language) async -> ModelState {
        guard let locale = await supportedLocale(for: language) else {
            return .unsupported
        }
        switch await AssetInventory.status(forModules: [makeTranscriber(locale: locale)]) {
        case .unsupported: return .unsupported
        case .supported: return .notInstalled
        case .downloading: return .downloading
        case .installed: return .installed
        @unknown default: return .notInstalled
        }
    }

    /// Downloads the recognition model if needed. `progress` receives 0...1.
    public static func prepareModel(for language: Language, progress: (@Sendable (Double) -> Void)? = nil) async throws {
        let locale = try await requireLocale(for: language)
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [makeTranscriber(locale: locale)]) else {
            progress?(1)
            return
        }
        let observation = request.progress.observe(\.fractionCompleted, options: [.new]) { value, _ in
            progress?(value.fractionCompleted)
        }
        defer { observation.invalidate() }
        try await request.downloadAndInstall()
        progress?(1)
    }

    public func transcribe(_ audio: AudioClip, languages: [Language], vocabulary: [String]) async throws -> Transcript {
        let language = Language.primary(of: languages)
        let locale = try await Self.requireLocale(for: language)
        let transcriber = Self.makeTranscriber(locale: locale)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let url = FileManager.default.temporaryDirectory.appending(path: "krasip-\(UUID().uuidString).wav")
        try AudioFileCodec.writeWAV(audio, to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forReading: url)

        let started = Date()
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        if !vocabulary.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = Array(vocabulary.prefix(100))
            try await analyzer.setContext(context)
        }

        let collector = Task { () -> (String, Double?) in
            var text = ""
            var weightedConfidence = 0.0
            var weight = 0.0
            for try await result in transcriber.results {
                text += String(result.text.characters)
                for run in result.text.runs {
                    if let confidence = run.transcriptionConfidence {
                        let length = Double(result.text[run.range].characters.count)
                        weightedConfidence += confidence * length
                        weight += length
                    }
                }
            }
            return (text, weight > 0 ? weightedConfidence / weight : nil)
        }

        do {
            if let lastSample = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: lastSample)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            collector.cancel()
            throw TranscriptionError.unavailable(error.localizedDescription)
        }

        let (text, confidence) = try await collector.value
        return Transcript(
            rawText: text.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: confidence,
            providerID: id.rawValue,
            processingDuration: Date().timeIntervalSince(started)
        )
    }

    private static func supportedLocale(for language: Language) async -> Locale? {
        await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: language.localeIdentifier))
    }

    private static func requireLocale(for language: Language) async throws -> Locale {
        guard let locale = await supportedLocale(for: language) else {
            throw TranscriptionError.unavailable("\(language.displayName) is not supported on this Mac.")
        }
        return locale
    }

    private static func makeTranscriber(locale: Locale) -> DictationTranscriber {
        DictationTranscriber(
            locale: locale,
            contentHints: [.shortForm],
            transcriptionOptions: [.punctuation],
            reportingOptions: [],
            attributeOptions: [.transcriptionConfidence]
        )
    }
}
