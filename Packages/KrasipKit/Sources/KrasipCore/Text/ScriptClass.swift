// ScriptClass.swift
// KrasipKit
// Classifies characters as Thai, Latin, digit, whitespace, or other for deterministic text rules.

import Foundation

/// The writing-system class of a character, as far as Krasip's text rules care.
public enum ScriptClass: Equatable, Sendable {
    case thai
    case latin
    case digit
    case whitespace
    case other
}

extension Unicode.Scalar {
    var isThai: Bool { (0x0E00...0x0E7F).contains(value) }

    var isLatinLetter: Bool {
        switch value {
        case 0x41...0x5A, 0x61...0x7A:
            return true
        case 0xC0...0x24F:
            return value != 0xD7 && value != 0xF7 && properties.isAlphabetic
        default:
            return false
        }
    }

    var isASCIIDigit: Bool { (0x30...0x39).contains(value) }

    /// เ แ โ ใ ไ are written before the consonant they belong to.
    var isThaiLeadingVowel: Bool { (0x0E40...0x0E44).contains(value) }

    /// ะ า ำ ๅ are written after the consonant they belong to, as separate characters.
    var isThaiFollowingVowel: Bool {
        value == 0x0E30 || value == 0x0E32 || value == 0x0E33 || value == 0x0E45
    }

    var isZeroWidth: Bool {
        switch value {
        case 0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF, 0x00AD:
            return true
        default:
            return false
        }
    }
}

extension Character {
    public var scriptClass: ScriptClass {
        if isWhitespace { return .whitespace }
        guard let first = unicodeScalars.first else { return .other }
        if first.isThai { return .thai }
        if first.isLatinLetter { return .latin }
        if first.isASCIIDigit { return .digit }
        return .other
    }

    var isLatinOrDigit: Bool {
        let script = scriptClass
        return script == .latin || script == .digit
    }
}

extension String {
    /// True when the string contains at least one Thai character.
    public var containsThai: Bool { unicodeScalars.contains { $0.isThai } }

    /// True when the string contains at least one Latin letter.
    public var containsLatin: Bool { unicodeScalars.contains { $0.isLatinLetter } }

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
