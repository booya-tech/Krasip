// GlossaryJSON.swift
// KrasipKit
// Imports and exports glossary entries in the spec's JSON shape (ISO-8601 dates).

import Foundation

public enum GlossaryJSON {
    public static func encode(_ entries: [GlossaryEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(entries)
    }

    /// Accepts a list of entries, a single entry, or an object with an `entries` list.
    public static func decode(_ data: Data) throws -> [GlossaryEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = parseDate(text) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected an ISO-8601 date, got \(text)")
        }

        if let entries = try? decoder.decode([GlossaryEntry].self, from: data) {
            return entries
        }
        if let entry = try? decoder.decode(GlossaryEntry.self, from: data) {
            return [entry]
        }
        struct Wrapper: Decodable { let entries: [GlossaryEntry] }
        return try decoder.decode(Wrapper.self, from: data).entries
    }

    private static func parseDate(_ text: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: text) { return date }
        let dateOnly = ISO8601DateFormatter()
        dateOnly.formatOptions = [.withFullDate]
        return dateOnly.date(from: text)
    }
}
