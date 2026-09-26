// SoundKey.swift
// KrasipKit
// A rough "how it sounds" key for Thai spellings, so ไซด์โปรเจ็กต์ and ไซต์โปรเจกต์ compare equal.

import Foundation

/// Speech engines spell the same English loanword in Thai several ways. The sound key drops
/// what does not change the sound (tone marks, ็, silent letters with ์, spaces) and folds
/// consonants that sound alike (ต/ด/ท, ก/ค, ซ/ส…). Used only to *suggest* glossary matches;
/// the user always confirms them.
struct SoundKey {
    let source: String
    let keys: [Character]
    let origins: [Range<String.Index>]

    init(_ source: String) {
        self.source = source
        let built = Self.build(source)
        keys = built.keys
        origins = built.origins
    }

    static func key(_ text: String) -> [Character] {
        build(text).keys
    }

    private static func build(_ text: String) -> (keys: [Character], origins: [Range<String.Index>]) {
        let scalars = Array(text.unicodeScalars.indices).map { (index: $0, scalar: text.unicodeScalars[$0]) }
        func upper(_ position: Int) -> String.Index {
            position + 1 < scalars.count ? scalars[position + 1].index : text.endIndex
        }

        var keys: [Character] = []
        var origins: [Range<String.Index>] = []
        var pendingLower: String.Index?

        func absorb(_ range: Range<String.Index>) {
            if origins.isEmpty {
                pendingLower = pendingLower ?? range.lowerBound
            } else {
                origins[origins.count - 1] = origins[origins.count - 1].lowerBound..<range.upperBound
            }
        }

        func emit(_ sound: String, _ range: Range<String.Index>) {
            let lower = pendingLower ?? range.lowerBound
            pendingLower = nil
            for (offset, character) in sound.enumerated() {
                keys.append(character)
                origins.append((offset == 0 ? lower : range.lowerBound)..<range.upperBound)
            }
        }

        var position = 0
        while position < scalars.count {
            let scalar = scalars[position].scalar
            let range = scalars[position].index..<upper(position)

            if isConsonant(scalar) {
                var next = position + 1
                while next < scalars.count, isSilencerCompanion(scalars[next].scalar) {
                    next += 1
                }
                if next < scalars.count, scalars[next].scalar.value == 0x0E4C {
                    absorb(scalars[position].index..<upper(next))
                    position = next + 1
                    continue
                }
            }

            if scalar.value == 0x0E4D, position + 1 < scalars.count, scalars[position + 1].scalar.value == 0x0E32 {
                emit("am", scalars[position].index..<upper(position + 1))
                position += 2
                continue
            }

            if let sound = sound(of: scalar) {
                emit(sound, range)
            } else {
                absorb(range)
            }
            position += 1
        }
        return (keys, origins)
    }

    private static func isConsonant(_ scalar: Unicode.Scalar) -> Bool {
        (0x0E01...0x0E2E).contains(scalar.value)
    }

    /// Marks that can sit between a consonant and the silencer ์ (e.g. the ิ in ดิ์).
    private static func isSilencerCompanion(_ scalar: Unicode.Scalar) -> Bool {
        [0x0E34, 0x0E38, 0x0E48, 0x0E49, 0x0E4A, 0x0E4B].contains(scalar.value)
    }

    private static func sound(of scalar: Unicode.Scalar) -> String? {
        if let thai = thaiSounds[scalar.value] {
            return thai.isEmpty ? nil : thai
        }
        if scalar.isThai || scalar.properties.isWhitespace || scalar.isZeroWidth {
            return nil
        }
        if scalar.isLatinLetter || scalar.isASCIIDigit {
            return scalar.properties.lowercaseMapping
        }
        return nil
    }

    /// Consonants grouped by sound, vowels by quality (long and short merged). Tone marks,
    /// ็, ์, and repetition marks map to "" and are ignored.
    private static let thaiSounds: [UInt32: String] = {
        var table: [UInt32: String] = [:]
        func set(_ characters: String, _ sound: String) {
            for scalar in characters.unicodeScalars {
                table[scalar.value] = sound
            }
        }
        set("กขฃคฅฆ", "k")
        set("ง", "N")
        set("จฉชฌ", "c")
        set("ซศษส", "s")
        set("ญย", "y")
        set("ฎฏดตฐฑฒถทธ", "t")
        set("ณน", "n")
        set("บ", "b")
        set("ปผพภ", "p")
        set("ฝฟ", "f")
        set("ม", "m")
        set("รลฬ", "l")
        set("ว", "w")
        set("หฮ", "h")
        set("อ", "o")
        set("ะัาๅ", "a")
        set("ำ", "am")
        set("ิี", "i")
        set("ึื", "U")
        set("ุู", "u")
        set("เ", "e")
        set("แ", "E")
        set("โ", "o")
        set("ใไ", "ai")
        set("ฤฦ", "l")
        set("\u{0E47}\u{0E48}\u{0E49}\u{0E4A}\u{0E4B}\u{0E4C}\u{0E4E}ๆฯ", "")
        return table
    }()
}
