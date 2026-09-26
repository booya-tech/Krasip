// SoundAlikeMatcher.swift
// KrasipKit
// Finds Thai spellings that sound like a saved alias but are spelled differently. Suggestions only.

import Foundation

/// A high-confidence sound-alike match: the whole Thai alias sounds the same (same sound key,
/// at least four sound units long), and the match sits on word and syllable boundaries.
/// The policy never applies these on its own; the user confirms each one.
struct SoundAlikeMatcher {
    private struct Candidate {
        let entry: GlossaryEntry
        let alias: String
        let key: [Character]
    }

    static let minimumKeyLength = 4

    private let candidates: [Candidate]

    init(entries: [GlossaryEntry]) {
        candidates = entries
            .filter { $0.mode != .disabled && !$0.preferredOutput.isEmpty }
            .flatMap { entry in
                entry.aliases.compactMap { alias -> Candidate? in
                    guard alias.containsThai else { return nil }
                    let key = SoundKey.key(alias)
                    return key.count >= Self.minimumKeyLength ? Candidate(entry: entry, alias: alias, key: key) : nil
                }
            }
    }

    var isEmpty: Bool { candidates.isEmpty }

    func matches(in text: String) -> [Replacement] {
        guard !candidates.isEmpty, text.containsThai else { return [] }
        let soundText = SoundKey(text)
        let keys = soundText.keys

        var hits: [(candidate: Candidate, range: Range<String.Index>, length: Int)] = []
        for candidate in candidates where candidate.key.count <= keys.count {
            var start = 0
            while start + candidate.key.count <= keys.count {
                let end = start + candidate.key.count
                if keys[start] == candidate.key[0], keys[start..<end].elementsEqual(candidate.key) {
                    let range = soundText.origins[start].lowerBound..<soundText.origins[end - 1].upperBound
                    let matched = text[range]
                    let sameLength = abs(matched.count - candidate.alias.count) <= max(2, candidate.alias.count / 3)
                    if sameLength, matched.contains(where: { $0.scriptClass == .thai }), MatchBoundary.isAcceptable(range, in: text) {
                        hits.append((candidate, range, candidate.key.count))
                    }
                }
                start += 1
            }
        }

        hits.sort { lhs, rhs in
            lhs.length != rhs.length ? lhs.length > rhs.length : lhs.range.lowerBound < rhs.range.lowerBound
        }
        var accepted: [(candidate: Candidate, range: Range<String.Index>, length: Int)] = []
        for hit in hits where !accepted.contains(where: { $0.range.overlaps(hit.range) }) {
            accepted.append(hit)
        }

        return accepted
            .sorted { $0.range.lowerBound < $1.range.lowerBound }
            .map { hit in
                Replacement(
                    entryID: hit.candidate.entry.id,
                    range: hit.range,
                    matchedText: String(text[hit.range]),
                    alias: hit.candidate.alias,
                    output: hit.candidate.entry.preferredOutput,
                    mode: .suggest
                )
            }
    }
}
