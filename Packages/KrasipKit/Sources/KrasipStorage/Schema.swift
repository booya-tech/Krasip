// Schema.swift
// KrasipKit
// Versioned SQLite schema for glossary entries, dictations, corrections, and per-app styles.

import Foundation

enum Schema {
    static let migrations: [String] = [
        """
        CREATE TABLE glossary_entries (
            id TEXT PRIMARY KEY,
            aliases TEXT NOT NULL,
            preferred_output TEXT NOT NULL,
            mode TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );

        CREATE TABLE dictations (
            id TEXT PRIMARY KEY,
            started_at REAL NOT NULL,
            raw_text TEXT NOT NULL,
            final_text TEXT NOT NULL,
            policy_text TEXT NOT NULL,
            destination_bundle_id TEXT,
            destination_app_name TEXT,
            confidence REAL,
            provider_id TEXT NOT NULL,
            audio_duration REAL NOT NULL DEFAULT 0,
            latency REAL,
            insertion TEXT,
            changes TEXT NOT NULL DEFAULT '[]',
            audio_path TEXT,
            word_count INTEGER NOT NULL DEFAULT 0,
            correction_count INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX dictations_started_at ON dictations(started_at DESC);

        CREATE TABLE corrections (
            id TEXT PRIMARY KEY,
            dictation_id TEXT NOT NULL REFERENCES dictations(id) ON DELETE CASCADE,
            before_text TEXT NOT NULL,
            after_text TEXT NOT NULL,
            accepted_suggestion INTEGER NOT NULL DEFAULT 0,
            created_at REAL NOT NULL,
            changed_word_count INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX corrections_dictation ON corrections(dictation_id);

        CREATE TABLE correction_pairs (
            correction_id TEXT NOT NULL REFERENCES corrections(id) ON DELETE CASCADE,
            pair_key TEXT NOT NULL,
            alias TEXT NOT NULL,
            preferred_output TEXT NOT NULL
        );
        CREATE INDEX correction_pairs_key ON correction_pairs(pair_key);

        CREATE TABLE dismissed_offers (
            pair_key TEXT PRIMARY KEY,
            dismissed_at REAL NOT NULL
        );

        CREATE TABLE app_styles (
            bundle_id TEXT PRIMARY KEY,
            app_name TEXT,
            punctuation_mode TEXT,
            auto_insert INTEGER NOT NULL DEFAULT 1
        );
        """
    ]

    static func migrate(_ database: SQLiteDatabase) throws {
        let current = try database.userVersion
        guard current < migrations.count else { return }
        for version in current..<migrations.count {
            try database.transaction {
                try database.execute(migrations[version])
                try database.setUserVersion(version + 1)
            }
        }
    }
}
