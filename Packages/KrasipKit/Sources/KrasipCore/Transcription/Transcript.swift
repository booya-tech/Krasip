// Transcript.swift
// KrasipKit
// Raw speech-recognition output: text, language spans, and confidence. Never altered by the recognizer adapter.

import Foundation

public struct LanguageSpan: Codable, Equatable, Hashable, Sendable {
    public enum Source: String, Codable, Sendable {
        /// Reported by the speech provider.
        case provider
        /// Derived from the writing system (Thai script vs Latin letters).
        case script
    }

    public var language: Language
    /// Character offsets in `rawText`.
    public var range: Range<Int>
    public var source: Source

    public init(language: Language, range: Range<Int>, source: Source) {
        self.language = language
        self.range = range
        self.source = source
    }

    /// Spans derived from script: Thai characters → Thai, Latin letters → English.
    /// Spaces, digits, and punctuation join the span around them.
    public static func byScript(_ text: String) -> [LanguageSpan] {
        var spans: [LanguageSpan] = []
        var offset = 0
        for character in text {
            let language: Language?
            switch character.scriptClass {
            case .thai: language = .thai
            case .latin: language = .english
            default: language = nil
            }
            if let language {
                if let last = spans.last, last.language == language {
                    spans[spans.count - 1].range = last.range.lowerBound..<(offset + 1)
                } else {
                    spans.append(LanguageSpan(language: language, range: offset..<(offset + 1), source: .script))
                }
            } else if let last = spans.last, last.range.upperBound == offset {
                spans[spans.count - 1].range = last.range.lowerBound..<(offset + 1)
            }
            offset += 1
        }
        return spans
    }
}

public struct Transcript: Codable, Equatable, Hashable, Sendable {
    public var rawText: String
    public var languageSpans: [LanguageSpan]
    /// 0...1, or `nil` when the provider does not report confidence.
    public var confidence: Double?
    public var providerID: String
    /// Time the provider took, for latency tracking.
    public var processingDuration: TimeInterval?

    public init(
        rawText: String,
        languageSpans: [LanguageSpan]? = nil,
        confidence: Double?,
        providerID: String,
        processingDuration: TimeInterval? = nil
    ) {
        self.rawText = rawText
        self.languageSpans = languageSpans ?? LanguageSpan.byScript(rawText)
        self.confidence = confidence.map { min(max($0, 0), 1) }
        self.providerID = providerID
        self.processingDuration = processingDuration
    }

    public func isLowConfidence(threshold: Double) -> Bool {
        guard let confidence else { return false }
        return confidence < threshold
    }
}
