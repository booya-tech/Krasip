// HistoryStore.swift
// KrasipKit
// The history module: records dictations locally, applies corrections, and spots repeated corrections.

import Foundation
import KrasipCore

public enum HistoryError: Error, Equatable, Sendable {
    case dictationNotFound
}

public final class HistoryStore: Sendable {
    /// How many separate corrections with the same change it takes before offering a rule.
    public let repeatThreshold: Int
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase, repeatThreshold: Int = 2) {
        self.database = database
        self.repeatThreshold = repeatThreshold
    }

    // MARK: - Spec interface

    /// `record(raw, final, destinationApp)`.
    @discardableResult
    public func record(raw: String, final: String, destinationApp: String?) throws -> DictationRecord {
        let record = DictationRecord(rawText: raw, finalText: final, destinationBundleID: destinationApp)
        try self.record(record)
        return record
    }

    /// `recent()`.
    public func recent(limit: Int = 200, matching search: String? = nil) throws -> [DictationRecord] {
        let trimmed = search?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return try database.query("\(Self.selectDictation) ORDER BY started_at DESC LIMIT ?", [.integer(Int64(limit))], map: Self.dictation)
        }
        let pattern = "%\(trimmed)%"
        return try database.query(
            "\(Self.selectDictation) WHERE final_text LIKE ? OR raw_text LIKE ? OR destination_app_name LIKE ? ORDER BY started_at DESC LIMIT ?",
            [.text(pattern), .text(pattern), .text(pattern), .integer(Int64(limit))],
            map: Self.dictation
        )
    }

    /// `applyCorrection(id, finalText)`. Saves the edit, updates the dictation, and returns
    /// glossary suggestions. A suggestion becomes an offer once the same change was made in
    /// `repeatThreshold` different corrections and no locked rule covers it yet.
    @discardableResult
    public func applyCorrection(id: UUID, finalText: String, glossary: Glossary = Glossary(), now: Date = .now) throws -> CorrectionOutcome {
        guard let dictation = try dictation(id: id) else { throw HistoryError.dictationNotFound }
        let correction = Correction(dictationID: id, beforeText: dictation.finalText, afterText: finalText, createdAt: now)
        guard dictation.finalText != finalText else {
            return CorrectionOutcome(correction: correction, suggestions: [], offers: [])
        }

        let suggestions = glossary.learnAll(before: dictation.finalText, after: finalText)
        try database.transaction {
            try database.run(
                "INSERT INTO corrections (id, dictation_id, before_text, after_text, accepted_suggestion, created_at, changed_word_count) VALUES (?, ?, ?, ?, 0, ?, ?)",
                [.uuid(correction.id), .uuid(id), .text(correction.beforeText), .text(correction.afterText), .date(now), .integer(Int64(correction.changedWordCount))]
            )
            try database.run(
                "UPDATE dictations SET final_text = ?, word_count = ?, correction_count = correction_count + 1 WHERE id = ?",
                [.text(finalText), .integer(Int64(WordSegmenter.wordCount(finalText))), .uuid(id)]
            )
            for suggestion in suggestions {
                try database.run(
                    "INSERT INTO correction_pairs (correction_id, pair_key, alias, preferred_output) VALUES (?, ?, ?, ?)",
                    [.uuid(correction.id), .text(suggestion.key), .text(suggestion.alias), .text(suggestion.preferredOutput)]
                )
            }
        }

        let dismissed = try dismissedKeys()
        let offers = try suggestions.compactMap { suggestion -> LearningOffer? in
            guard !glossary.alreadyKnows(suggestion), !dismissed.contains(suggestion.key) else { return nil }
            let occurrences = try occurrenceCount(of: suggestion.key)
            guard occurrences >= repeatThreshold else { return nil }
            return LearningOffer(suggestion: suggestion, occurrences: occurrences, correctionID: correction.id)
        }
        return CorrectionOutcome(correction: correction, suggestions: suggestions, offers: offers)
    }

    // MARK: - Records

    public func record(_ record: DictationRecord) throws {
        let changes = String(decoding: try JSONEncoder().encode(record.changes), as: UTF8.self)
        try database.run(
            """
            INSERT OR REPLACE INTO dictations (
                id, started_at, raw_text, final_text, policy_text, destination_bundle_id, destination_app_name,
                confidence, provider_id, audio_duration, latency, insertion, changes, audio_path, word_count, correction_count
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .uuid(record.id), .date(record.startedAt), .text(record.rawText), .text(record.finalText),
                .text(record.policyText), .optionalText(record.destinationBundleID), .optionalText(record.destinationAppName),
                .optionalReal(record.confidence), .text(record.providerID), .real(record.audioDuration),
                .optionalReal(record.latency), .optionalText(record.insertion?.storageValue), .text(changes),
                .optionalText(record.audioPath), .integer(Int64(record.wordCount)), .integer(Int64(record.correctionCount))
            ]
        )
    }

    public func dictation(id: UUID) throws -> DictationRecord? {
        try database.query("\(Self.selectDictation) WHERE id = ?", [.uuid(id)], map: Self.dictation).first
    }

    public func corrections(for dictationID: UUID) throws -> [Correction] {
        try database.query(
            "SELECT id, dictation_id, before_text, after_text, accepted_suggestion, created_at, changed_word_count FROM corrections WHERE dictation_id = ? ORDER BY created_at",
            [.uuid(dictationID)]
        ) { row in
            Correction(
                id: UUID(uuidString: row.string(0) ?? "") ?? UUID(),
                dictationID: UUID(uuidString: row.string(1) ?? "") ?? dictationID,
                beforeText: row.string(2) ?? "",
                afterText: row.string(3) ?? "",
                acceptedSuggestion: row.bool(4),
                createdAt: Date(timeIntervalSince1970: row.double(5) ?? 0),
                changedWordCount: row.int(6) ?? 0
            )
        }
    }

    /// Mark that the user turned this correction into a glossary rule.
    public func markSuggestionAccepted(correctionID: UUID) throws {
        try database.run("UPDATE corrections SET accepted_suggestion = 1 WHERE id = ?", [.uuid(correctionID)])
    }

    /// Stop offering this rule ("Don't ask again").
    public func dismissOffer(key: String, now: Date = .now) throws {
        try database.run("INSERT OR REPLACE INTO dismissed_offers (pair_key, dismissed_at) VALUES (?, ?)", [.text(key), .date(now)])
    }

    /// Repeated corrections that are not yet glossary rules, most frequent first.
    public func pendingOffers(glossary: Glossary) throws -> [LearningOffer] {
        let dismissed = try dismissedKeys()
        let rows = try database.query(
            """
            SELECT p.pair_key, p.alias, p.preferred_output, COUNT(DISTINCT p.correction_id), MAX(c.created_at),
                   (SELECT p2.correction_id FROM correction_pairs p2 JOIN corrections c2 ON c2.id = p2.correction_id
                    WHERE p2.pair_key = p.pair_key ORDER BY c2.created_at DESC LIMIT 1)
            FROM correction_pairs p JOIN corrections c ON c.id = p.correction_id
            GROUP BY p.pair_key
            HAVING COUNT(DISTINCT p.correction_id) >= ?
            ORDER BY COUNT(DISTINCT p.correction_id) DESC, MAX(c.created_at) DESC
            """,
            [.integer(Int64(repeatThreshold))]
        ) { row in
            (key: row.string(0) ?? "", alias: row.string(1) ?? "", output: row.string(2) ?? "", count: row.int(3) ?? 0, correctionID: row.string(5))
        }
        return rows.compactMap { row in
            guard !dismissed.contains(row.key), let correctionID = row.correctionID.flatMap(UUID.init(uuidString:)) else { return nil }
            let suggestion = glossary.learn(raw: row.alias, corrected: row.output)
                .map { Suggestion(alias: row.alias, preferredOutput: row.output, kind: $0.kind) }
                ?? Suggestion(alias: row.alias, preferredOutput: row.output, kind: .newEntry)
            guard !glossary.alreadyKnows(suggestion) else { return nil }
            return LearningOffer(suggestion: suggestion, occurrences: row.count, correctionID: correctionID)
        }
    }

    public func updateAudioPath(id: UUID, path: String?) throws {
        try database.run("UPDATE dictations SET audio_path = ? WHERE id = ?", [.optionalText(path), .uuid(id)])
    }

    // MARK: - Deleting

    /// Deletes one dictation and returns its saved audio path, if any, so the file can be removed.
    @discardableResult
    public func delete(id: UUID) throws -> String? {
        let path = try dictation(id: id)?.audioPath
        try database.run("DELETE FROM dictations WHERE id = ?", [.uuid(id)])
        return path
    }

    @discardableResult
    public func deleteAll() throws -> [String] {
        let paths = try audioPaths(where: "1 = 1", [])
        try database.transaction {
            try database.run("DELETE FROM dictations")
            try database.run("DELETE FROM dismissed_offers")
        }
        return paths
    }

    @discardableResult
    public func deleteOlderThan(_ date: Date) throws -> [String] {
        let paths = try audioPaths(where: "started_at < ?", [.date(date)])
        try database.run("DELETE FROM dictations WHERE started_at < ?", [.date(date)])
        return paths
    }

    /// Forgets every saved audio path and returns them so the files can be removed.
    @discardableResult
    public func removeAllAudioReferences() throws -> [String] {
        let paths = try audioPaths(where: "1 = 1", [])
        try database.run("UPDATE dictations SET audio_path = NULL")
        return paths
    }

    // MARK: - Stats

    public func stats(since date: Date? = nil) throws -> QualityStats {
        let start = Value.date(date ?? .distantPast)
        let totals = try database.query(
            """
            SELECT COUNT(*),
                   COALESCE(SUM(word_count), 0),
                   COALESCE(SUM(CASE WHEN insertion LIKE 'inserted.%' THEN 1 ELSE 0 END), 0),
                   COALESCE(SUM(CASE WHEN insertion LIKE 'inserted.%' OR (insertion LIKE 'copied.%' AND insertion != 'copied.userChoseCopy') THEN 1 ELSE 0 END), 0)
            FROM dictations WHERE started_at >= ?
            """,
            [start]
        ) { row in (row.int(0) ?? 0, row.int(1) ?? 0, row.int(2) ?? 0, row.int(3) ?? 0) }.first ?? (0, 0, 0, 0)

        let corrected = try database.query(
            "SELECT COALESCE(SUM(c.changed_word_count), 0) FROM corrections c JOIN dictations d ON d.id = c.dictation_id WHERE d.started_at >= ?",
            [start]
        ) { $0.int(0) ?? 0 }.first ?? 0

        let latencies = try database.query(
            "SELECT latency FROM dictations WHERE latency IS NOT NULL AND insertion LIKE 'inserted.%' AND started_at >= ?",
            [start]
        ) { $0.double(0) ?? 0 }

        return QualityStats(
            dictationCount: totals.0,
            insertionAttempts: totals.3,
            insertionSuccesses: totals.2,
            dictatedWords: totals.1,
            correctedWords: corrected,
            latencies: latencies
        )
    }

    // MARK: - Helpers

    private typealias Value = SQLiteDatabase.Value

    private func dismissedKeys() throws -> Set<String> {
        Set(try database.query("SELECT pair_key FROM dismissed_offers") { $0.string(0) ?? "" })
    }

    private func occurrenceCount(of key: String) throws -> Int {
        try database.query("SELECT COUNT(DISTINCT correction_id) FROM correction_pairs WHERE pair_key = ?", [.text(key)]) {
            $0.int(0) ?? 0
        }.first ?? 0
    }

    private func audioPaths(where condition: String, _ values: [Value]) throws -> [String] {
        try database.query("SELECT audio_path FROM dictations WHERE audio_path IS NOT NULL AND \(condition)", values) {
            $0.string(0) ?? ""
        }.filter { !$0.isEmpty }
    }

    private static let selectDictation = """
        SELECT id, started_at, raw_text, final_text, policy_text, destination_bundle_id, destination_app_name,
               confidence, provider_id, audio_duration, latency, insertion, changes, audio_path, word_count, correction_count
        FROM dictations
        """

    private static func dictation(_ row: SQLiteDatabase.Row) -> DictationRecord {
        let changes = (row.string(12).flatMap { try? JSONDecoder().decode([TextChange].self, from: Data($0.utf8)) }) ?? []
        return DictationRecord(
            id: UUID(uuidString: row.string(0) ?? "") ?? UUID(),
            startedAt: Date(timeIntervalSince1970: row.double(1) ?? 0),
            rawText: row.string(2) ?? "",
            finalText: row.string(3) ?? "",
            policyText: row.string(4),
            destinationBundleID: row.string(5),
            destinationAppName: row.string(6),
            confidence: row.double(7),
            providerID: row.string(8) ?? "",
            audioDuration: row.double(9) ?? 0,
            latency: row.double(10),
            insertion: row.string(11).flatMap(InsertionResult.init(storageValue:)),
            changes: changes,
            audioPath: row.string(13),
            wordCount: row.int(14) ?? 0,
            correctionCount: row.int(15) ?? 0
        )
    }
}
