// DottedEmailRepair.swift
// KrasipKit
// Puts back the `@` the speech model wrote as a dot: "support.at.grasip.app" and, after an email cue, "admin.example.com".

import Foundation

/// The model rarely writes `@` for a spoken email address. It keeps the word "at" as a label of
/// its own, or writes a dot in its place. Both repairs work on one dotted token and must run
/// before URLs and code are protected, because that step seals every dotted token as it stands.
///
/// A wrong `@` inside a URL or a file name is worse than a missing one, so each repair asks for
/// a token that already looks like an email address once the `@` is back.
enum DottedEmailRepair {
    /// A bare domain and an email address with its `@` lost look the same, so the lone-dot repair
    /// needs one of these just before the token. Thai has no spaces, so a cue is found anywhere in
    /// the window. "ส่งไปที่" is deliberately absent: it comes before a URL just as often.
    private static let cues = ["อีเมล", "อีเมล์", "เมล", "สำเนา", "email", "e-mail", "mail", "cc", "bcc"]
    private static let cueWindow = 25

    /// A token ending in one of these is a file, not an email address.
    private static let fileExtensions: Set<String> = [
        "pdf", "txt", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv", "json", "xml", "md",
        "png", "jpg", "jpeg", "gif", "svg", "heic", "zip", "mp3", "mp4", "mov", "wav",
        "swift", "js", "ts", "py", "rb", "java", "html", "css", "yaml", "yml", "log", "sql"
    ]

    /// A token starting with one of these is a server's address, not a person's.
    private static let hostPrefixes: Set<String> = ["www", "mail", "webmail", "smtp", "imap"]

    /// A run of labels joined by dots, not inside a URL, a path, an existing address, or code.
    private static let dottedToken: NSRegularExpression = {
        let pattern = #"(?<![A-Za-z0-9_\-.@/:`])[A-Za-z0-9_\-]+(?:\.[A-Za-z0-9_\-]+)+"#
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid dotted-token pattern: \(error)")
        }
    }()
    private static let blockedFollowers: Set<Character> = ["/", ":", "?", "#", "@", "`", "("]

    static func matches(in text: String) -> [SymbolMatch] {
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        return dottedToken.matches(in: text, range: whole).compactMap { result in
            guard let range = Range(result.range, in: text) else { return nil }
            if range.upperBound < text.endIndex, blockedFollowers.contains(text[range.upperBound]) { return nil }
            let labels = text[range].split(separator: ".").map(String.init)
            guard let first = labels.first, !hostPrefixes.contains(first.lowercased()) else { return nil }
            guard let address = address(from: labels, cued: hasCue(before: range.lowerBound, in: text)) else { return nil }
            return SymbolMatch(range: range, replacement: address)
        }
    }

    /// `support.at.grasip.app` when the word "at" survived as a middle label, otherwise
    /// `admin.example.com` with its first dot as the `@` when the text names an email.
    private static func address(from labels: [String], cued: Bool) -> String? {
        let local: ArraySlice<String>
        let domain: ArraySlice<String>
        if let at = labels.indices.dropFirst().dropLast().first(where: { labels[$0] == "at" }) {
            local = labels[..<at]
            domain = labels[(at + 1)...]
            guard labels[at - 1].containsLatin, labels[at + 1].containsLatin else { return nil }
        } else if labels.count == 3, cued {
            local = labels[..<1]
            domain = labels[1...]
        } else {
            return nil
        }
        guard isEmailDomain(domain) else { return nil }
        return local.joined(separator: ".") + "@" + domain.joined(separator: ".")
    }

    private static func isEmailDomain(_ labels: ArraySlice<String>) -> Bool {
        guard labels.count >= 2, let last = labels.last?.lowercased() else { return false }
        return (2...6).contains(last.count)
            && last.allSatisfy { $0.isASCII && $0.isLetter }
            && !fileExtensions.contains(last)
    }

    private static func hasCue(before start: String.Index, in text: String) -> Bool {
        var windowStart = text.index(start, offsetBy: -cueWindow, limitedBy: text.startIndex) ?? text.startIndex
        if let newline = text[windowStart..<start].lastIndex(where: \.isNewline) {
            windowStart = text.index(after: newline)
        }
        let window = windowStart..<start
        return cues.contains { cue in
            var from = window.lowerBound
            while let found = text.range(of: cue, options: .caseInsensitive, range: from..<window.upperBound) {
                if cue.containsThai || isWholeWord(found, in: text) { return true }
                from = found.upperBound
            }
            return false
        }
    }

    private static func isWholeWord(_ range: Range<String.Index>, in text: String) -> Bool {
        let before = range.lowerBound > text.startIndex ? text[text.index(before: range.lowerBound)] : nil
        let after = range.upperBound < text.endIndex ? text[range.upperBound] : nil
        return before?.isLatinOrDigit != true && after?.isLatinOrDigit != true
    }
}
