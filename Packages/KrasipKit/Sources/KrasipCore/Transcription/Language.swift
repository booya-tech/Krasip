// Language.swift
// KrasipKit
// Languages the dictation pipeline can recognize.

import Foundation

public enum Language: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case thai
    case english

    public var id: String { rawValue }

    /// ISO 639-1 code, as used by cloud transcription APIs.
    public var isoCode: String {
        switch self {
        case .thai: "th"
        case .english: "en"
        }
    }

    public var localeIdentifier: String {
        switch self {
        case .thai: "th-TH"
        case .english: "en-US"
        }
    }

    public var displayName: String {
        switch self {
        case .thai: "Thai"
        case .english: "English"
        }
    }

    /// The recognizer locale to use for a language set. Thai wins when mixed, because a Thai
    /// model hears English loanwords far better than an English model hears Thai.
    public static func primary(of languages: [Language]) -> Language {
        languages.contains(.thai) || languages.isEmpty ? .thai : .english
    }
}
