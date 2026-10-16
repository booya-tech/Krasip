// TextStyle.swift
// KrasipKit
// Formatting choices the text policy applies. Spacing and spoken times always run; punctuation can differ per destination app.

import Foundation

/// What the policy does with punctuation the speech recognizer produced.
public enum PunctuationMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Keep punctuation exactly as transcribed.
    case keep
    /// Drop a single trailing period, which reads oddly in chat apps and Thai text.
    case noTrailingPeriod
    /// Remove sentence punctuation (. , ! ? ; :) outside protected spans.
    case none

    public var id: String { rawValue }
}

public struct TextStyle: Codable, Equatable, Hashable, Sendable {
    public var punctuation: PunctuationMode
    /// Offer glossary spellings for Thai words that sound like a saved alias (always asks first).
    public var suggestSoundAlikes: Bool

    public init(
        punctuation: PunctuationMode = .keep,
        suggestSoundAlikes: Bool = true
    ) {
        self.punctuation = punctuation
        self.suggestSoundAlikes = suggestSoundAlikes
    }

    public static let standard = TextStyle()
}

/// Per-app behavior, keyed by the destination app's bundle identifier.
public struct AppStyle: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var bundleID: String
    public var appName: String?
    /// `nil` means "use the global punctuation setting".
    public var punctuationMode: PunctuationMode?
    /// When false, Krasip always shows the text for review before inserting in this app.
    public var autoInsert: Bool

    public var id: String { bundleID }

    public init(bundleID: String, appName: String? = nil, punctuationMode: PunctuationMode? = nil, autoInsert: Bool = true) {
        self.bundleID = bundleID
        self.appName = appName
        self.punctuationMode = punctuationMode
        self.autoInsert = autoInsert
    }

    public func applied(to style: TextStyle) -> TextStyle {
        var result = style
        if let punctuationMode {
            result.punctuation = punctuationMode
        }
        return result
    }
}
