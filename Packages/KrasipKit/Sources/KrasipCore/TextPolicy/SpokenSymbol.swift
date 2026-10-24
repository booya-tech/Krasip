// SpokenSymbol.swift
// KrasipKit
// Turns the spoken name of a symbol into the symbol: "เครื่องหมายตกใจ" → "!", "แฮชแท็ก krasip" → "#krasip".

import Foundation

/// A spoken symbol name found in the text, and the symbol that takes its place. Mirrors
/// `TimeMatch`, so the policy can run this converter the same way it runs the time converters.
struct SymbolMatch {
    let range: Range<String.Index>
    let replacement: String
}

/// One static table, one entry per symbol. The entry says when a name counts and which
/// neighbour the symbol sticks to, so the matcher never branches per symbol.
enum SpokenSymbol {
    /// What has to be true before a spoken name becomes its symbol.
    private enum Trigger {
        /// Only with a marker word: the Thai prefix เครื่องหมาย, or the English suffix "sign".
        case marker
        /// The name alone is enough, because the name is never an ordinary word.
        case bare
        /// Only directly after a number, and the symbol moves in front of that number.
        case afterNumber
    }

    /// Which side the symbol sticks to, and so which side's spaces the match swallows.
    private enum Attach {
        case left
        case right
    }

    private struct Entry {
        let symbol: String
        let names: [String]
        let trigger: Trigger
        let attach: Attach
    }

    /// Every spelling here was measured from real recordings. The speech model flips between the
    /// Thai and the English name of the same symbol, so most entries carry both.
    ///
    /// `@` is absent because the model writes "." instead of the word, and `%` is absent because
    /// the model already writes `%` itself after a number.
    private static let entries: [Entry] = [
        Entry(symbol: "!", names: ["ตกใจ", "อัศเจรีย์", "exclamation"], trigger: .marker, attach: .left),
        Entry(symbol: "#", names: ["แฮชแท็ก", "hashtag", "แฮช", "hash"], trigger: .bare, attach: .right),
        Entry(symbol: "#", names: ["ชาร์ป", "sharp"], trigger: .marker, attach: .right),
        Entry(symbol: "$", names: ["ดอลลาร์", "ดอลล่า", "dollar", "dollars"], trigger: .afterNumber, attach: .right),
        Entry(symbol: "(", names: ["วงเล็บเปิด", "วงเล็บซ้าย"], trigger: .bare, attach: .right),
        Entry(symbol: ")", names: ["วงเล็บปิด", "วงเล็บขวา"], trigger: .bare, attach: .left),
        Entry(symbol: ":", names: ["โคลอน", "colon"], trigger: .marker, attach: .left),
        Entry(symbol: ";", names: ["เซมิโคลอน", "semicolon", "อัฒภาค"], trigger: .marker, attach: .left),
        // แห่ง is what the model heard for a spoken แอนด์. It is safe only because the marker is
        // required, and nobody says "เครื่องหมายแห่ง" meaning anything else.
        Entry(symbol: "&", names: ["แอนด์", "แห่ง", "and", "ampersand"], trigger: .marker, attach: .left),
        Entry(symbol: "*", names: ["ดอกจัน", "ดอกจันทน์", "asterisk"], trigger: .marker, attach: .left),
        Entry(symbol: "=", names: ["เท่ากับ", "equals", "equal"], trigger: .marker, attach: .left)
    ]

    private static let thaiMarker = "เครื่องหมาย"
    private static let englishMarker = "sign"

    /// Non-overlapping matches, left to right.
    static func matches(in text: String) -> [SymbolMatch] {
        // In a Thai sentence the model mangles "colon sign" into "colon ใส่", so the English
        // suffix is only trusted when nothing in the text is Thai.
        let allowsEnglishMarker = !text.containsThai
        var found: [SymbolMatch] = []
        for candidate in candidates(in: text, allowsEnglishMarker: allowsEnglishMarker) {
            guard !found.contains(where: { $0.range.overlaps(candidate.range) }) else { continue }
            found.append(candidate)
        }
        return found.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// Earliest first, and the longer match first where two start together, so "แฮช" never wins
    /// over "แฮชแท็ก" and "ดอกจัน" never leaves the tail of "ดอกจันทน์" behind.
    private static func candidates(in text: String, allowsEnglishMarker: Bool) -> [SymbolMatch] {
        var candidates: [SymbolMatch] = []
        for entry in entries {
            for name in entry.names {
                for occurrence in occurrences(of: name, in: text) {
                    guard let match = match(
                        entry,
                        name: name,
                        at: occurrence,
                        in: text,
                        allowsEnglishMarker: allowsEnglishMarker
                    ) else { continue }
                    candidates.append(match)
                }
            }
        }
        return candidates.sorted { left, right in
            left.range.lowerBound == right.range.lowerBound
                ? left.range.upperBound > right.range.upperBound
                : left.range.lowerBound < right.range.lowerBound
        }
    }

    private static func match(
        _ entry: Entry,
        name: String,
        at occurrence: Range<String.Index>,
        in text: String,
        allowsEnglishMarker: Bool
    ) -> SymbolMatch? {
        guard hasWordBoundary(around: occurrence, name: name, in: text) else { return nil }

        var start = occurrence.lowerBound
        var end = occurrence.upperBound
        var replacement = entry.symbol

        switch entry.trigger {
        case .marker, .bare:
            // A marker word is part of the spoken phrase either way. A bare name does not need
            // one, but when one is there it is swallowed too, or "เครื่องหมายแฮช" would leave
            // "เครื่องหมาย#" behind.
            var marked = false
            if let markerStart = thaiMarkerStart(before: start, in: text) {
                start = markerStart
                marked = true
            }
            if allowsEnglishMarker, let markerEnd = englishMarkerEnd(after: end, in: text) {
                end = markerEnd
                marked = true
            }
            guard entry.trigger == .bare || marked else { return nil }

        case .afterNumber:
            guard let digits = digitRun(before: start, in: text) else { return nil }
            start = digits.lowerBound
            replacement = entry.symbol + text[digits]
        }

        switch entry.attach {
        case .left:
            while start > text.startIndex, text[text.index(before: start)] == " " {
                start = text.index(before: start)
            }
        case .right:
            while end < text.endIndex, text[end] == " " {
                end = text.index(after: end)
            }
        }
        return SymbolMatch(range: start..<end, replacement: replacement)
    }

    private static func occurrences(of name: String, in text: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        var from = text.startIndex
        while let range = text.range(of: name, options: [.caseInsensitive], range: from..<text.endIndex) {
            found.append(range)
            from = range.upperBound
        }
        return found
    }

    /// Thai runs come back with no spaces, so only a Latin edge of the name can carry a boundary.
    /// Without this, "and" matches inside "android" and "hash" inside "hashed".
    private static func hasWordBoundary(around occurrence: Range<String.Index>, name: String, in text: String) -> Bool {
        if name.first?.isLatinOrDigit == true,
           occurrence.lowerBound > text.startIndex,
           text[text.index(before: occurrence.lowerBound)].isLatinOrDigit {
            return false
        }
        if name.last?.isLatinOrDigit == true,
           occurrence.upperBound < text.endIndex,
           text[occurrence.upperBound].isLatinOrDigit {
            return false
        }
        return true
    }

    /// The start of a เครื่องหมาย sitting just before `start`. The model emits both
    /// "เครื่องหมายชาร์ป" and "เครื่องหมาย colon", so the space between is optional.
    private static func thaiMarkerStart(before start: String.Index, in text: String) -> String.Index? {
        let cursor = skippingSpaces(before: start, in: text)
        guard let marker = text[..<cursor].range(of: thaiMarker, options: [.backwards, .anchored]) else { return nil }
        return marker.lowerBound
    }

    private static func englishMarkerEnd(after end: String.Index, in text: String) -> String.Index? {
        let cursor = skippingSpaces(after: end, in: text)
        guard let marker = text.range(
            of: englishMarker,
            options: [.caseInsensitive, .anchored],
            range: cursor..<text.endIndex
        ) else { return nil }
        guard marker.upperBound == text.endIndex || !text[marker.upperBound].isLatinOrDigit else { return nil }
        return marker.upperBound
    }

    private static func digitRun(before start: String.Index, in text: String) -> Range<String.Index>? {
        let end = skippingSpaces(before: start, in: text)
        var cursor = end
        while cursor > text.startIndex, text[text.index(before: cursor)].scriptClass == .digit {
            cursor = text.index(before: cursor)
        }
        return cursor < end ? cursor..<end : nil
    }

    /// Only plain spaces are crossed. A line break is a real separator, never part of a phrase.
    private static func skippingSpaces(before start: String.Index, in text: String) -> String.Index {
        var cursor = start
        while cursor > text.startIndex, text[text.index(before: cursor)] == " " {
            cursor = text.index(before: cursor)
        }
        return cursor
    }

    private static func skippingSpaces(after end: String.Index, in text: String) -> String.Index {
        var cursor = end
        while cursor < text.endIndex, text[cursor] == " " {
            cursor = text.index(after: cursor)
        }
        return cursor
    }
}
