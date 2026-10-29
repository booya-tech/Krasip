// SpokenEmail.swift
// KrasipKit
// Assembles an email address the user spoke in parts: "patompong.beam at sign gmail dot com" → "patompong.beam@gmail.com".

import Foundation

/// The speech model writes a spoken address as loose words: the `@` stays a phrase ("at sign",
/// "แอดไซน์"), a dot can stay the word "dot", and a spelled name comes back as "p-e-a-m". This
/// finds the whole address around a spoken `@` and writes it as one token. It must run before URLs
/// and code are protected, because that step seals "gmail.com" on its own and the `@` could then
/// never join it.
enum SpokenEmail {
    /// A bare "at" is an everyday word, so it only counts in front of a domain people mail every
    /// day. "work at google.com" stays as spoken.
    private static let mailProviders: Set<String> = [
        "gmail.com", "hotmail.com", "outlook.com", "yahoo.com", "icloud.com"
    ]

    /// Every part is joined to the next by a dot, written or spoken, so a plain space ends the
    /// address and the word before it stays out. A dot may lean on the next label, as in
    /// "p-a-t-o-m-p-o-n-g .p-e-a-m", but a dot followed by a space ends a sentence instead.
    private static let pattern: NSRegularExpression = {
        let label = #"[A-Za-z0-9][A-Za-z0-9_+\-]*"#
        let separator = #"(?: ?\.| dot )"#
        let spokenAt = #"(?: +(?<latin>at[ -]?sign|add sign|at) +| *แอ[ดท] ?ไซน์ *)"#
        let pattern = #"(?<![A-Za-z0-9_.\-@/:`])"#
            + "(?<local>\(label)(?:\(separator)\(label))*)"
            + spokenAt
            + "(?<domain>\(label)(?:\(separator)\(label))+)"
            + #"(?![A-Za-z0-9_\-@/])"#
        do {
            return try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            preconditionFailure("Invalid spoken-email pattern: \(error)")
        }
    }()

    static func matches(in text: String) -> [SymbolMatch] {
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        return pattern.matches(in: text, range: whole).compactMap { result in
            guard let range = Range(result.range, in: text),
                  let localRange = Range(result.range(withName: "local"), in: text),
                  let domainRange = Range(result.range(withName: "domain"), in: text) else { return nil }
            let local = labels(in: text[localRange])
            let domain = labels(in: text[domainRange])
            guard DottedEmailRepair.isEmailDomain(domain[...]) else { return nil }
            let joinedDomain = domain.joined(separator: ".")
            if let bare = Range(result.range(withName: "latin"), in: text),
               text[bare].lowercased() == "at",
               !mailProviders.contains(joinedDomain.lowercased()) {
                return nil
            }
            return SymbolMatch(range: range, replacement: local.joined(separator: ".") + "@" + joinedDomain)
        }
    }

    /// The labels between the dots, with a spelled-out label such as "p-e-a-m" written as one word.
    private static func labels(in part: Substring) -> [String] {
        part.replacingOccurrences(of: " dot ", with: ".", options: .caseInsensitive)
            .replacingOccurrences(of: " ", with: "")
            .split(separator: ".")
            .map { label in
                let pieces = label.split(separator: "-", omittingEmptySubsequences: false)
                let spelled = pieces.count >= 3 && pieces.allSatisfy { $0.count == 1 }
                return spelled ? pieces.joined() : String(label)
            }
    }
}
