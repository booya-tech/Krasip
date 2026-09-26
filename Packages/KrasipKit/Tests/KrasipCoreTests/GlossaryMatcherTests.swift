// GlossaryMatcherTests.swift
// KrasipCoreTests
// Exact normalized alias matching: case, spacing, Thai marks, word and syllable boundaries.

import Foundation
import Testing
@testable import KrasipCore

struct GlossaryMatcherTests {
    private func resolve(_ text: String, _ entries: GlossaryEntry...) -> [String] {
        Glossary(entries).resolve(text).map(\.matchedText)
    }

    @Test func matchesLatinAliasIgnoringCase() {
        let entry = GlossaryEntry(aliases: ["side project"], preferredOutput: "side-project")
        #expect(resolve("ทำ Side Project", entry) == ["Side Project"])
    }

    @Test func matchesLatinAliasAcrossRepeatedSpaces() {
        let entry = GlossaryEntry(aliases: ["side project"], preferredOutput: "side-project")
        #expect(resolve("ทำ side   project", entry) == ["side   project"])
    }

    @Test func doesNotMatchInsideLongerLatinWord() {
        let entry = GlossaryEntry(aliases: ["code"], preferredOutput: "Code")
        #expect(resolve("encode และ codebase", entry).isEmpty)
        #expect(resolve("push code ขึ้น", entry) == ["code"])
    }

    @Test func doesNotMatchInsideHyphenatedWord() {
        let entry = GlossaryEntry(aliases: ["project"], preferredOutput: "โปรเจกต์")
        #expect(resolve("side-project กับ my_project", entry).isEmpty)
    }

    @Test func matchesThaiAliasInsideThaiRun() {
        let entry = GlossaryEntry(aliases: ["ไซต์โปรเจกต์"], preferredOutput: "side-project")
        #expect(resolve("ไปทำไซต์โปรเจกต์ตอนเย็น", entry) == ["ไซต์โปรเจกต์"])
    }

    @Test func thaiAliasIgnoresSpacesTheRecognizerInserted() {
        let entry = GlossaryEntry(aliases: ["ไซต์โปรเจกต์"], preferredOutput: "side-project")
        #expect(resolve("ไปทำไซต์ โปรเจกต์", entry) == ["ไซต์ โปรเจกต์"])
    }

    @Test func decomposedSaraAmMatches() {
        let composed = GlossaryEntry(aliases: ["ทำงาน"], preferredOutput: "work")
        #expect(resolve("ไป\u{0E17}\u{0E4D}\u{0E32}งาน", composed) == ["\u{0E17}\u{0E4D}\u{0E32}งาน"])
    }

    @Test func neverSplitsAConsonantFromItsMarks() {
        // "กี่" is one character: ก plus vowel and tone mark. Alias "ก" must not match it.
        let entry = GlossaryEntry(aliases: ["ก"], preferredOutput: "K")
        #expect(resolve("กี่โมง", entry).isEmpty)
    }

    @Test func respectsThaiLeadingVowels() {
        // In "เกม" the leading vowel เ belongs to ก, so alias "กม" must not match.
        let entry = GlossaryEntry(aliases: ["กม"], preferredOutput: "km")
        #expect(resolve("เล่นเกมกัน", entry).isEmpty)
    }

    @Test func respectsThaiFollowingVowels() {
        // In "ขา" the vowel า belongs to ข, so alias "ข" must not match.
        let entry = GlossaryEntry(aliases: ["ข"], preferredOutput: "K")
        #expect(resolve("ขาเจ็บ", entry).isEmpty)
    }

    @Test func longestAliasWins() {
        let long = GlossaryEntry(aliases: ["pull request"], preferredOutput: "pull request (PR)")
        let short = GlossaryEntry(aliases: ["request"], preferredOutput: "คำขอ")
        let matches = Glossary([short, long]).resolve("ส่ง pull request ให้ทีม")
        #expect(matches.map(\.output) == ["pull request (PR)"])
    }

    @Test func lockedWinsOverSuggestAtSameLength() {
        let suggest = GlossaryEntry(aliases: ["github"], preferredOutput: "Github", mode: .suggest)
        let locked = GlossaryEntry(aliases: ["github"], preferredOutput: "GitHub", mode: .locked)
        let matches = Glossary([suggest, locked]).resolve("push ขึ้น github")
        #expect(matches.map(\.output) == ["GitHub"])
    }

    @Test func disabledEntriesAreIgnored() {
        let entry = GlossaryEntry(aliases: ["github"], preferredOutput: "GitHub", mode: .disabled)
        #expect(resolve("github", entry).isEmpty)
    }

    @Test func findsEveryOccurrence() {
        let entry = GlossaryEntry(aliases: ["PR"], preferredOutput: "pull request")
        #expect(resolve("PR แรกกับ PR ที่สอง", entry).count == 2)
    }

    @Test func fullWidthAndDashVariantsNormalize() {
        let entry = GlossaryEntry(aliases: ["side-project"], preferredOutput: "side-project")
        #expect(resolve("ทำ ｓｉｄｅ\u{2010}project", entry).count == 1)
    }

    @Test func cleansDuplicateAliases() {
        let entry = GlossaryEntry(aliases: [" side project ", "Side Project", "", "ไซต์โปรเจกต์"], preferredOutput: "side-project")
        #expect(entry.aliases == ["side project", "ไซต์โปรเจกต์"])
    }

    @Test func flagsVeryShortThaiAliases() {
        let entry = GlossaryEntry(aliases: ["ไซ", "ไซต์โปรเจกต์"], preferredOutput: "side-project")
        #expect(entry.riskyAliases == ["ไซ"])
    }

    @Test func vocabularyHintsIncludeLatinSpellings() {
        let glossary = Glossary([AcceptanceTests.sideProject])
        #expect(glossary.vocabularyHints == ["side-project", "side project"])
    }
}
