// TextStyle.swift
// KrasipKit
// Formatting choices the text policy applies, globally or per destination app.

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
    /// Insert one space where Thai text touches English words or digits ("ทำside" → "ทำ side").
    public var spaceBetweenThaiAndLatin: Bool
    /// Turn spoken English clock times into digits ("ten AM" → "10 AM").
    public var convertSpokenTimes: Bool
    /// Turn Thai clock times into digits ("สิบโมงเช้า" → "10:00").
    public var convertThaiTimes: Bool
    /// Offer glossary spellings for Thai words that sound like a saved alias (always asks first).
    public var suggestSoundAlikes: Bool

    public init(
        punctuation: PunctuationMode = .keep,
        spaceBetweenThaiAndLatin: Bool = true,
        convertSpokenTimes: Bool = true,
        convertThaiTimes: Bool = false,
        suggestSoundAlikes: Bool = true
    ) {
        self.punctuation = punctuation
        self.spaceBetweenThaiAndLatin = spaceBetweenThaiAndLatin
        self.convertSpokenTimes = convertSpokenTimes
        self.convertThaiTimes = convertThaiTimes
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
