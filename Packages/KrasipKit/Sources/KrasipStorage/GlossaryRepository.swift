// GlossaryRepository.swift
// KrasipKit
// Saves glossary entries in SQLite and merges imported entries without duplicates.

import Foundation
import KrasipCore

public struct GlossaryImportSummary: Equatable, Sendable {
    public var added: Int
    public var updated: Int
}

public final class GlossaryRepository: Sendable {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    public func all() throws -> [GlossaryEntry] {
        try database.query(
            "SELECT id, aliases, preferred_output, mode, created_at, updated_at FROM glossary_entries ORDER BY preferred_output COLLATE NOCASE"
        ) { row in
            let aliasesJSON = row.string(1) ?? "[]"
            let aliases = (try? JSONDecoder().decode([String].self, from: Data(aliasesJSON.utf8))) ?? []
            return GlossaryEntry(
                id: UUID(uuidString: row.string(0) ?? "") ?? UUID(),
                aliases: aliases,
                preferredOutput: row.string(2) ?? "",
                mode: GlossaryEntry.Mode(rawValue: row.string(3) ?? "") ?? .locked,
                createdAt: Date(timeIntervalSince1970: row.double(4) ?? 0),
                updatedAt: Date(timeIntervalSince1970: row.double(5) ?? 0)
            )
        }
    }

    public var count: Int {
        get throws {
            try database.query("SELECT COUNT(*) FROM glossary_entries") { $0.int(0) ?? 0 }.first ?? 0
        }
    }

    public func upsert(_ entry: GlossaryEntry) throws {
        let aliases = String(decoding: try JSONEncoder().encode(entry.aliases), as: UTF8.self)
        try database.run(
            """
            INSERT INTO glossary_entries (id, aliases, preferred_output, mode, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                aliases = excluded.aliases,
                preferred_output = excluded.preferred_output,
                mode = excluded.mode,
                updated_at = excluded.updated_at
            """,
            [
                .uuid(entry.id), .text(aliases), .text(entry.preferredOutput), .text(entry.mode.rawValue),
                .date(entry.createdAt), .date(entry.updatedAt)
            ]
        )
    }

    public func delete(id: UUID) throws {
        try database.run("DELETE FROM glossary_entries WHERE id = ?", [.uuid(id)])
    }

    /// Adds imported entries. An entry with the same id or the same preferred output is merged
    /// into the existing one (aliases combined) instead of being duplicated.
    @discardableResult
    public func importEntries(_ entries: [GlossaryEntry], now: Date = .now) throws -> GlossaryImportSummary {
        try database.transaction {
            var existing = try all()
            var summary = GlossaryImportSummary(added: 0, updated: 0)
            for incoming in entries where !incoming.preferredOutput.isEmpty && !incoming.aliases.isEmpty {
                if let index = existing.firstIndex(where: { $0.id == incoming.id || $0.preferredOutput == incoming.preferredOutput }) {
                    var merged = existing[index]
                    merged.aliases = GlossaryEntry.cleanAliases(merged.aliases + incoming.aliases)
                    merged.mode = incoming.mode
                    merged.updatedAt = now
                    try upsert(merged)
                    existing[index] = merged
                    summary.updated += 1
                } else {
                    try upsert(incoming)
                    existing.append(incoming)
                    summary.added += 1
                }
            }
            return summary
        }
    }
}
