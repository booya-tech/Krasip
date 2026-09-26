// HistoryTypes.swift
// KrasipKit
// Records shared by the history module and its callers: dictations, corrections, learned offers, and quality stats.

import Foundation

public struct DictationRecord: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var rawText: String
    /// Current final text. Starts as the text policy output and changes with corrections.
    public var finalText: String
    /// What the text policy produced before any user correction.
    public var policyText: String
    public var destinationBundleID: String?
    public var destinationAppName: String?
    public var confidence: Double?
    public var providerID: String
    public var audioDuration: TimeInterval
    /// Hotkey release to inserted text.
    public var latency: TimeInterval?
    public var insertion: InsertionResult?
    public var changes: [TextChange]
    /// Saved only when the user turned on "Keep audio for retry".
    public var audioPath: String?
    public var wordCount: Int
    public var correctionCount: Int

    public init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        rawText: String,
        finalText: String,
        policyText: String? = nil,
        destinationBundleID: String? = nil,
        destinationAppName: String? = nil,
        confidence: Double? = nil,
        providerID: String = "",
        audioDuration: TimeInterval = 0,
        latency: TimeInterval? = nil,
        insertion: InsertionResult? = nil,
        changes: [TextChange] = [],
        audioPath: String? = nil,
        wordCount: Int? = nil,
        correctionCount: Int = 0
    ) {
        self.id = id
        self.startedAt = startedAt
        self.rawText = rawText
        self.finalText = finalText
        self.policyText = policyText ?? finalText
        self.destinationBundleID = destinationBundleID
        self.destinationAppName = destinationAppName
        self.confidence = confidence
        self.providerID = providerID
        self.audioDuration = audioDuration
        self.latency = latency
        self.insertion = insertion
        self.changes = changes
        self.audioPath = audioPath
        self.wordCount = wordCount ?? WordSegmenter.wordCount(finalText)
        self.correctionCount = correctionCount
    }

    public var wasCorrected: Bool { correctionCount > 0 }
}

public struct Correction: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var dictationID: UUID
    public var beforeText: String
    public var afterText: String
    /// True once the user turned this correction into a glossary rule.
    public var acceptedSuggestion: Bool
    public var createdAt: Date
    /// Words touched by the edit, for the correction-rate metric.
    public var changedWordCount: Int

    public init(
        id: UUID = UUID(),
        dictationID: UUID,
        beforeText: String,
        afterText: String,
        acceptedSuggestion: Bool = false,
        createdAt: Date = .now,
        changedWordCount: Int? = nil
    ) {
        self.id = id
        self.dictationID = dictationID
        self.beforeText = beforeText
        self.afterText = afterText
        self.acceptedSuggestion = acceptedSuggestion
        self.createdAt = createdAt
        self.changedWordCount = changedWordCount ?? Self.changedWords(from: beforeText, to: afterText)
    }

    public static func changedWords(from before: String, to after: String) -> Int {
        let old = Array(before)
        let new = Array(after)
        return TextDiff.wordHunks(from: before, to: after).reduce(0) { total, hunk in
            let removed = WordSegmenter.wordCount(String(old[hunk.before]))
            let added = WordSegmenter.wordCount(String(new[hunk.after]))
            return total + max(removed, added, 1)
        }
    }
}

/// A correction the user has now made repeatedly, offered as a glossary rule.
public struct LearningOffer: Identifiable, Equatable, Sendable {
    public var suggestion: Suggestion
    public var occurrences: Int
    public var correctionID: UUID

    public init(suggestion: Suggestion, occurrences: Int, correctionID: UUID) {
        self.suggestion = suggestion
        self.occurrences = occurrences
        self.correctionID = correctionID
    }

    public var id: String { suggestion.key }
}

public struct CorrectionOutcome: Equatable, Sendable {
    public var correction: Correction
    /// Every candidate rule found in this correction.
    public var suggestions: [Suggestion]
    /// Candidates seen in enough corrections to offer, and not already in the glossary.
    public var offers: [LearningOffer]

    public init(correction: Correction, suggestions: [Suggestion], offers: [LearningOffer]) {
        self.correction = correction
        self.suggestions = suggestions
        self.offers = offers
    }
}

/// The spec's quality metrics that can be measured from everyday use.
public struct QualityStats: Equatable, Sendable {
    public var dictationCount: Int
    public var insertionAttempts: Int
    public var insertionSuccesses: Int
    public var dictatedWords: Int
    public var correctedWords: Int
    public var latencies: [TimeInterval]

    public init(
        dictationCount: Int = 0,
        insertionAttempts: Int = 0,
        insertionSuccesses: Int = 0,
        dictatedWords: Int = 0,
        correctedWords: Int = 0,
        latencies: [TimeInterval] = []
    ) {
        self.dictationCount = dictationCount
        self.insertionAttempts = insertionAttempts
        self.insertionSuccesses = insertionSuccesses
        self.dictatedWords = dictatedWords
        self.correctedWords = correctedWords
        self.latencies = latencies
    }

    /// Successful focused-field insertions / attempts.
    public var insertionSuccessRate: Double? {
        insertionAttempts > 0 ? Double(insertionSuccesses) / Double(insertionAttempts) : nil
    }

    /// User-edited words / dictated words.
    public var correctionRate: Double? {
        dictatedWords > 0 ? Double(correctedWords) / Double(dictatedWords) : nil
    }

    public var medianLatency: TimeInterval? { percentile(0.5) }
    public var p90Latency: TimeInterval? { percentile(0.9) }

    private func percentile(_ fraction: Double) -> TimeInterval? {
        guard !latencies.isEmpty else { return nil }
        let sorted = latencies.sorted()
        let index = min(Int((Double(sorted.count - 1) * fraction).rounded()), sorted.count - 1)
        return sorted[index]
    }
}
