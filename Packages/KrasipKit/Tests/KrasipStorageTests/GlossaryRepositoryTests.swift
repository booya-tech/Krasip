// GlossaryRepositoryTests.swift
// KrasipStorageTests
// Glossary persistence, import merging, first-run seeding, per-app styles, and on-disk reopening.

import Foundation
import Testing
@testable import KrasipCore
@testable import KrasipStorage

struct GlossaryRepositoryTests {
    private let store = try! KrasipStore.inMemory()

    private let sideProject = GlossaryEntry(
        aliases: ["side project", "ไซต์โปรเจกต์", "ไซด์โปรเจกต์"],
        preferredOutput: "side-project"
    )

    @Test func savesAndLoadsEntries() throws {
        try store.glossary.upsert(sideProject)
        let loaded = try store.glossary.all()
        #expect(loaded.count == 1)
        #expect(loaded[0].id == sideProject.id)
        #expect(loaded[0].aliases == sideProject.aliases)
        #expect(loaded[0].mode == .locked)
    }

    @Test func upsertUpdatesInPlace() throws {
        try store.glossary.upsert(sideProject)
        var edited = sideProject
        edited.mode = .suggest
        edited.aliases.append("ไซด์โปรเจ็กต์")
        try store.glossary.upsert(edited)
        let loaded = try store.glossary.all()
        #expect(loaded.count == 1)
        #expect(loaded[0].mode == .suggest)
        #expect(loaded[0].aliases.count == 4)
    }

    @Test func deleteRemovesEntry() throws {
        try store.glossary.upsert(sideProject)
        try store.glossary.delete(id: sideProject.id)
        #expect(try store.glossary.all().isEmpty)
    }

    @Test func importMergesSamePreferredOutput() throws {
        try store.glossary.upsert(sideProject)
        let incoming = [
            GlossaryEntry(aliases: ["ไซด์โปรเจ็กต์"], preferredOutput: "side-project"),
            GlossaryEntry(aliases: ["กิตฮับ"], preferredOutput: "GitHub")
        ]
        let summary = try store.glossary.importEntries(incoming)
        #expect(summary == GlossaryImportSummary(added: 1, updated: 1))
        let loaded = try store.glossary.all()
        #expect(loaded.count == 2)
        #expect(loaded.first { $0.preferredOutput == "side-project" }?.aliases.count == 4)
    }

    @Test func seedsOnlyOnce() throws {
        try store.seedGlossaryIfEmpty([sideProject])
        try store.seedGlossaryIfEmpty([GlossaryEntry(aliases: ["x"], preferredOutput: "y")])
        #expect(try store.glossary.all().map(\.preferredOutput) == ["side-project"])
    }

    @Test func appStylesRoundTrip() throws {
        try store.appStyles.upsert(AppStyle(bundleID: "com.tinyspeck.slackmacgap", appName: "Slack", punctuationMode: .noTrailingPeriod, autoInsert: true))
        try store.appStyles.upsert(AppStyle(bundleID: "com.apple.mail", appName: "Mail", punctuationMode: nil, autoInsert: false))
        let styles = try store.appStyles.all()
        #expect(styles.map(\.appName) == ["Mail", "Slack"])
        #expect(try store.appStyles.style(for: "com.tinyspeck.slackmacgap")?.punctuationMode == .noTrailingPeriod)
        #expect(try store.appStyles.style(for: "com.apple.mail")?.autoInsert == false)
        try store.appStyles.delete(bundleID: "com.apple.mail")
        #expect(try store.appStyles.all().count == 1)
    }

    @Test func dataSurvivesReopeningTheFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "krasip-test-\(UUID().uuidString)")
            .appending(path: "Krasip.sqlite")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        do {
            let first = try KrasipStore(url: url)
            try first.glossary.upsert(sideProject)
            try first.history.record(raw: "ทำ side project", final: "ทำ side-project", destinationApp: "com.apple.Notes")
        }
        let reopened = try KrasipStore(url: url)
        #expect(try reopened.glossary.all().map(\.preferredOutput) == ["side-project"])
        #expect(try reopened.history.recent().count == 1)
        #expect(try reopened.database.userVersion == 1)
    }
}
