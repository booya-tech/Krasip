// FlowTypes.swift
// KrasipKit
// Settings, phases, and dependencies of the end-to-end dictation flow.

import Foundation

public struct FlowSettings: Equatable, Sendable {
    public var languages: [Language]
    public var textStyle: TextStyle
    /// Below this confidence the raw transcript is shown for review before inserting.
    public var lowConfidenceThreshold: Double
    /// Always show the text for review instead of inserting right away.
    public var reviewBeforeInsert: Bool
    /// A quick tap of the shortcut starts hands-free recording; tap again to finish.
    public var handsFreeOnQuickTap: Bool
    public var quickTapThreshold: TimeInterval
    /// Recordings with less voiced audio than this are treated as "no speech".
    public var minimumVoicedDuration: TimeInterval
    public var voiceThreshold: Float
    public var maximumDuration: TimeInterval
    public var transcriptionTimeout: TimeInterval
    public var keepAudio: Bool
    public var saveHistory: Bool
    public var finishedDisplayDuration: Duration
    public var noticeDisplayDuration: Duration

    public init(
        languages: [Language] = [.thai, .english],
        textStyle: TextStyle = .standard,
        lowConfidenceThreshold: Double = 0.5,
        reviewBeforeInsert: Bool = false,
        handsFreeOnQuickTap: Bool = true,
        quickTapThreshold: TimeInterval = 0.35,
        minimumVoicedDuration: TimeInterval = 0.15,
        voiceThreshold: Float = 0.005,
        maximumDuration: TimeInterval = 360,
        transcriptionTimeout: TimeInterval = 90,
        keepAudio: Bool = false,
        saveHistory: Bool = true,
        finishedDisplayDuration: Duration = .seconds(2.5),
        noticeDisplayDuration: Duration = .seconds(4)
    ) {
        self.languages = languages
        self.textStyle = textStyle
        self.lowConfidenceThreshold = lowConfidenceThreshold
        self.reviewBeforeInsert = reviewBeforeInsert
        self.handsFreeOnQuickTap = handsFreeOnQuickTap
        self.quickTapThreshold = quickTapThreshold
        self.minimumVoicedDuration = minimumVoicedDuration
        self.voiceThreshold = voiceThreshold
        self.maximumDuration = maximumDuration
        self.transcriptionTimeout = transcriptionTimeout
        self.keepAudio = keepAudio
        self.saveHistory = saveHistory
        self.finishedDisplayDuration = finishedDisplayDuration
        self.noticeDisplayDuration = noticeDisplayDuration
    }
}

public enum ReviewReason: String, Hashable, Sendable {
    case lowConfidence
    case suggestions
    case reviewMode
}

public enum FlowPhase: Equatable, Sendable {
    case idle
    case listening(Listening)
    case transcribing(appName: String?)
    case review(Review)
    case inserting(appName: String?)
    case finished(Finished)
    case notice(Notice)

    public struct Listening: Equatable, Sendable {
        public var startedAt: Date
        public var handsFree: Bool
        public var appName: String?

        public init(startedAt: Date, handsFree: Bool, appName: String?) {
            self.startedAt = startedAt
            self.handsFree = handsFree
            self.appName = appName
        }
    }

    public struct Review: Equatable, Sendable {
        public var dictationID: UUID
        public var transcript: Transcript
        public var finalText: FinalText
        public var decisions: PolicyDecisions
        /// Free-form edits typed by the user. `nil` until they edit.
        public var editedText: String?
        public var reasons: Set<ReviewReason>
        public var appName: String?

        public init(
            dictationID: UUID,
            transcript: Transcript,
            finalText: FinalText,
            decisions: PolicyDecisions,
            editedText: String?,
            reasons: Set<ReviewReason>,
            appName: String?
        ) {
            self.dictationID = dictationID
            self.transcript = transcript
            self.finalText = finalText
            self.decisions = decisions
            self.editedText = editedText
            self.reasons = reasons
            self.appName = appName
        }

        public var text: String { editedText ?? finalText.text }
    }

    public struct Finished: Equatable, Sendable {
        public var dictationID: UUID
        public var text: String
        public var result: InsertionResult
        public var changes: [TextChange]
        public var appName: String?
        public var offers: [LearningOffer]

        public init(dictationID: UUID, text: String, result: InsertionResult, changes: [TextChange], appName: String?, offers: [LearningOffer]) {
            self.dictationID = dictationID
            self.text = text
            self.result = result
            self.changes = changes
            self.appName = appName
            self.offers = offers
        }
    }

    public struct Notice: Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case noSpeech
            case holdLonger
            case secureField
            case microphone(DictationError)
            case transcription(TranscriptionError)
            case failure(String)
        }

        public var kind: Kind

        public init(kind: Kind) {
            self.kind = kind
        }
    }

    public var isIdle: Bool { self == .idle }

    public var isActive: Bool {
        switch self {
        case .listening, .transcribing, .review, .inserting: true
        default: false
        }
    }
}

/// Sounds and other feedback the app can play at key moments.
public enum FlowFeedback: Sendable {
    case startedListening
    case stoppedListening
    case inserted
    case copied
    case cancelled
    case problem
}

/// Everything the flow needs from the outside world, as closures so tests can fake each one.
@MainActor
public struct DictationFlowEnvironment {
    public var recorder: any DictationRecording
    public var transcriber: @MainActor () -> any Transcriber
    public var glossary: @MainActor () -> Glossary
    public var settings: @MainActor () -> FlowSettings
    public var appStyle: @MainActor (_ bundleID: String?) -> AppStyle?
    public var captureTarget: @MainActor () -> InsertionTarget
    public var insert: @MainActor (_ text: String, _ target: InsertionTarget) async -> InsertionResult
    public var copyToClipboard: @MainActor (_ text: String) -> Void
    public var record: @MainActor (_ record: DictationRecord) -> Void
    public var applyCorrection: @MainActor (_ dictationID: UUID, _ finalText: String) -> CorrectionOutcome?
    public var persistAudio: @MainActor (_ audio: AudioClip, _ dictationID: UUID) -> String?
    /// Saves a sound-alike spelling the user confirmed as a new alias of the entry.
    public var confirmAlias: @MainActor (_ entryID: UUID, _ alias: String) -> Void
    public var feedback: @MainActor (_ event: FlowFeedback) -> Void
    public var now: @MainActor () -> Date
    public var sleep: @MainActor (_ duration: Duration) async -> Void

    public init(
        recorder: any DictationRecording,
        transcriber: @escaping @MainActor () -> any Transcriber,
        glossary: @escaping @MainActor () -> Glossary,
        settings: @escaping @MainActor () -> FlowSettings,
        appStyle: (@MainActor (String?) -> AppStyle?)? = nil,
        captureTarget: @escaping @MainActor () -> InsertionTarget,
        insert: @escaping @MainActor (String, InsertionTarget) async -> InsertionResult,
        copyToClipboard: @escaping @MainActor (String) -> Void,
        record: (@MainActor (DictationRecord) -> Void)? = nil,
        applyCorrection: (@MainActor (UUID, String) -> CorrectionOutcome?)? = nil,
        persistAudio: (@MainActor (AudioClip, UUID) -> String?)? = nil,
        confirmAlias: (@MainActor (UUID, String) -> Void)? = nil,
        feedback: (@MainActor (FlowFeedback) -> Void)? = nil,
        now: (@MainActor () -> Date)? = nil,
        sleep: (@MainActor (Duration) async -> Void)? = nil
    ) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.glossary = glossary
        self.settings = settings
        self.appStyle = appStyle ?? { _ in nil }
        self.captureTarget = captureTarget
        self.insert = insert
        self.copyToClipboard = copyToClipboard
        self.record = record ?? { _ in }
        self.applyCorrection = applyCorrection ?? { _, _ in nil }
        self.persistAudio = persistAudio ?? { _, _ in nil }
        self.confirmAlias = confirmAlias ?? { _, _ in }
        self.feedback = feedback ?? { _ in }
        self.now = now ?? { Date() }
        self.sleep = sleep ?? { duration in try? await Task.sleep(for: duration) }
    }
}
