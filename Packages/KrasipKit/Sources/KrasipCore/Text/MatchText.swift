// MatchText.swift
// KrasipKit
// Normalized view of a string for glossary matching, with a map back to the original text.

import Foundation

/// A normalized copy of a string used only for comparison. The original text is never
/// rewritten from this view; `origins` maps every normalized scalar back to the source.
///
/// Normalization: Latin case folding, full-width ASCII folding, dash and apostrophe
/// variants, decomposed Thai sara am (ํ + า → ำ), zero-width characters removed, and
/// whitespace collapsed. Whitespace next to Thai text is ignored, because speech
/// recognizers split Thai words with spaces inconsistently.
struct MatchText {
    let source: String
    let keys: [Unicode.Scalar]
    let origins: [Range<String.Index>]

    init(_ source: String) {
        self.source = source
        var builder = Builder(recordOrigins: true)
        builder.consume(source)
        keys = builder.keys
        origins = builder.origins
    }

    static func key(_ text: String) -> [Unicode.Scalar] {
        var builder = Builder(recordOrigins: false)
        builder.consume(text)
        return builder.keys
    }

    static func keyString(_ text: String) -> String {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: key(text))
        return String(view)
    }
}

private struct Builder {
    let recordOrigins: Bool
    var keys: [Unicode.Scalar] = []
    var origins: [Range<String.Index>] = []

    init(recordOrigins: Bool) {
        self.recordOrigins = recordOrigins
    }

    mutating func consume(_ text: String) {
        let scalars = text.unicodeScalars
        var index = scalars.startIndex

        while index < scalars.endIndex {
            let scalar = scalars[index]
            let next = scalars.index(after: index)

            if scalar.isZeroWidth {
                index = next
                continue
            }

            if scalar.properties.isWhitespace {
                var runEnd = next
                while runEnd < scalars.endIndex,
                      scalars[runEnd].properties.isWhitespace || scalars[runEnd].isZeroWidth {
                    runEnd = scalars.index(after: runEnd)
                }
                let previous = keys.last
                let following = runEnd < scalars.endIndex ? scalars[runEnd] : nil
                if let previous, let following, !previous.isThai, !following.isThai {
                    append(" ", origin: index..<runEnd)
                }
                index = runEnd
                continue
            }

            if scalar.value == 0x0E4D, next < scalars.endIndex, scalars[next].value == 0x0E32 {
                append("\u{0E33}", origin: index..<scalars.index(after: next))
                index = scalars.index(after: next)
                continue
            }

            for folded in Self.fold(scalar) {
                append(folded, origin: index..<next)
            }
            index = next
        }
    }

    private mutating func append(_ scalar: Unicode.Scalar, origin: Range<String.Index>) {
        keys.append(scalar)
        if recordOrigins {
            origins.append(origin)
        }
    }

    private static func fold(_ scalar: Unicode.Scalar) -> [Unicode.Scalar] {
        switch scalar.value {
        case 0x2010...0x2015, 0x2212, 0xFE58, 0xFE63, 0xFF0D:
            return ["-"]
        case 0x2018, 0x2019, 0x02BC, 0xFF07:
            return ["'"]
        case 0xFF01...0xFF5E:
            if let ascii = Unicode.Scalar(scalar.value - 0xFEE0) {
                return Array(ascii.properties.lowercaseMapping.unicodeScalars)
            }
            return [scalar]
        default:
            if scalar.isThai || scalar.value < 0x41 {
                return [scalar]
            }
            return Array(scalar.properties.lowercaseMapping.unicodeScalars)
        }
    }
}
