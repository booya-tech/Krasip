// Benchmark.swift
// KrasipKit
// Thai-English benchmark set and the metrics from the quality plan: term preservation, transliteration, CER.

import Foundation

public enum BenchmarkCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case acceptance
    case plainThai
    case workTerms
    case names
    case numbers
    case technical

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .acceptance: "Acceptance tests"
        case .plainThai: "Plain Thai"
        case .workTerms: "Thai + English work terms"
        case .names: "Product and person names"
        case .numbers: "Numbers, dates, times, currency"
        case .technical: "URLs, emails, code"
        }
    }
}

public struct BenchmarkItem: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var category: BenchmarkCategory
    /// What to read aloud.
    public var script: String
    /// The final text a perfect run produces.
    public var expected: String
    /// Terms that must appear exactly as written (names, English terms, numbers, URLs).
    public var keyTerms: [String]
    public var note: String?

    public init(id: String, category: BenchmarkCategory, script: String, expected: String, keyTerms: [String], note: String? = nil) {
        self.id = id
        self.category = category
        self.script = script
        self.expected = expected
        self.keyTerms = keyTerms
        self.note = note
    }
}

public struct BenchmarkSet: Codable, Sendable {
    public var name: String
    public var version: Int
    /// Glossary rules the expected outputs assume (for example side-project).
    public var glossary: [GlossaryEntry]
    public var items: [BenchmarkItem]

    public init(name: String, version: Int, glossary: [GlossaryEntry], items: [BenchmarkItem]) {
        self.name = name
        self.version = version
        self.glossary = glossary
        self.items = items
    }

    /// The Thai-English sentence set shipped with the app.
    public static func bundled() throws -> BenchmarkSet {
        guard let url = Bundle.module.url(forResource: "benchmark-th-en", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BenchmarkSet.self, from: Data(contentsOf: url))
    }
}

public struct BenchmarkScore: Codable, Equatable, Identifiable, Sendable {
    public var itemID: String
    public var providerID: String
    public var rawText: String
    public var finalText: String
    public var keyTermsTotal: Int
    public var preservedTerms: [String]
    public var missingTerms: [String]
    public var latinTermsTotal: Int
    /// English terms that came out in Thai script instead.
    public var transliteratedTerms: [String]
    public var characterErrorRate: Double
    public var exactMatch: Bool
    public var latency: TimeInterval?

    public var id: String { "\(providerID):\(itemID)" }

    public static func score(
        item: BenchmarkItem,
        providerID: String,
        rawText: String,
        finalText: String,
        latency: TimeInterval? = nil
    ) -> BenchmarkScore {
        let preserved = item.keyTerms.filter { containsTerm($0, in: finalText) }
        let missing = item.keyTerms.filter { !containsTerm($0, in: finalText) }
        let latinTerms = item.keyTerms.filter(\.containsLatin)

        let extraThai = thaiCount(finalText) - thaiCount(item.expected)
        let transliterated = extraThai >= 2
            ? missing.filter { term in term.containsLatin && finalText.range(of: term, options: .caseInsensitive) == nil }
            : []

        return BenchmarkScore(
            itemID: item.id,
            providerID: providerID,
            rawText: rawText,
            finalText: finalText,
            keyTermsTotal: item.keyTerms.count,
            preservedTerms: preserved,
            missingTerms: missing,
            latinTermsTotal: latinTerms.count,
            transliteratedTerms: transliterated,
            characterErrorRate: characterErrorRate(expected: item.expected, actual: finalText),
            exactMatch: finalText == item.expected,
            latency: latency
        )
    }

    /// Edit distance between texts with spaces removed, divided by the expected length.
    /// Thai word spacing varies between transcribers, so spaces are not counted.
    public static func characterErrorRate(expected: String, actual: String) -> Double {
        let reference = Array(expected.filter { !$0.isWhitespace })
        let hypothesis = Array(actual.filter { !$0.isWhitespace })
        guard !reference.isEmpty else { return hypothesis.isEmpty ? 0 : 1 }
        var previous = Array(0...hypothesis.count)
        var current = [Int](repeating: 0, count: hypothesis.count + 1)
        for i in 1...reference.count {
            current[0] = i
            if !hypothesis.isEmpty {
                for j in 1...hypothesis.count {
                    let cost = reference[i - 1] == hypothesis[j - 1] ? 0 : 1
                    current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                }
            }
            swap(&previous, &current)
        }
        return Double(previous[hypothesis.count]) / Double(reference.count)
    }

    /// Whole-term match: Latin terms may not be part of a longer Latin word.
    static func containsTerm(_ term: String, in text: String) -> Bool {
        var searchRange = text.startIndex..<text.endIndex
        while let found = text.range(of: term, range: searchRange) {
            let before = found.lowerBound > text.startIndex ? text[text.index(before: found.lowerBound)] : nil
            let after = found.upperBound < text.endIndex ? text[found.upperBound] : nil
            let startsWord = term.first?.isLatinOrDigit == true
            let endsWord = term.last?.isLatinOrDigit == true
            let cleanStart = !startsWord || !(before?.isLatinOrDigit ?? false)
            let cleanEnd = !endsWord || !(after?.isLatinOrDigit ?? false)
            if cleanStart && cleanEnd { return true }
            searchRange = found.upperBound..<text.endIndex
        }
        return false
    }

    private static func thaiCount(_ text: String) -> Int {
        text.unicodeScalars.filter(\.isThai).count
    }
}

public struct BenchmarkSummary: Equatable, Sendable {
    public var providerID: String
    public var count: Int
    public var termPreservationRate: Double?
    public var unwantedTransliterationRate: Double?
    public var meanCharacterErrorRate: Double?
    public var exactMatchRate: Double?
    public var medianLatency: TimeInterval?

    public init(providerID: String, scores: [BenchmarkScore]) {
        self.providerID = providerID
        count = scores.count
        let terms = scores.reduce(0) { $0 + $1.keyTermsTotal }
        let preserved = scores.reduce(0) { $0 + $1.preservedTerms.count }
        termPreservationRate = terms > 0 ? Double(preserved) / Double(terms) : nil
        let latin = scores.reduce(0) { $0 + $1.latinTermsTotal }
        let transliterated = scores.reduce(0) { $0 + $1.transliteratedTerms.count }
        unwantedTransliterationRate = latin > 0 ? Double(transliterated) / Double(latin) : nil
        meanCharacterErrorRate = scores.isEmpty ? nil : scores.reduce(0) { $0 + $1.characterErrorRate } / Double(scores.count)
        exactMatchRate = scores.isEmpty ? nil : Double(scores.filter(\.exactMatch).count) / Double(scores.count)
        let latencies = scores.compactMap(\.latency).sorted()
        medianLatency = latencies.isEmpty ? nil : latencies[latencies.count / 2]
    }
}
