// WordSegmenter.swift
// KrasipKit
// Splits mixed Thai-English text into words: Thai runs via NaturalLanguage, Latin runs by character class.

import Foundation
import NaturalLanguage

/// Word segmentation used for analysis only (learning corrections, counting words).
/// It never rewrites dictated text.
public enum WordSegmenter {
    /// Character-offset ranges of words. Whitespace and punctuation are not words.
    public static func wordRanges(in text: String) -> [Range<Int>] {
        pieces(in: Array(text)).compactMap { $0.isWord ? $0.range : nil }
    }

    public static func words(in text: String) -> [String] {
        let characters = Array(text)
        return wordRanges(in: text).map { String(characters[$0]) }
    }

    public static func wordCount(_ text: String) -> Int {
        wordRanges(in: text).count
    }

    /// Character offsets where any word, space, or punctuation piece starts or ends.
    static func boundaryOffsets(in characters: [Character]) -> Set<Int> {
        var offsets: Set<Int> = [0, characters.count]
        for piece in pieces(in: characters) {
            offsets.insert(piece.range.lowerBound)
            offsets.insert(piece.range.upperBound)
        }
        return offsets
    }

    private struct Piece {
        let range: Range<Int>
        let isWord: Bool
    }

    private static func pieces(in characters: [Character]) -> [Piece] {
        var pieces: [Piece] = []
        var index = 0

        while index < characters.count {
            let character = characters[index]
            switch character.scriptClass {
            case .whitespace:
                var end = index + 1
                while end < characters.count, characters[end].scriptClass == .whitespace { end += 1 }
                pieces.append(Piece(range: index..<end, isWord: false))
                index = end

            case .thai:
                var end = index + 1
                while end < characters.count, characters[end].scriptClass == .thai { end += 1 }
                pieces.append(contentsOf: thaiWords(characters, in: index..<end))
                index = end

            case .latin, .digit:
                var end = index + 1
                while end < characters.count {
                    let current = characters[end]
                    if current.isLatinOrDigit {
                        end += 1
                    } else if isConnector(current),
                              end + 1 < characters.count,
                              characters[end + 1].isLatinOrDigit {
                        end += 2
                    } else {
                        break
                    }
                }
                pieces.append(Piece(range: index..<end, isWord: true))
                index = end

            case .other:
                pieces.append(Piece(range: index..<(index + 1), isWord: false))
                index += 1
            }
        }
        return pieces
    }

    private static func isConnector(_ character: Character) -> Bool {
        character == "-" || character == "'" || character == "’" || character == "." || character == "_"
    }

    private static func thaiWords(_ characters: [Character], in run: Range<Int>) -> [Piece] {
        let text = String(characters[run])
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.setLanguage(.thai)
        tokenizer.string = text

        var pieces: [Piece] = []
        var covered = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            let end = text.distance(from: text.startIndex, to: range.upperBound)
            if start > covered {
                pieces.append(Piece(range: (run.lowerBound + covered)..<(run.lowerBound + start), isWord: true))
            }
            if end > start {
                pieces.append(Piece(range: (run.lowerBound + start)..<(run.lowerBound + end), isWord: true))
            }
            covered = max(covered, end)
            return true
        }
        if covered < run.count {
            pieces.append(Piece(range: (run.lowerBound + covered)..<run.upperBound, isWord: true))
        }
        return mergeBrokenSyllables(pieces, characters)
    }

    /// NaturalLanguage splits unknown loanwords badly (e.g. "ไซต์" → "ไซ" + "ต์"). A piece that
    /// starts with a silent letter (์), a following vowel, or ๆ belongs to the piece before it;
    /// a piece that ends with a leading vowel (เ แ โ ใ ไ) belongs to the piece after it.
    private static func mergeBrokenSyllables(_ pieces: [Piece], _ characters: [Character]) -> [Piece] {
        var merged: [Piece] = []
        for piece in pieces {
            guard let last = merged.last else {
                merged.append(piece)
                continue
            }
            let first = characters[piece.range.lowerBound]
            let previousLast = characters[last.range.upperBound - 1]
            let attachesBackward = first.unicodeScalars.contains { $0.value == 0x0E4C }
                || first.unicodeScalars.first.map { $0.isThaiFollowingVowel || $0.value == 0x0E46 } == true
            let previousWantsNext = previousLast.unicodeScalars.first?.isThaiLeadingVowel == true
            if attachesBackward || previousWantsNext {
                merged[merged.count - 1] = Piece(range: last.range.lowerBound..<piece.range.upperBound, isWord: true)
            } else {
                merged.append(piece)
            }
        }
        return merged
    }
}
