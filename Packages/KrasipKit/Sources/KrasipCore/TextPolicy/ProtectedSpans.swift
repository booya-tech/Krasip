// ProtectedSpans.swift
// KrasipKit
// Finds URLs, emails, code fragments, numbers, and Latin words that later rules must not alter.

import Foundation

struct ProtectedSpan {
    let range: Range<String.Index>
    let protection: TextSegment.Protection
}

enum ProtectedSpans {
    /// URLs, email addresses, and code fragments. Glossary aliases never match inside these.
    static func structured(in text: String) -> [ProtectedSpan] {
        var spans: [ProtectedSpan] = []
        collect(email, .email, in: text, into: &spans)
        collect(url, .url, in: text, into: &spans, trimTrailingPunctuation: true)
        for pattern in code {
            collect(pattern, .code, in: text, into: &spans)
        }
        return spans.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    /// Latin words and numbers: kept exactly as transcribed.
    static func words(in text: String) -> [ProtectedSpan] {
        var spans: [ProtectedSpan] = []
        collect(number, .number, in: text, into: &spans)
        collect(latinWord, .latinWord, in: text, into: &spans)
        return spans.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    private static func collect(
        _ regex: NSRegularExpression,
        _ protection: TextSegment.Protection,
        in text: String,
        into spans: inout [ProtectedSpan],
        trimTrailingPunctuation: Bool = false
    ) {
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in regex.matches(in: text, range: whole) {
            guard var range = Range(match.range, in: text), !range.isEmpty else { continue }
            if trimTrailingPunctuation {
                while range.upperBound > range.lowerBound,
                      let last = text[range].last, ".,!?;:)]}'\"".contains(last) {
                    range = range.lowerBound..<text.index(before: range.upperBound)
                }
            }
            guard !range.isEmpty, !spans.contains(where: { $0.range.overlaps(range) }) else { continue }
            spans.append(ProtectedSpan(range: range, protection: protection))
        }
    }

    // Lookbehinds instead of \b: ICU treats Thai letters as word characters, so "ดูที่github.com"
    // would otherwise have no boundary before the URL.
    private static let email = regex(
        #"(?<![A-Za-z0-9._%+\-])[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}(?![A-Za-z0-9])"#
    )

    private static let url = regex(
        #"(?i)(?<![A-Za-z0-9@/])(?:(?:https?|ftp)://[^\s<>"\x{0E00}-\x{0E7F}]+|www\.[^\s<>"\x{0E00}-\x{0E7F}]+|(?:[a-z0-9](?:[a-z0-9\-]*[a-z0-9])?\.)+(?:com|net|org|io|dev|app|ai|co|th|me|info|xyz|tech|cloud|so|gg|ly|to|us|uk|jp|sg|edu|gov)(?![a-z0-9])(?:/[^\s<>"\x{0E00}-\x{0E7F}]*)?)"#
    )

    private static let code: [NSRegularExpression] = [
        regex(#"`[^`\n]+`"#),
        regex(#"(?<![A-Za-z0-9_$])[A-Za-z_$][A-Za-z0-9_$]*(?:::|->)[A-Za-z_$][A-Za-z0-9_$]*(?:(?:\.|::|->)[A-Za-z_$][A-Za-z0-9_$]*)*(?:\(\))?"#),
        regex(#"(?<![A-Za-z0-9_$])[A-Za-z_$][A-Za-z0-9_$]+(?:\.[A-Za-z_$][A-Za-z0-9_$]+)+(?:\(\))?(?![A-Za-z0-9_])"#),
        regex(#"(?<![A-Za-z0-9_])[A-Za-z0-9]+(?:_[A-Za-z0-9]+)+(?![A-Za-z0-9_])"#),
        regex(#"(?<![A-Za-z0-9_])[A-Za-z_][A-Za-z0-9_]*\(\)"#),
        regex(#"(?<![A-Za-z0-9\-])--[A-Za-z][A-Za-z0-9\-]*"#),
        regex(#"(?<![A-Za-z0-9])(?:~|\.{1,2})?/[A-Za-z0-9._\-]+(?:/[A-Za-z0-9._\-]+)*"#)
    ]

    private static let number = regex(
        #"(?<![A-Za-z0-9])[0-9]+(?:[.,:][0-9]+)*%?"#
    )

    private static let latinWord = regex(
        #"[A-Za-z\x{00C0}-\x{024F}][A-Za-z0-9\x{00C0}-\x{024F}'’\-]*"#
    )

    private static func regex(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid protected-span pattern \(pattern): \(error)")
        }
    }
}
