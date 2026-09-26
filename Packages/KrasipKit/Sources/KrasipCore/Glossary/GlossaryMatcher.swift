// GlossaryMatcher.swift
// KrasipKit
// Finds exact normalized glossary aliases in text without splitting words or Thai syllables.

import Foundation

/// A place in the text where a glossary alias was found.
public struct Replacement: Equatable, Sendable {
    public let entryID: UUID
    public let range: Range<String.Index>
    public let matchedText: String
    public let alias: String
    public let output: String
    public let mode: GlossaryEntry.Mode
}

struct GlossaryMatcher {
    private struct Candidate {
        let entry: GlossaryEntry
        let alias: String
        let key: [Unicode.Scalar]
    }

    private let candidates: [Candidate]

    init(entries: [GlossaryEntry], includeModes: Set<GlossaryEntry.Mode> = [.locked, .suggest]) {
        candidates = entries
            .filter { includeModes.contains($0.mode) && !$0.preferredOutput.isEmpty }
            .flatMap { entry in
                entry.aliases.compactMap { alias -> Candidate? in
                    let key = MatchText.key(alias)
                    return key.isEmpty ? nil : Candidate(entry: entry, alias: alias, key: key)
                }
            }
    }

    /// Non-overlapping matches ordered by position. Longer aliases win over shorter ones;
    /// at equal length, locked entries win over suggestions.
    func matches(in text: String) -> [Replacement] {
        guard !candidates.isEmpty, !text.isEmpty else { return [] }
        let matchText = MatchText(text)
        let keys = matchText.keys

        struct Hit {
            let candidate: Candidate
            let start: Int
            let end: Int
        }

        var hits: [Hit] = []
        for candidate in candidates where candidate.key.count <= keys.count {
            let key = candidate.key
            let first = key[0]
            var start = 0
            while start + key.count <= keys.count {
                if keys[start] == first, keys[start..<(start + key.count)].elementsEqual(key) {
                    let end = start + key.count
                    if isAcceptable(start: start, end: end, in: matchText) {
                        hits.append(Hit(candidate: candidate, start: start, end: end))
                    }
                }
                start += 1
            }
        }

        hits.sort { lhs, rhs in
            if lhs.candidate.key.count != rhs.candidate.key.count {
                return lhs.candidate.key.count > rhs.candidate.key.count
            }
            if lhs.candidate.entry.mode != rhs.candidate.entry.mode {
                return lhs.candidate.entry.mode == .locked
            }
            return lhs.start < rhs.start
        }

        var taken: [Range<Int>] = []
        var accepted: [Hit] = []
        for hit in hits {
            let span = hit.start..<hit.end
            guard !taken.contains(where: { $0.overlaps(span) }) else { continue }
            taken.append(span)
            accepted.append(hit)
        }

        return accepted
            .sorted { $0.start < $1.start }
            .map { hit in
                let range = matchText.origins[hit.start].lowerBound..<matchText.origins[hit.end - 1].upperBound
                return Replacement(
                    entryID: hit.candidate.entry.id,
                    range: range,
                    matchedText: String(text[range]),
                    alias: hit.candidate.alias,
                    output: hit.candidate.entry.preferredOutput,
                    mode: hit.candidate.entry.mode
                )
            }
    }

    private func isAcceptable(start: Int, end: Int, in matchText: MatchText) -> Bool {
        MatchBoundary.isAcceptable(
            matchText.origins[start].lowerBound..<matchText.origins[end - 1].upperBound,
            in: matchText.source
        )
    }
}

/// Where a glossary match may start and end without cutting a word or a Thai syllable.
enum MatchBoundary {
    static func isAcceptable(_ range: Range<String.Index>, in text: String) -> Bool {
        let lower = range.lowerBound
        let upper = range.upperBound
        guard lower < upper else { return false }

        // Never split a grapheme cluster (e.g. a consonant from its tone mark).
        guard lower.samePosition(in: text) != nil, upper.samePosition(in: text) != nil else {
            return false
        }

        let scalars = text.unicodeScalars
        let firstScalar = scalars[lower]
        let lastScalar = scalars[scalars.index(before: upper)]
        let before: Unicode.Scalar? = lower > scalars.startIndex ? scalars[scalars.index(before: lower)] : nil
        let after: Unicode.Scalar? = upper < scalars.endIndex ? scalars[upper] : nil

        // Latin words must match whole words: "code" never matches inside "encode",
        // and "project" never matches inside "side-project" or "my_project".
        if isWordScalar(firstScalar), let before {
            if isWordScalar(before) { return false }
            if isJoiner(before), lower > scalars.index(after: scalars.startIndex) {
                let beforeJoiner = scalars[scalars.index(before: scalars.index(before: lower))]
                if isWordScalar(beforeJoiner) { return false }
            }
        }
        if isWordScalar(lastScalar), let after {
            if isWordScalar(after) { return false }
            let afterNext = scalars.index(after: upper)
            if isJoiner(after), afterNext < scalars.endIndex, isWordScalar(scalars[afterNext]) {
                return false
            }
        }

        // Thai has no spaces between words, so guard syllables instead: a leading vowel
        // (เ แ โ ใ ไ) belongs to the next consonant, and ะ า ำ belong to the previous one.
        if firstScalar.isThai, let before, before.isThaiLeadingVowel {
            return false
        }
        if lastScalar.isThaiLeadingVowel {
            return false
        }
        if lastScalar.isThai, let after, after.isThaiFollowingVowel {
            return false
        }
        return true
    }

    private static func isWordScalar(_ scalar: Unicode.Scalar) -> Bool {
        scalar.isLatinLetter || scalar.isASCIIDigit
    }

    private static func isJoiner(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "-" || scalar == "_"
    }
}
