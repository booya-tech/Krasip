// Glossary.swift
// KrasipKit
// The glossary module: resolves saved aliases in text and learns new rules from user corrections.

import Foundation

/// A proposed glossary rule learned from a correction. It is never applied without the user.
public struct Suggestion: Equatable, Hashable, Identifiable, Sendable {
    public enum Kind: Equatable, Hashable, Sendable {
        /// No entry produces this spelling yet.
        case newEntry
        /// An entry already produces this spelling; add the alias to it.
        case addAlias(entryID: UUID)
        /// An entry already knows this alias but is not locked.
        case lockEntry(entryID: UUID)
    }

    public var alias: String
    public var preferredOutput: String
    public var kind: Kind

    public init(alias: String, preferredOutput: String, kind: Kind) {
        self.alias = alias
        self.preferredOutput = preferredOutput
        self.kind = kind
    }

    /// Stable identity used to detect the same correction repeated across dictations.
    public var key: String { Self.key(alias: alias, preferredOutput: preferredOutput) }
    public var id: String { key }

    public static func key(alias: String, preferredOutput: String) -> String {
        MatchText.keyString(alias) + "\u{2192}" + preferredOutput
    }
}

public struct Glossary: Equatable, Sendable {
    public var entries: [GlossaryEntry]

    public init(_ entries: [GlossaryEntry] = []) {
        self.entries = entries
    }

    /// Every alias found in `text`, locked and suggest entries only, ordered by position.
    public func resolve(_ text: String) -> [Replacement] {
        GlossaryMatcher(entries: entries).matches(in: text)
    }

    /// The most useful rule a correction teaches, if any.
    public func learn(raw: String, corrected: String) -> Suggestion? {
        learnAll(before: raw, after: corrected).first
    }

    /// Every small word-level change between two versions, as candidate glossary rules.
    /// Whole-sentence rewrites are ignored: they are edits, not vocabulary.
    public func learnAll(before: String, after: String) -> [Suggestion] {
        let old = Array(before)
        let new = Array(after)
        let hunks = TextDiff.wordHunks(from: before, to: after)
        guard !hunks.isEmpty, hunks.count <= 4 else { return [] }

        let changedCharacters = hunks.reduce(0) { $0 + $1.before.count }
        if WordSegmenter.wordCount(before) >= 4, Double(changedCharacters) >= Double(old.count) * 0.9 {
            return []
        }

        var suggestions: [Suggestion] = []
        var seen = Set<String>()
        for hunk in hunks {
            let alias = String(old[hunk.before]).trimmed
            let output = String(new[hunk.after]).trimmed
            guard !alias.isEmpty, !output.isEmpty, alias != output,
                  alias.count <= 40, output.count <= 60,
                  alias.contains(where: { $0.isLetter || $0.isNumber }),
                  WordSegmenter.wordCount(alias) <= 5 else { continue }

            let suggestion = Suggestion(alias: alias, preferredOutput: output, kind: kind(alias: alias, output: output))
            if seen.insert(suggestion.key).inserted {
                suggestions.append(suggestion)
            }
        }
        return suggestions
    }

    /// Whether a saved, locked rule already turns `alias` into `preferredOutput`.
    public func alreadyKnows(_ suggestion: Suggestion) -> Bool {
        entries.contains { $0.mode == .locked && $0.turns(suggestion.alias, into: suggestion.preferredOutput) }
    }

    /// Latin spellings the user cares about, offered to speech recognizers as vocabulary hints.
    public var vocabularyHints: [String] {
        var seen = Set<String>()
        var hints: [String] = []
        for entry in entries where entry.mode != .disabled {
            for term in [entry.preferredOutput] + entry.aliases where term.containsLatin {
                if seen.insert(term.lowercased()).inserted {
                    hints.append(term)
                }
            }
        }
        return hints
    }

    private func kind(alias: String, output: String) -> Suggestion.Kind {
        if let entry = entries.first(where: { $0.turns(alias, into: output) }) {
            return .lockEntry(entryID: entry.id)
        }
        if let entry = entries.first(where: { $0.preferredOutput == output }) {
            return .addAlias(entryID: entry.id)
        }
        return .newEntry
    }
}

private extension GlossaryEntry {
    func turns(_ alias: String, into output: String) -> Bool {
        let aliasKey = MatchText.keyString(alias)
        return preferredOutput == output && aliases.contains { MatchText.keyString($0) == aliasKey }
    }
}
