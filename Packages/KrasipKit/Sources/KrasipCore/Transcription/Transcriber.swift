// Transcriber.swift
// KrasipKit
// The transcription module seam: audio in, raw transcript out. Each provider is one adapter.

import Foundation

/// Identifies a speech-recognition provider.
public struct TranscriberID: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let appleOnDevice = TranscriberID(rawValue: "apple.ondevice")
    public static let appleServer = TranscriberID(rawValue: "apple.server")
    public static let openAI = TranscriberID(rawValue: "openai")
    public static let fixture = TranscriberID(rawValue: "fixture")

    public var description: String { rawValue }
}

public protocol Transcriber: Sendable {
    var id: TranscriberID { get }

    /// Raw text exactly as the provider heard it. Adapters must not respell or clean it up;
    /// that is the text policy's job. `vocabulary` holds optional spelling hints.
    func transcribe(_ audio: AudioClip, languages: [Language], vocabulary: [String]) async throws -> Transcript
}

extension Transcriber {
    public func transcribe(_ audio: AudioClip, languages: [Language]) async throws -> Transcript {
        try await transcribe(audio, languages: languages, vocabulary: [])
    }
}

public enum TranscriptionError: Error, Equatable, Sendable, LocalizedError {
    case notAuthorized
    case unavailable(String)
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case network(String)
    case provider(status: Int, message: String)
    case timedOut
    case noSpeech

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            String(localized: "Speech recognition is not allowed. Turn it on in System Settings → Privacy & Security → Speech Recognition.", bundle: .module)
        case .unavailable(let reason):
            String(localized: "Speech recognition is unavailable: \(reason)", bundle: .module)
        case .missingAPIKey:
            String(localized: "Add your API key in Krasip Settings → Languages.", bundle: .module)
        case .invalidAPIKey:
            String(localized: "The API key was rejected. Check it in Krasip Settings → Languages.", bundle: .module)
        case .rateLimited:
            String(localized: "The speech service is busy or your quota is used up. Try again in a moment.", bundle: .module)
        case .network(let message):
            String(localized: "Could not reach the speech service: \(message)", bundle: .module)
        case .provider(let status, let message):
            String(localized: "The speech service returned an error (\(String(status))): \(message)", bundle: .module)
        case .timedOut:
            String(localized: "Transcription took too long.", bundle: .module)
        case .noSpeech:
            String(localized: "No speech was detected.", bundle: .module)
        }
    }
}

/// Returns fixed text. Used by tests, previews, and the "display a fake transcript" spike.
public struct FixtureTranscriber: Transcriber {
    public var id: TranscriberID { .fixture }
    public var text: String
    public var confidence: Double?
    public var delay: Duration

    public init(text: String, confidence: Double? = 0.95, delay: Duration = .zero) {
        self.text = text
        self.confidence = confidence
        self.delay = delay
    }

    public func transcribe(_ audio: AudioClip, languages: [Language], vocabulary: [String]) async throws -> Transcript {
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        return Transcript(rawText: text, confidence: confidence, providerID: id.rawValue)
    }
}
