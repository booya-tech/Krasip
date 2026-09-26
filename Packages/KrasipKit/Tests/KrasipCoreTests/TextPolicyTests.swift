// TextPolicyTests.swift
// KrasipCoreTests
// Normalization, protected spans, spacing, punctuation, suggestions, and undo in the text policy.

import Foundation
import Testing
@testable import KrasipCore

struct TextPolicyTests {
    private let policy = TextPolicy()
    private let glossary = Glossary([AcceptanceTests.sideProject])

    // MARK: Normalization

    @Test func collapsesRepeatedWhitespaceAndTrims() {
        let result = policy.finalize("  เดี๋ยว   push\tcode  ", glossary: Glossary())
        #expect(result.text == "เดี๋ยว push code")
        #expect(result.changes.allSatisfy { $0.kind == .normalization })
    }

    @Test func removesZeroWidthCharacters() {
        let result = policy.finalize("ทำ\u{200B}งาน", glossary: Glossary())
        #expect(result.text == "ทำงาน")
    }

    @Test func composesUnicodeToNFC() {
        let decomposed = "Cafe\u{0301} กับทีม"
        let result = policy.finalize(decomposed, glossary: Glossary())
        #expect(result.text == "Café กับทีม")
        #expect(result.text.unicodeScalars.count == "Café กับทีม".unicodeScalars.count)
    }

    @Test func keepsThaiCharactersExactly() {
        let thai = "ข้าวมันไก่ร้านนี้อร่อยมากเลยนะ"
        #expect(policy.finalize(thai, glossary: glossary).text == thai)
    }

    @Test func emptyTranscriptStaysEmpty() {
        let result = policy.finalize("   ", glossary: glossary)
        #expect(result.text.isEmpty)
    }

    // MARK: Spacing

    @Test func insertsSpaceBetweenThaiAndEnglish() {
        let result = policy.finalize("ส่งpull requestให้ทีม", glossary: Glossary())
        #expect(result.text == "ส่ง pull request ให้ทีม")
        #expect(result.visibleChanges.map(\.kind) == [.spacing, .spacing])
    }

    @Test func insertsSpaceBetweenThaiAndDigits() {
        #expect(policy.finalize("ตอน10 AM", glossary: Glossary()).text == "ตอน 10 AM")
    }

    @Test func spacingCanBeTurnedOff() {
        let style = TextStyle(spaceBetweenThaiAndLatin: false)
        #expect(policy.finalize("ส่งpull request", glossary: Glossary(), style: style).text == "ส่งpull request")
    }

    @Test func existingSpaceIsNotDuplicated() {
        let result = policy.finalize("วันนี้จะต้องกลับบ้านไปทำ side project", glossary: glossary)
        #expect(!result.text.contains("  "))
    }

    // MARK: Protected spans

    @Test func urlsAreNotBrokenBySpacingOrGlossary() {
        let entry = GlossaryEntry(aliases: ["github"], preferredOutput: "GitHub")
        let result = policy.finalize("ดูที่https://github.com/krasipนะ", glossary: Glossary([entry]))
        #expect(result.text == "ดูที่ https://github.com/krasip นะ")
    }

    @Test func emailsAreProtected() {
        let entry = GlossaryEntry(aliases: ["example"], preferredOutput: "EXAMPLE")
        let result = policy.finalize("ส่งไปที่ hello@example.com ครับ", glossary: Glossary([entry]))
        #expect(result.text == "ส่งไปที่ hello@example.com ครับ")
    }

    @Test func codeFragmentsAreProtectedFromPunctuationRemoval() {
        let style = TextStyle(punctuation: .none)
        let result = policy.finalize("แก้ config.json และ fetchUser() แล้ว.", glossary: Glossary(), style: style)
        #expect(result.text == "แก้ config.json และ fetchUser() แล้ว")
    }

    @Test func numbersAreProtected() {
        let style = TextStyle(punctuation: .none)
        let result = policy.finalize("ราคา 2,500 บาท หรือ 3.5%", glossary: Glossary(), style: style)
        #expect(result.text == "ราคา 2,500 บาท หรือ 3.5%")
    }

    @Test func englishIsNeverTransliteratedOrChangedWithoutARule() {
        let raw = "เดี๋ยว merge PR แล้ว deploy ขึ้น production บน AWS ด้วย Terraform"
        let result = policy.finalize(raw, glossary: Glossary())
        #expect(result.text == raw)
        for word in ["merge", "PR", "deploy", "production", "AWS", "Terraform"] {
            #expect(result.text.contains(word))
        }
    }

    @Test func glossaryOutputIsNotReplacedAgain() {
        let entries = [
            GlossaryEntry(aliases: ["side project"], preferredOutput: "side-project"),
            GlossaryEntry(aliases: ["project"], preferredOutput: "โปรเจกต์")
        ]
        let result = policy.finalize("ทำ side project", glossary: Glossary(entries))
        #expect(result.text == "ทำ side-project")
    }

    // MARK: Punctuation

    @Test func keepModeLeavesPunctuation() {
        #expect(policy.finalize("เสร็จแล้วครับ.", glossary: Glossary()).text == "เสร็จแล้วครับ.")
    }

    @Test func noTrailingPeriodModeDropsFinalPeriodOnly() {
        let style = TextStyle(punctuation: .noTrailingPeriod)
        let result = policy.finalize("Hello, team. เสร็จแล้วครับ.", glossary: Glossary(), style: style)
        #expect(result.text == "Hello, team. เสร็จแล้วครับ")
        #expect(result.visibleChanges.map(\.kind) == [.punctuation])
    }

    @Test func noTrailingPeriodKeepsEllipsis() {
        let style = TextStyle(punctuation: .noTrailingPeriod)
        #expect(policy.finalize("เดี๋ยวก่อน...", glossary: Glossary(), style: style).text == "เดี๋ยวก่อน...")
    }

    @Test func noneModeRemovesSentencePunctuation() {
        let style = TextStyle(punctuation: .none)
        let result = policy.finalize("โอเค, เดี๋ยวส่งให้นะ!", glossary: Glossary(), style: style)
        #expect(result.text == "โอเค เดี๋ยวส่งให้นะ")
    }

    // MARK: Glossary behavior

    @Test func suggestModeDoesNotChangeTextButReportsSuggestion() {
        let entry = GlossaryEntry(aliases: ["ไซต์โปรเจกต์"], preferredOutput: "side-project", mode: .suggest)
        let result = policy.finalize("ทำไซต์โปรเจกต์", glossary: Glossary([entry]))
        #expect(result.text == "ทำไซต์โปรเจกต์")
        #expect(result.suggestions.count == 1)
        #expect(result.suggestions.first?.matchedText == "ไซต์โปรเจกต์")
        let range = try! #require(result.suggestions.first?.range)
        #expect(String(Array(result.text)[range]) == "ไซต์โปรเจกต์")
    }

    @Test func acceptingASuggestionAppliesIt() {
        let entry = GlossaryEntry(aliases: ["ไซต์โปรเจกต์"], preferredOutput: "side-project", mode: .suggest)
        let decisions = PolicyDecisions(acceptedSuggestions: [entry.id])
        let result = policy.finalize("ทำไซต์โปรเจกต์", glossary: Glossary([entry]), decisions: decisions)
        #expect(result.text == "ทำ side-project")
        #expect(result.suggestions.isEmpty)
    }

    @Test func disabledEntryNeverReplaces() {
        let entry = GlossaryEntry(aliases: ["side project"], preferredOutput: "side-project", mode: .disabled)
        let result = policy.finalize("ทำ side project", glossary: Glossary([entry]))
        #expect(result.text == "ทำ side project")
        #expect(result.suggestions.isEmpty)
    }

    @Test func undoingAGlossaryChangeRestoresTheTranscript() {
        let first = policy.finalize("ทำไซต์โปรเจกต์", glossary: glossary)
        let change = try! #require(first.visibleChanges.first { $0.kind == .glossary })
        var decisions = PolicyDecisions()
        decisions.undo(change)
        let undone = policy.finalize("ทำไซต์โปรเจกต์", glossary: glossary, decisions: decisions)
        #expect(undone.text == "ทำไซต์โปรเจกต์")
    }

    @Test func undoingSpokenTimeKeepsWords() {
        var decisions = PolicyDecisions()
        decisions.disabledKinds.insert(.spokenTime)
        #expect(policy.finalize("ตอน ten AM", glossary: glossary, decisions: decisions).text == "ตอน ten AM")
    }

    @Test func glossaryRangesPointAtOutputs() {
        let result = policy.finalize("ทำไซต์โปรเจกต์", glossary: glossary)
        let range = try! #require(result.glossaryRanges.first)
        let characters = Array(result.text)
        #expect(String(characters[range]) == "side-project")
    }

    // MARK: Properties

    @Test(arguments: [
        "วันนี้จะต้องกลับบ้านไปทำ side project",
        "เดี๋ยว push code ขึ้น GitHub",
        "นัดกับพี่แบงก์ตอน ten AM",
        "ทำไซต์โปรเจกต์",
        "ดูที่https://github.com/krasipนะ",
        "ราคา 2,500 บาท รวม VAT แล้ว.",
        "ส่งpull requestให้ทีม"
    ])
    func finalizingTwiceChangesNothingMore(_ raw: String) {
        let once = policy.finalize(raw, glossary: glossary)
        let twice = policy.finalize(once.text, glossary: glossary)
        #expect(twice.text == once.text)
        #expect(twice.visibleChanges.isEmpty)
    }

    @Test func everyChangeIsExplainedInSpecFormat() {
        let result = policy.finalize("ไปทำไซต์โปรเจกต์ตอน ten AM", glossary: glossary)
        #expect(result.text == "ไปทำ side-project ตอน 10 AM")
        #expect(result.visibleChanges.map(\.description) == [
            "ไซต์โปรเจกต์ -> side-project (glossary)",
            "ten AM -> 10 AM (spoken time)",
            "ทำside-project -> ทำ side-project (spacing)",
            "side-projectตอน -> side-project ตอน (spacing)"
        ])
    }
}
