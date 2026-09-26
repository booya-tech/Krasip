// FinalText.swift
// KrasipKit
// Output of the text policy: final text, every change made, and suggestions waiting for the user.

import Foundation

/// One explainable edit the policy made, e.g. `side project -> side-project (glossary)`.
public struct TextChange: Codable, Equatable, Hashable, Identifiable, Sendable, CustomStringConvertible {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case normalization
        case glossary
        case spokenTime
        case spacing
        case punctuation

        public var label: String {
            switch self {
            case .normalization: "cleanup"
            case .glossary: "glossary"
            case .spokenTime: "spoken time"
            case .spacing: "spacing"
            case .punctuation: "punctuation"
            }
        }
    }

    public var id: String
    public var kind: Kind
    public var before: String
    public var after: String
    public var entryID: UUID?

    public init(id: String, kind: Kind, before: String, after: String, entryID: UUID? = nil) {
        self.id = id
        self.kind = kind
        self.before = before
        self.after = after
        self.entryID = entryID
    }

    public var description: String { "\(before) -> \(after) (\(kind.label))" }

    /// Cleanup changes (Unicode, repeated spaces) are recorded but shown less prominently.
    public var isCosmetic: Bool { kind == .normalization }
}

/// A piece of the final text and where it came from.
public struct TextSegment: Equatable, Sendable {
    public enum Origin: Equatable, Sendable {
        case transcript
        case glossary(UUID)
        case spokenTime
        case insertedSpace
    }

    /// Protected spans are never reformatted, translated, or respelled by later rules.
    public enum Protection: String, Equatable, Sendable {
        case none
        case latinWord
        case number
        case url
        case email
        case code
        case glossaryOutput
        case spokenTime
    }

    public var text: String
    public var origin: Origin
    public var protection: Protection
    /// Set when this transcript span matches a `suggest` glossary entry.
    public var suggestionEntryID: UUID?
    /// The suggestion comes from a sound-alike spelling rather than an exact alias.
    public var suggestionIsSoundAlike: Bool

    public init(
        text: String,
        origin: Origin,
        protection: Protection = .none,
        suggestionEntryID: UUID? = nil,
        suggestionIsSoundAlike: Bool = false
    ) {
        self.text = text
        self.origin = origin
        self.protection = protection
        self.suggestionEntryID = suggestionEntryID
        self.suggestionIsSoundAlike = suggestionIsSoundAlike
    }

    public var isProtected: Bool { protection != .none }
}

/// A `suggest` entry that matched but was not applied. The user decides.
public struct PendingSuggestion: Equatable, Hashable, Identifiable, Sendable {
    public var entryID: UUID
    public var matchedText: String
    public var preferredOutput: String
    /// Character offsets in the final text.
    public var range: Range<Int>
    /// Spelled differently from every alias but sounds the same.
    public var isSoundAlike: Bool

    public init(entryID: UUID, matchedText: String, preferredOutput: String, range: Range<Int>, isSoundAlike: Bool = false) {
        self.entryID = entryID
        self.matchedText = matchedText
        self.preferredOutput = preferredOutput
        self.range = range
        self.isSoundAlike = isSoundAlike
    }

    public var id: String { "\(entryID.uuidString):\(range.lowerBound)" }
}

/// Choices the user made about one dictation, fed back into `TextPolicy.finalize`.
public struct PolicyDecisions: Equatable, Hashable, Sendable {
    /// `suggest` entries the user accepted for this text.
    public var acceptedSuggestions: Set<UUID>
    /// Entries whose sound-alike spellings the user accepted for this text.
    public var acceptedSoundAlikes: Set<UUID>
    /// Glossary entries the user undid for this text.
    public var revertedEntries: Set<UUID>
    /// Built-in rules the user undid for this text.
    public var disabledKinds: Set<TextChange.Kind>

    public init(
        acceptedSuggestions: Set<UUID> = [],
        acceptedSoundAlikes: Set<UUID> = [],
        revertedEntries: Set<UUID> = [],
        disabledKinds: Set<TextChange.Kind> = []
    ) {
        self.acceptedSuggestions = acceptedSuggestions
        self.acceptedSoundAlikes = acceptedSoundAlikes
        self.revertedEntries = revertedEntries
        self.disabledKinds = disabledKinds
    }

    /// Accepts a pending suggestion for this text.
    public mutating func accept(_ suggestion: PendingSuggestion) {
        acceptedSuggestions.insert(suggestion.entryID)
        if suggestion.isSoundAlike {
            acceptedSoundAlikes.insert(suggestion.entryID)
        }
        revertedEntries.remove(suggestion.entryID)
    }

    /// The decision that undoes `change`.
    public mutating func undo(_ change: TextChange) {
        if change.kind == .glossary, let entryID = change.entryID {
            revertedEntries.insert(entryID)
            acceptedSuggestions.remove(entryID)
            acceptedSoundAlikes.remove(entryID)
        } else {
            disabledKinds.insert(change.kind)
        }
    }
}

public struct FinalText: Equatable, Sendable {
    public var rawText: String
    public var text: String
    public var changes: [TextChange]
    public var suggestions: [PendingSuggestion]
    public var segments: [TextSegment]

    /// Changes worth showing to the user (glossary, times, spacing, punctuation).
    public var visibleChanges: [TextChange] { changes.filter { !$0.isCosmetic } }

    /// Character ranges in `text` produced by glossary rules, for highlighting.
    public var glossaryRanges: [Range<Int>] {
        var offset = 0
        var ranges: [Range<Int>] = []
        for segment in segments {
            let length = segment.text.count
            if case .glossary = segment.origin {
                ranges.append(offset..<(offset + length))
            }
            offset += length
        }
        return ranges
    }
}
