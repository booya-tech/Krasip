// LearnerTests.swift
// KrasipCoreTests
// Learning glossary suggestions from corrections: word-level diffs, existing entries, and rewrites.

import Foundation
import Testing
@testable import KrasipCore

struct LearnerTests {
    @Test func learnsThaiTransliterationToEnglish() {
        let suggestion = Glossary().learn(raw: "วันนี้จะต้องกลับบ้านไปทำไซต์โปรเจกต์", corrected: "วันนี้จะต้องกลับบ้านไปทำ side-project")
        #expect(suggestion?.alias == "ไซต์โปรเจกต์")
        #expect(suggestion?.preferredOutput == "side-project")
        #expect(suggestion?.kind == .newEntry)
    }

    @Test func learnsHyphenationOfLatinWords() {
        let suggestion = Glossary().learn(raw: "ทำ side project ต่อ", corrected: "ทำ side-project ต่อ")
        #expect(suggestion?.alias == "side project")
        #expect(suggestion?.preferredOutput == "side-project")
    }

    @Test func growsSingleLetterFixToWholeWord() {
        let suggestion = Glossary().learn(raw: "เปิดไซต์ใหม่", corrected: "เปิดไซด์ใหม่")
        #expect(suggestion?.alias.contains("ไซต์") == true)
        #expect(suggestion?.preferredOutput.contains("ไซด์") == true)
    }

    @Test func learnsCasing() {
        let suggestion = Glossary().learn(raw: "push ขึ้น github", corrected: "push ขึ้น GitHub")
        #expect(suggestion?.alias == "github")
        #expect(suggestion?.preferredOutput == "GitHub")
    }

    @Test func findsSeveralSmallChanges() {
        let suggestions = Glossary().learnAll(
            before: "เดี๋ยวส่ง พูลรีเควสต์ ไปที่ กิตฮับ นะครับ ขอบคุณ",
            after: "เดี๋ยวส่ง pull request ไปที่ GitHub นะครับ ขอบคุณ"
        )
        #expect(suggestions.map(\.preferredOutput) == ["pull request", "GitHub"])
    }

    @Test func suggestsAddingAliasToExistingEntry() {
        let glossary = Glossary([AcceptanceTests.sideProject])
        let suggestion = glossary.learn(raw: "ทำไซต์โปรเจ็กต์", corrected: "ทำ side-project")
        #expect(suggestion?.kind == .addAlias(entryID: AcceptanceTests.sideProject.id))
    }

    @Test func suggestsLockingAKnownSuggestEntry() {
        let entry = GlossaryEntry(aliases: ["กิตฮับ"], preferredOutput: "GitHub", mode: .suggest)
        let suggestion = Glossary([entry]).learn(raw: "ขึ้น กิตฮับ", corrected: "ขึ้น GitHub")
        #expect(suggestion?.kind == .lockEntry(entryID: entry.id))
    }

    @Test func ignoresWholeSentenceRewrites() {
        let suggestions = Glossary().learnAll(
            before: "วันนี้อากาศดีมากเลยนะครับ",
            after: "Please send me the quarterly report tomorrow."
        )
        #expect(suggestions.isEmpty)
    }

    @Test func ignoresPureInsertionsAndDeletions() {
        #expect(Glossary().learnAll(before: "ส่งงาน", after: "ส่งงานแล้วนะ").isEmpty)
        #expect(Glossary().learnAll(before: "ส่งงานแล้วนะ", after: "ส่งงาน").isEmpty)
    }

    @Test func identicalTextTeachesNothing() {
        #expect(Glossary().learnAll(before: "เหมือนเดิม", after: "เหมือนเดิม").isEmpty)
    }

    @Test func suggestionKeyIgnoresCaseOfAlias() {
        let a = Suggestion(alias: "Side Project", preferredOutput: "side-project", kind: .newEntry)
        let b = Suggestion(alias: "side project", preferredOutput: "side-project", kind: .newEntry)
        #expect(a.key == b.key)
    }

    @Test func knownRulesAreRecognized() {
        let glossary = Glossary([AcceptanceTests.sideProject])
        let suggestion = Suggestion(alias: "ไซต์โปรเจกต์", preferredOutput: "side-project", kind: .newEntry)
        #expect(glossary.alreadyKnows(suggestion))
    }

    @Test func diffHunksAreWordAligned() {
        let hunks = TextDiff.wordHunks(from: "ไปทำไซต์โปรเจกต์", to: "ไปทำ side-project")
        #expect(hunks.count == 1)
        let old = Array("ไปทำไซต์โปรเจกต์")
        #expect(String(old[hunks[0].before]) == "ไซต์โปรเจกต์")
    }

    @Test func countsChangedWords() {
        #expect(Correction.changedWords(from: "push ขึ้น github", to: "push ขึ้น GitHub") == 1)
        #expect(Correction.changedWords(from: "same", to: "same") == 0)
    }
}
