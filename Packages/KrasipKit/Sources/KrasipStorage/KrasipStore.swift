// KrasipStore.swift
// KrasipKit
// Opens the local SQLite database and hands out the glossary, history, and app-style stores.

import Foundation
import KrasipCore

public final class KrasipStore: Sendable {
    public let database: SQLiteDatabase
    public let glossary: GlossaryRepository
    public let history: HistoryStore
    public let appStyles: AppStyleRepository

    public init(database: SQLiteDatabase, repeatThreshold: Int = 2) throws {
        try Schema.migrate(database)
        self.database = database
        glossary = GlossaryRepository(database: database)
        history = HistoryStore(database: database, repeatThreshold: repeatThreshold)
        appStyles = AppStyleRepository(database: database)
    }

    public convenience init(url: URL) throws {
        try self.init(database: SQLiteDatabase(url: url))
    }

    public static func inMemory() throws -> KrasipStore {
        try KrasipStore(database: SQLiteDatabase())
    }

    /// ~/Library/Application Support/Krasip
    public static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Krasip", directoryHint: .isDirectory)
    }

    public static var defaultDatabaseURL: URL {
        supportDirectory.appending(path: "Krasip.sqlite")
    }

    /// Saved recordings live here only when "Keep audio for retry" is on.
    public static var audioDirectory: URL {
        supportDirectory.appending(path: "Audio", directoryHint: .isDirectory)
    }

    /// Where the app kept its files before it was renamed from WispFlow, so a glossary saved
    /// by that build can still be imported once.
    public static var previousSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "WispFlow", directoryHint: .isDirectory)
    }

    /// Adds the spec's example entry the first time the app runs.
    public func seedGlossaryIfEmpty(_ entries: [GlossaryEntry]) throws {
        guard try glossary.count == 0 else { return }
        try glossary.importEntries(entries)
    }
}
