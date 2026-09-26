// SoundAlikeTests.swift
// KrasipCoreTests
// Thai spellings that sound like a saved alias are suggested, never applied until the user confirms.

import Foundation
import Testing
@testable import KrasipCore

struct SoundAlikeTests {
    private let policy = TextPolicy()
    private let glossary = Glossary([AcceptanceTests.sideProject])

    @Test(arguments: [
        ("ไซต์โปรเจกต์", "ไซด์โปรเจ็กต์"),
        ("คอมมิต", "คอมมิท"),
        ("ฟีดแบ็ก", "ฟีดแบค"),
        ("อัปเดต", "อัพเดท"),
        ("เมิร์จ", "เมิจ")
    ])
    func variantSpellingsShareASoundKey(_ first: String, _ second: String) {
        #expect(SoundKey.key(first) == SoundKey.key(second))
    }

    @Test func differentWordsHaveDifferentKeys() {
        #expect(SoundKey.key("ไซต์โปรเจกต์") != SoundKey.key("ไซต์งาน"))
        #expect(SoundKey.key("คอมมิต") != SoundKey.key("คอมพิวเตอร์"))
    }

    @Test func soundAlikeIsSuggestedButTextIsUnchanged() {
        let result = policy.finalize("ทำไซด์โปรเจ็กต์ต่อ", glossary: glossary)
        #expect(result.text == "ทำไซด์โปรเจ็กต์ต่อ")
        #expect(result.suggestions.count == 1)
        let suggestion = try! #require(result.suggestions.first)
        #expect(suggestion.isSoundAlike)
        #expect(suggestion.matchedText == "ไซด์โปรเจ็กต์")
        #expect(suggestion.preferredOutput == "side-project")
    }

    @Test func acceptedSoundAlikeIsApplied() {
        let first = policy.finalize("ทำไซด์โปรเจ็กต์ต่อ", glossary: glossary)
        var decisions = PolicyDecisions()
        decisions.accept(try! #require(first.suggestions.first))
        let accepted = policy.finalize("ทำไซด์โปรเจ็กต์ต่อ", glossary: glossary, decisions: decisions)
        #expect(accepted.text == "ทำ side-project ต่อ")
        #expect(accepted.visibleChanges.first?.description == "ไซด์โปรเจ็กต์ -> side-project (glossary)")
    }

    @Test func exactAliasWinsOverSoundAlike() {
        let result = policy.finalize("ทำไซต์โปรเจกต์ต่อ", glossary: glossary)
        #expect(result.text == "ทำ side-project ต่อ")
        #expect(result.suggestions.isEmpty)
    }

    @Test func unrelatedThaiIsLeftAlone() {
        for raw in ["ไปทำงานต่อ", "ไซต์งานก่อสร้างอยู่ไกล", "โปรแกรมเมอร์ทำงานหนัก"] {
            let result = policy.finalize(raw, glossary: glossary)
            #expect(result.text == raw)
            #expect(result.suggestions.isEmpty, "\(raw)")
        }
    }

    @Test func shortAliasesNeverSoundAlike() {
        let entry = GlossaryEntry(aliases: ["ไซต์"], preferredOutput: "site")
        let result = policy.finalize("เปิดไซด์ใหม่", glossary: Glossary([entry]))
        #expect(result.suggestions.isEmpty)
    }

    @Test func canBeTurnedOff() {
        let style = TextStyle(suggestSoundAlikes: false)
        let result = policy.finalize("ทำไซด์โปรเจ็กต์ต่อ", glossary: glossary, style: style)
        #expect(result.suggestions.isEmpty)
    }

    @Test func disabledEntriesDoNotSoundAlike() {
        var entry = AcceptanceTests.sideProject
        entry.mode = .disabled
        #expect(policy.finalize("ทำไซด์โปรเจ็กต์ต่อ", glossary: Glossary([entry])).suggestions.isEmpty)
    }

    @Test func silentLettersAreKeptWithTheWord() {
        // The trailing ต์ is silent; the suggestion must cover it so no stray mark is left.
        let result = policy.finalize("ไซด์โปรเจ็กต์", glossary: glossary)
        #expect(result.suggestions.first?.matchedText == "ไซด์โปรเจ็กต์")
    }
}

@MainActor
struct SoundAlikeFlowTests {
    @Test func acceptingASoundAlikeTeachesTheAlias() async {
        var confirmed: [(UUID, String)] = []
        let harness = FlowHarness()
        harness.transcriber = FixtureTranscriber(text: "ทำไซด์โปรเจ็กต์ต่อ")
        harness.onConfirmAlias = { confirmed.append(($0, $1)) }
        await harness.dictate()

        guard case .review(let review) = harness.flow.phase, let suggestion = review.finalText.suggestions.first else {
            Issue.record("Expected a sound-alike suggestion to review")
            return
        }
        #expect(review.reasons.contains(.suggestions))
        harness.flow.accept(suggestion)
        guard case .review(let accepted) = harness.flow.phase else { return }
        #expect(accepted.text == "ทำ side-project ต่อ")
        #expect(confirmed.map(\.1) == ["ไซด์โปรเจ็กต์"])
        #expect(confirmed.first?.0 == AcceptanceTests.sideProject.id)
    }
}
