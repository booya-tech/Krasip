// AppSettings.swift
// Krasip
// User preferences saved in UserDefaults and turned into settings for the dictation flow.

import Foundation
import Observation
import KrasipCore
import KrasipSystem

enum SpeechEngine: String, CaseIterable, Identifiable, Codable {
    /// macOS 26+: Thai recognized fully on this Mac.
    case appleOnDevice
    /// Apple's server-based recognizer (SFSpeechRecognizer).
    case appleOnline
    /// OpenAI-compatible cloud transcription with the user's API key.
    case openAI

    var id: String { rawValue }

    var isAvailable: Bool {
        switch self {
        case .appleOnDevice:
            if #available(macOS 26.0, *) { return true }
            return false
        case .appleOnline, .openAI:
            return true
        }
    }

    static var available: [SpeechEngine] { allCases.filter(\.isAvailable) }

    static var recommended: SpeechEngine {
        SpeechEngine.appleOnDevice.isAvailable ? .appleOnDevice : .appleOnline
    }

    var transcriberID: TranscriberID {
        switch self {
        case .appleOnDevice: .appleOnDevice
        case .appleOnline: .appleServer
        case .openAI: .openAI
        }
    }

    init?(transcriberID: String) {
        guard let engine = SpeechEngine.allCases.first(where: { $0.transcriberID.rawValue == transcriberID }) else { return nil }
        self = engine
    }
}

enum HistoryRetention: Int, CaseIterable, Identifiable {
    case forever = 0
    case quarter = 90
    case month = 30
    case week = 7
    case day = 1

    var id: Int { rawValue }
}

@MainActor
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var hotkey: KeyCombo { didSet { encode(hotkey, for: Key.hotkey) } }
    var handsFreeOnQuickTap: Bool { didSet { defaults.set(handsFreeOnQuickTap, forKey: Key.handsFree) } }
    var reviewBeforeInsert: Bool { didSet { defaults.set(reviewBeforeInsert, forKey: Key.reviewBeforeInsert) } }
    var lowConfidenceThreshold: Double { didSet { defaults.set(lowConfidenceThreshold, forKey: Key.lowConfidence) } }
    var insertionMode: TextInserter.Mode { didSet { defaults.set(insertionMode.rawValue, forKey: Key.insertionMode) } }
    var playSounds: Bool { didSet { defaults.set(playSounds, forKey: Key.playSounds) } }
    /// Core Audio UID of the chosen microphone; `nil` follows the system default.
    var inputDeviceUID: String? { didSet { defaults.set(inputDeviceUID, forKey: Key.inputDevice) } }

    var engine: SpeechEngine { didSet { defaults.set(engine.rawValue, forKey: Key.engine) } }
    var languages: [Language] { didSet { defaults.set(languages.map(\.rawValue), forKey: Key.languages) } }
    var openAIModel: String { didSet { defaults.set(openAIModel, forKey: Key.openAIModel) } }
    var openAIBaseURL: String { didSet { defaults.set(openAIBaseURL, forKey: Key.openAIBaseURL) } }
    var openAISendsLanguageHint: Bool { didSet { defaults.set(openAISendsLanguageHint, forKey: Key.openAILanguageHint) } }

    var spaceBetweenThaiAndLatin: Bool { didSet { defaults.set(spaceBetweenThaiAndLatin, forKey: Key.spacing) } }
    var convertSpokenTimes: Bool { didSet { defaults.set(convertSpokenTimes, forKey: Key.spokenTimes) } }
    var convertThaiTimes: Bool { didSet { defaults.set(convertThaiTimes, forKey: Key.thaiTimes) } }
    var suggestSoundAlikes: Bool { didSet { defaults.set(suggestSoundAlikes, forKey: Key.soundAlikes) } }
    var punctuation: PunctuationMode { didSet { defaults.set(punctuation.rawValue, forKey: Key.punctuation) } }

    var saveHistory: Bool { didSet { defaults.set(saveHistory, forKey: Key.saveHistory) } }
    var keepAudio: Bool { didSet { defaults.set(keepAudio, forKey: Key.keepAudio) } }
    var retention: HistoryRetention { didSet { defaults.set(retention.rawValue, forKey: Key.retention) } }

    var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Key.onboarding) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hotkey = Self.decode(KeyCombo.self, from: defaults, key: Key.hotkey) ?? .optionSpace
        handsFreeOnQuickTap = defaults.object(forKey: Key.handsFree) as? Bool ?? true
        reviewBeforeInsert = defaults.object(forKey: Key.reviewBeforeInsert) as? Bool ?? false
        lowConfidenceThreshold = defaults.object(forKey: Key.lowConfidence) as? Double ?? 0.45
        insertionMode = defaults.string(forKey: Key.insertionMode).flatMap(TextInserter.Mode.init(rawValue:)) ?? .automatic
        playSounds = defaults.object(forKey: Key.playSounds) as? Bool ?? true
        inputDeviceUID = defaults.string(forKey: Key.inputDevice)

        let savedEngine = defaults.string(forKey: Key.engine).flatMap(SpeechEngine.init(rawValue:))
        engine = savedEngine.flatMap { $0.isAvailable ? $0 : nil } ?? .recommended
        let savedLanguages = (defaults.stringArray(forKey: Key.languages) ?? []).compactMap(Language.init(rawValue:))
        languages = savedLanguages.isEmpty ? [.thai, .english] : savedLanguages
        openAIModel = defaults.string(forKey: Key.openAIModel) ?? "gpt-4o-transcribe"
        openAIBaseURL = defaults.string(forKey: Key.openAIBaseURL) ?? OpenAIConfiguration.defaultBaseURL.absoluteString
        openAISendsLanguageHint = defaults.object(forKey: Key.openAILanguageHint) as? Bool ?? true

        spaceBetweenThaiAndLatin = defaults.object(forKey: Key.spacing) as? Bool ?? true
        convertSpokenTimes = defaults.object(forKey: Key.spokenTimes) as? Bool ?? true
        convertThaiTimes = defaults.object(forKey: Key.thaiTimes) as? Bool ?? true
        suggestSoundAlikes = defaults.object(forKey: Key.soundAlikes) as? Bool ?? true
        punctuation = defaults.string(forKey: Key.punctuation).flatMap(PunctuationMode.init(rawValue:)) ?? .keep

        saveHistory = defaults.object(forKey: Key.saveHistory) as? Bool ?? true
        keepAudio = defaults.object(forKey: Key.keepAudio) as? Bool ?? false
        retention = HistoryRetention(rawValue: defaults.integer(forKey: Key.retention)) ?? .forever

        hasCompletedOnboarding = defaults.bool(forKey: Key.onboarding)
    }

    var textStyle: TextStyle {
        TextStyle(
            punctuation: punctuation,
            spaceBetweenThaiAndLatin: spaceBetweenThaiAndLatin,
            convertSpokenTimes: convertSpokenTimes,
            convertThaiTimes: convertThaiTimes,
            suggestSoundAlikes: suggestSoundAlikes
        )
    }

    var flowSettings: FlowSettings {
        FlowSettings(
            languages: languages,
            textStyle: textStyle,
            lowConfidenceThreshold: lowConfidenceThreshold,
            reviewBeforeInsert: reviewBeforeInsert,
            handsFreeOnQuickTap: handsFreeOnQuickTap,
            keepAudio: keepAudio,
            saveHistory: saveHistory
        )
    }

    var openAIConfiguration: OpenAIConfiguration {
        OpenAIConfiguration(
            baseURL: URL(string: openAIBaseURL.trimmingCharacters(in: .whitespaces)) ?? OpenAIConfiguration.defaultBaseURL,
            model: openAIModel.trimmingCharacters(in: .whitespaces).isEmpty ? "gpt-4o-transcribe" : openAIModel,
            sendLanguageHint: openAISendsLanguageHint
        )
    }

    func setLanguage(_ language: Language, enabled: Bool) {
        var updated = languages.filter { $0 != language }
        if enabled {
            updated.append(language)
        }
        guard !updated.isEmpty else { return }
        languages = Language.allCases.filter(updated.contains)
    }

    // MARK: - Storage

    private enum Key {
        static let hotkey = "hotkey"
        static let handsFree = "handsFreeOnQuickTap"
        static let reviewBeforeInsert = "reviewBeforeInsert"
        static let lowConfidence = "lowConfidenceThreshold"
        static let insertionMode = "insertionMode"
        static let playSounds = "playSounds"
        static let inputDevice = "inputDeviceUID"
        static let engine = "speechEngine"
        static let languages = "languages"
        static let openAIModel = "openAIModel"
        static let openAIBaseURL = "openAIBaseURL"
        static let openAILanguageHint = "openAISendsLanguageHint"
        static let spacing = "spaceBetweenThaiAndLatin"
        static let spokenTimes = "convertSpokenTimes"
        static let thaiTimes = "convertThaiTimes"
        static let soundAlikes = "suggestSoundAlikes"
        static let punctuation = "punctuationMode"
        static let saveHistory = "saveHistory"
        static let keepAudio = "keepAudio"
        static let retention = "historyRetentionDays"
        static let onboarding = "hasCompletedOnboarding"
    }

    private func encode<T: Encodable>(_ value: T, for key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
