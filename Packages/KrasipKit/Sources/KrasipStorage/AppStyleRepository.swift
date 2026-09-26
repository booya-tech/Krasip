// AppStyleRepository.swift
// KrasipKit
// Saves per-app punctuation and auto-insert choices, keyed by bundle identifier.

import Foundation
import KrasipCore

public final class AppStyleRepository: Sendable {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
    }

    public func all() throws -> [AppStyle] {
        try database.query(
            "SELECT bundle_id, app_name, punctuation_mode, auto_insert FROM app_styles ORDER BY COALESCE(app_name, bundle_id) COLLATE NOCASE"
        ) { row in
            AppStyle(
                bundleID: row.string(0) ?? "",
                appName: row.string(1),
                punctuationMode: row.string(2).flatMap(PunctuationMode.init(rawValue:)),
                autoInsert: row.bool(3)
            )
        }
    }

    public func style(for bundleID: String) throws -> AppStyle? {
        try all().first { $0.bundleID == bundleID }
    }

    public func upsert(_ style: AppStyle) throws {
        try database.run(
            """
            INSERT INTO app_styles (bundle_id, app_name, punctuation_mode, auto_insert) VALUES (?, ?, ?, ?)
            ON CONFLICT(bundle_id) DO UPDATE SET
                app_name = excluded.app_name,
                punctuation_mode = excluded.punctuation_mode,
                auto_insert = excluded.auto_insert
            """,
            [.text(style.bundleID), .optionalText(style.appName), .optionalText(style.punctuationMode?.rawValue), .bool(style.autoInsert)]
        )
    }

    public func delete(bundleID: String) throws {
        try database.run("DELETE FROM app_styles WHERE bundle_id = ?", [.text(bundleID)])
    }
}
