// GlossaryJSONTests.swift
// KrasipCoreTests
// Glossary import/export uses the spec's JSON shape.

import Foundation
import Testing
@testable import KrasipCore

struct GlossaryJSONTests {
    @Test func decodesTheSpecExample() throws {
        let json = """
        {
          "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
          "aliases": ["side project", "ไซต์โปรเจกต์", "ไซด์โปรเจกต์"],
          "preferredOutput": "side-project",
          "mode": "locked",
          "createdAt": "2026-09-22T10:00:00Z"
        }
        """
        let entries = try GlossaryJSON.decode(Data(json.utf8))
        #expect(entries.count == 1)
        #expect(entries[0].preferredOutput == "side-project")
        #expect(entries[0].aliases.count == 3)
        #expect(entries[0].mode == .locked)
        #expect(entries[0].updatedAt == entries[0].createdAt)
    }

    @Test func roundTripsEntries() throws {
        let entries = [
            AcceptanceTests.sideProject,
            GlossaryEntry(aliases: ["กิตฮับ"], preferredOutput: "GitHub", mode: .suggest)
        ]
        let decoded = try GlossaryJSON.decode(GlossaryJSON.encode(entries))
        #expect(decoded.map(\.id) == entries.map(\.id))
        #expect(decoded.map(\.mode) == [.locked, .suggest])
    }

    @Test func acceptsWrappedListAndFractionalDates() throws {
        let json = """
        {"entries": [{"aliases": ["พีอาร์"], "preferredOutput": "PR", "createdAt": "2026-09-22T10:00:00.123Z"}]}
        """
        let entries = try GlossaryJSON.decode(Data(json.utf8))
        #expect(entries.first?.preferredOutput == "PR")
        #expect(entries.first?.mode == .locked)
    }

    @Test func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            try GlossaryJSON.decode(Data("not json".utf8))
        }
    }
}
