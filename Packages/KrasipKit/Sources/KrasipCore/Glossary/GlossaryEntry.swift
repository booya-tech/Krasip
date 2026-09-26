// GlossaryEntry.swift
// KrasipKit
// One user-owned preferred spelling and the spoken or transcribed aliases that map to it.

import Foundation

public struct GlossaryEntry: Codable, Equatable, Hashable, Identifiable, Sendable {
    /// `locked` always replaces, `suggest` asks first, `disabled` keeps the entry but never replaces.
    public enum Mode: String, Codable, CaseIterable, Identifiable, Sendable {
        case locked
        case suggest
        case disabled

        public var id: String { rawValue }
    }

    public let id: UUID
    public var aliases: [String]
    public var preferredOutput: String
    public var mode: Mode
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        aliases: [String],
        preferredOutput: String,
        mode: Mode = .locked,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.aliases = Self.cleanAliases(aliases)
        self.preferredOutput = preferredOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mode = mode
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, aliases, preferredOutput, mode, createdAt, updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            aliases: try container.decode([String].self, forKey: .aliases),
            preferredOutput: try container.decode(String.self, forKey: .preferredOutput),
            mode: try container.decodeIfPresent(Mode.self, forKey: .mode) ?? .locked,
            createdAt: createdAt,
            updatedAt: try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        )
    }

    /// Trims aliases and drops empty ones and duplicates that normalize to the same key.
    public static func cleanAliases(_ aliases: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for alias in aliases {
            let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = MatchText.keyString(trimmed)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }

    /// Aliases made only of one or two Thai characters can match inside unrelated words.
    public var riskyAliases: [String] {
        aliases.filter { alias in
            let key = MatchText.key(alias)
            return key.allSatisfy(\.isThai) && alias.count <= 2
        }
    }
}

extension GlossaryEntry.Mode {
    public var replacesAutomatically: Bool { self == .locked }
}
