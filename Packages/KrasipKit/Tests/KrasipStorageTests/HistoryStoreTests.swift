// HistoryStoreTests.swift
// KrasipStorageTests
// Local history: recording, searching, corrections, repeated-correction offers, deletion, and stats.

import Foundation
import Testing
@testable import KrasipCore
@testable import KrasipStorage

struct HistoryStoreTests {
    private let store = try! KrasipStore.inMemory()

    private func dictation(_ final: String, raw: String? = nil, at date: Date = .now, insertion: InsertionResult = .inserted(.paste), latency: TimeInterval? = 0.8) -> DictationRecord {
        DictationRecord(
            startedAt: date,
            rawText: raw ?? final,
            finalText: final,
            destinationBundleID: "com.apple.Notes",
            destinationAppName: "Notes",
            confidence: 0.9,
            providerID: "fixture",
            audioDuration: 2,
            latency: latency,
            insertion: insertion,
            changes: [TextChange(id: "glossary#0", kind: .glossary, before: "side project", after: "side-project")]
        )
    }

    @Test func recordsAndReadsBackEveryField() throws {
        let record = dictation("วันนี้จะต้องกลับบ้านไปทำ side-project", raw: "วันนี้จะต้องกลับบ้านไปทำ side project")
        try store.history.record(record)
        let loaded = try #require(try store.history.dictation(id: record.id))
        #expect(loaded.rawText == record.rawText)
        #expect(loaded.finalText == record.finalText)
        #expect(loaded.policyText == record.finalText)
        #expect(loaded.destinationBundleID == "com.apple.Notes")
        #expect(loaded.confidence == 0.9)
        #expect(loaded.insertion == .inserted(.paste))
        #expect(loaded.changes.map(\.description) == ["side project -> side-project (glossary)"])
        #expect(loaded.wordCount == record.wordCount)
    }

    @Test func specRecordSignatureWorks() throws {
        try store.history.record(raw: "ส่ง pull request", final: "ส่ง pull request", destinationApp: "com.tinyspeck.slackmacgap")
        let recent = try store.history.recent()
        #expect(recent.count == 1)
        #expect(recent[0].destinationBundleID == "com.tinyspeck.slackmacgap")
    }

    @Test func recentIsNewestFirstAndSearchable() throws {
        try store.history.record(dictation("แรก push code", at: Date(timeIntervalSince1970: 100)))
        try store.history.record(dictation("ที่สอง GitHub", at: Date(timeIntervalSince1970: 200)))
        #expect(try store.history.recent().map(\.finalText) == ["ที่สอง GitHub", "แรก push code"])
        #expect(try store.history.recent(matching: "GitHub").map(\.finalText) == ["ที่สอง GitHub"])
    }

    @Test func correctionUpdatesFinalTextAndKeepsBefore() throws {
        let record = dictation("ทำไซต์โปรเจกต์")
        try store.history.record(record)
        let outcome = try store.history.applyCorrection(id: record.id, finalText: "ทำ side-project")

        #expect(outcome.correction.beforeText == "ทำไซต์โปรเจกต์")
        #expect(outcome.correction.afterText == "ทำ side-project")
        #expect(outcome.suggestions.first?.alias == "ไซต์โปรเจกต์")
        #expect(outcome.offers.isEmpty)

        let loaded = try #require(try store.history.dictation(id: record.id))
        #expect(loaded.finalText == "ทำ side-project")
        #expect(loaded.policyText == "ทำไซต์โปรเจกต์")
        #expect(loaded.correctionCount == 1)
        #expect(try store.history.corrections(for: record.id).count == 1)
    }

    @Test func repeatedCorrectionBecomesAnOffer() throws {
        let first = dictation("ทำไซต์โปรเจกต์ก่อน")
        let second = dictation("เดี๋ยวไปทำไซต์โปรเจกต์")
        try store.history.record(first)
        try store.history.record(second)

        let once = try store.history.applyCorrection(id: first.id, finalText: "ทำ side-project ก่อน")
        #expect(once.offers.isEmpty)
        let twice = try store.history.applyCorrection(id: second.id, finalText: "เดี๋ยวไปทำ side-project")
        #expect(twice.offers.count == 1)
        #expect(twice.offers.first?.occurrences == 2)
        #expect(twice.offers.first?.suggestion.alias == "ไซต์โปรเจกต์")
        #expect(twice.offers.first?.suggestion.preferredOutput == "side-project")

        #expect(try store.history.pendingOffers(glossary: Glossary()).map(\.suggestion.preferredOutput) == ["side-project"])
    }

    @Test func knownRulesAreNotOfferedAgain() throws {
        let first = dictation("ทำไซต์โปรเจกต์ก่อน")
        let second = dictation("ไปทำไซต์โปรเจกต์")
        try store.history.record(first)
        try store.history.record(second)
        let glossary = Glossary([GlossaryEntry(aliases: ["ไซต์โปรเจกต์"], preferredOutput: "side-project")])
        try store.history.applyCorrection(id: first.id, finalText: "ทำ side-project ก่อน", glossary: glossary)
        let outcome = try store.history.applyCorrection(id: second.id, finalText: "ไปทำ side-project", glossary: glossary)
        #expect(outcome.offers.isEmpty)
        #expect(try store.history.pendingOffers(glossary: glossary).isEmpty)
    }

    @Test func dismissedOffersStayDismissed() throws {
        let first = dictation("ขึ้น กิตฮับ")
        let second = dictation("push ขึ้น กิตฮับ")
        try store.history.record(first)
        try store.history.record(second)
        try store.history.applyCorrection(id: first.id, finalText: "ขึ้น GitHub")
        let outcome = try store.history.applyCorrection(id: second.id, finalText: "push ขึ้น GitHub")
        let offer = try #require(outcome.offers.first)
        try store.history.dismissOffer(key: offer.suggestion.key)
        #expect(try store.history.pendingOffers(glossary: Glossary()).isEmpty)
    }

    @Test func unchangedCorrectionIsANoOp() throws {
        let record = dictation("เหมือนเดิม")
        try store.history.record(record)
        let outcome = try store.history.applyCorrection(id: record.id, finalText: "เหมือนเดิม")
        #expect(outcome.suggestions.isEmpty)
        #expect(try store.history.corrections(for: record.id).isEmpty)
    }

    @Test func correctingUnknownDictationThrows() {
        #expect(throws: HistoryError.dictationNotFound) {
            try store.history.applyCorrection(id: UUID(), finalText: "x")
        }
    }

    @Test func deletingRemovesCorrectionsAndReturnsAudio() throws {
        var record = dictation("มีเสียง")
        record.audioPath = "/tmp/a.m4a"
        try store.history.record(record)
        try store.history.applyCorrection(id: record.id, finalText: "มีเสียงแล้ว")
        #expect(try store.history.delete(id: record.id) == "/tmp/a.m4a")
        #expect(try store.history.dictation(id: record.id) == nil)
        #expect(try store.history.corrections(for: record.id).isEmpty)
    }

    @Test func retentionDeletesOldDictations() throws {
        try store.history.record(dictation("เก่า", at: Date(timeIntervalSince1970: 10)))
        try store.history.record(dictation("ใหม่", at: Date(timeIntervalSince1970: 1_000)))
        try store.history.deleteOlderThan(Date(timeIntervalSince1970: 500))
        #expect(try store.history.recent().map(\.finalText) == ["ใหม่"])
    }

    @Test func statsMatchQualityPlanDefinitions() throws {
        let inserted = dictation("เดี๋ยว push code ขึ้น GitHub", latency: 1.0)
        let copied = dictation("ส่ง pull request ให้ทีม", insertion: .copiedToClipboard(.appRejected), latency: nil)
        let userCopy = dictation("ก็อปเอง", insertion: .copiedToClipboard(.userChoseCopy), latency: nil)
        try store.history.record(inserted)
        try store.history.record(copied)
        try store.history.record(userCopy)
        try store.history.applyCorrection(id: inserted.id, finalText: "เดี๋ยว push code ขึ้น GitHub แล้ว")

        let stats = try store.history.stats()
        #expect(stats.dictationCount == 3)
        #expect(stats.insertionAttempts == 2)
        #expect(stats.insertionSuccesses == 1)
        #expect(stats.insertionSuccessRate == 0.5)
        #expect(stats.latencies == [1.0])
        #expect(stats.correctedWords >= 1)
        #expect((stats.correctionRate ?? 0) > 0)
    }
}
