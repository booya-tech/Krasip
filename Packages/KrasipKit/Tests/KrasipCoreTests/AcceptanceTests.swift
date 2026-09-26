// AcceptanceTests.swift
// KrasipCoreTests
// The spec's acceptance table: raw transcript in, expected final text out.

import Foundation
import Testing
@testable import KrasipCore

struct AcceptanceTests {
    /// The one glossary entry from the spec's JSON example.
    static let sideProject = GlossaryEntry(
        aliases: ["side project", "ไซต์โปรเจกต์", "ไซด์โปรเจกต์"],
        preferredOutput: "side-project",
        mode: .locked
    )

    private let policy = TextPolicy()
    private let glossary = Glossary([Self.sideProject])

    @Test func primarySuccessCase() {
        let result = policy.finalize("วันนี้จะต้องกลับบ้านไปทำ side project", glossary: glossary)
        #expect(result.text == "วันนี้จะต้องกลับบ้านไปทำ side-project")
        #expect(result.visibleChanges.map(\.description) == ["side project -> side-project (glossary)"])
    }

    @Test func englishTermsStayUntouched() {
        let result = policy.finalize("เดี๋ยว push code ขึ้น GitHub", glossary: glossary)
        #expect(result.text == "เดี๋ยว push code ขึ้น GitHub")
        #expect(result.changes.isEmpty)
    }

    @Test func spokenTimeBecomesDigits() {
        let result = policy.finalize("นัดกับพี่แบงก์ตอน ten AM", glossary: glossary)
        #expect(result.text == "นัดกับพี่แบงก์ตอน 10 AM")
        #expect(result.visibleChanges.map(\.description) == ["ten AM -> 10 AM (spoken time)"])
    }

    @Test func pullRequestStaysUntouched() {
        let result = policy.finalize("ส่ง pull request ให้ทีม", glossary: glossary)
        #expect(result.text == "ส่ง pull request ให้ทีม")
        #expect(result.changes.isEmpty)
    }

    @Test func thaiAliasUsesGlossaryWhenSaved() {
        let result = policy.finalize("ทำไซต์โปรเจกต์", glossary: glossary)
        #expect(result.text == "ทำ side-project")
        #expect(result.visibleChanges.first?.description == "ไซต์โปรเจกต์ -> side-project (glossary)")
    }

    @Test func thaiAliasStaysWithoutGlossary() {
        let result = policy.finalize("ทำไซต์โปรเจกต์", glossary: Glossary())
        #expect(result.text == "ทำไซต์โปรเจกต์")
        #expect(result.changes.isEmpty)
    }

    @Test func similarSoundingPhraseIsNotReplaced() {
        // "ไซต์งาน" (a work site) sounds similar but is not a saved alias.
        let result = policy.finalize("ไปดูไซต์งานก่อน", glossary: glossary)
        #expect(result.text == "ไปดูไซต์งานก่อน")
    }

    @Test(arguments: 1...20)
    func acceptanceCasesAreStableAcrossRuns(_ run: Int) {
        #expect(policy.finalize("วันนี้จะต้องกลับบ้านไปทำ side project", glossary: glossary).text
            == "วันนี้จะต้องกลับบ้านไปทำ side-project")
        #expect(policy.finalize("ทำไซต์โปรเจกต์", glossary: glossary).text == "ทำ side-project")
    }
}
