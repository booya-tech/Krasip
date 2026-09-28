// DictationFlow.swift
// KrasipKit
// Runs one dictation end to end: hotkey → record → transcribe → text policy → insert → history.

import Foundation
import Observation

@MainActor
@Observable
public final class DictationFlow {
    public private(set) var phase: FlowPhase = .idle {
        didSet {
            if phase != oldValue {
                onPhaseChange?(phase)
            }
        }
    }

    /// Microphone level 0...1 while listening, for the overlay meter.
    public private(set) var level: Float = 0
    public private(set) var elapsed: TimeInterval = 0
    /// The most recent final text, kept so it is never lost even after the overlay hides.
    public private(set) var lastText: String?

    @ObservationIgnored public var onPhaseChange: ((FlowPhase) -> Void)?

    @ObservationIgnored private let environment: DictationFlowEnvironment
    @ObservationIgnored private var session: Session?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var startTask: Task<Void, Never>?
    @ObservationIgnored private var workTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?
    @ObservationIgnored private var stateTask: Task<Void, Never>?

    private struct Session {
        let id: UUID
        let startedAt: Date
        let target: InsertionTarget
        let style: TextStyle
        let autoInsert: Bool
        var handsFree: Bool
        var releasedAt: Date?
        var clip: AudioClip?
        var transcript: Transcript?
    }

    public init(environment: DictationFlowEnvironment) {
        self.environment = environment
        let states = environment.recorder.states
        stateTask = Task { [weak self] in
            for await state in states {
                self?.handle(state)
            }
        }
    }

    // MARK: - Hotkey

    public func hotkeyDown() {
        switch phase {
        case .idle, .finished, .notice:
            beginListening(handsFree: false)
        case .listening(let listening) where listening.handsFree:
            finishListening()
        default:
            break
        }
    }

    public func hotkeyUp() {
        guard case .listening(let listening) = phase, !listening.handsFree, var session else { return }
        let settings = environment.settings()
        let held = environment.now().timeIntervalSince(session.startedAt)
        if held < settings.quickTapThreshold {
            if settings.handsFreeOnQuickTap {
                session.handsFree = true
                self.session = session
                phase = .listening(.init(startedAt: session.startedAt, handsFree: true, appName: session.target.appName))
            } else {
                abandonListening()
                showNotice(.holdLonger)
            }
            return
        }
        finishListening()
    }

    /// Start or finish a hands-free dictation (menu item, or a button in the app).
    public func toggleHandsFree() {
        switch phase {
        case .listening:
            finishListening()
        case .idle, .finished, .notice:
            beginListening(handsFree: true)
        default:
            break
        }
    }

    // MARK: - Overlay actions

    /// Esc: stop listening, stop transcribing, discard a review, or hide a result.
    public func cancel() {
        switch phase {
        case .listening:
            abandonListening()
            environment.feedback(.cancelled)
            phase = .idle
        case .transcribing:
            generation += 1
            workTask?.cancel()
            environment.recorder.cancel()
            session = nil
            environment.feedback(.cancelled)
            phase = .idle
        case .review(let review):
            recordUnsent(review, result: .cancelled)
            generation += 1
            session = nil
            phase = .idle
        case .finished, .notice:
            dismiss()
        case .idle, .inserting:
            break
        }
    }

    /// Return / Insert: insert the reviewed text.
    public func confirm() {
        guard case .review(let review) = phase else { return }
        // Leave the review state right away so a second Return or click cannot insert twice.
        phase = .inserting(appName: review.appName)
        let generation = self.generation
        workTask = Task { [weak self] in
            await self?.insert(review: review, generation: generation)
        }
    }

    public func copyReviewText() {
        guard case .review(let review) = phase else { return }
        environment.copyToClipboard(review.text)
        recordUnsent(review, result: .copiedToClipboard(.userChoseCopy))
        lastText = review.text
        generation += 1
        session = nil
        phase = .finished(.init(
            dictationID: review.dictationID,
            text: review.text,
            result: .copiedToClipboard(.userChoseCopy),
            changes: review.finalText.visibleChanges,
            appName: review.appName,
            offers: []
        ))
        scheduleDismiss(after: environment.settings().noticeDisplayDuration)
    }

    /// Free-form edit of the reviewed text. Pass `nil` to drop the edits.
    public func updateReviewText(_ text: String?) {
        guard case .review(var review) = phase else { return }
        review.editedText = (text == review.finalText.text) ? nil : text
        phase = .review(review)
    }

    public func accept(_ suggestion: PendingSuggestion) {
        guard case .review(var review) = phase else { return }
        review.decisions.accept(suggestion)
        if suggestion.isSoundAlike {
            // The user confirmed this spelling, so it becomes an alias of the entry.
            environment.confirmAlias(suggestion.entryID, suggestion.matchedText)
        }
        refinalize(&review)
        phase = .review(review)
    }

    public func undo(_ change: TextChange) {
        guard case .review(var review) = phase else { return }
        review.decisions.undo(change)
        refinalize(&review)
        phase = .review(review)
    }

    /// Keep the finished card on screen (e.g. while the pointer is over it).
    public func holdResult() {
        dismissTask?.cancel()
    }

    public func releaseResult() {
        guard isShowingResult else { return }
        scheduleDismiss(after: environment.settings().finishedDisplayDuration)
    }

    /// Remove a learning offer after the user answered it.
    public func resolveOffer(_ offer: LearningOffer) {
        guard case .finished(var finished) = phase else { return }
        finished.offers.removeAll { $0.id == offer.id }
        phase = .finished(finished)
    }

    public func dismiss() {
        dismissTask?.cancel()
        if isShowingResult {
            phase = .idle
        }
    }

    private var isShowingResult: Bool {
        switch phase {
        case .finished, .notice: true
        default: false
        }
    }

    // MARK: - Listening

    private func beginListening(handsFree: Bool) {
        dismissTask?.cancel()
        generation += 1
        let generation = self.generation

        let target = environment.captureTarget()
        guard !target.isSecureField else {
            showNotice(.secureField)
            return
        }

        let settings = environment.settings()
        let appStyle = environment.appStyle(target.bundleID)
        let session = Session(
            id: UUID(),
            startedAt: environment.now(),
            target: target,
            style: appStyle?.applied(to: settings.textStyle) ?? settings.textStyle,
            autoInsert: (appStyle?.autoInsert ?? true) && !settings.reviewBeforeInsert,
            handsFree: handsFree
        )
        self.session = session
        level = 0
        elapsed = 0
        phase = .listening(.init(startedAt: session.startedAt, handsFree: handsFree, appName: target.appName))
        environment.feedback(.startedListening)

        let recorder = environment.recorder
        startTask = Task { [weak self] in
            do {
                try await recorder.start()
            } catch {
                self?.recorderFailedToStart(error, generation: generation)
            }
        }

        timerTask?.cancel()
        let limit = settings.maximumDuration
        timerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(limit))
            guard let self, self.generation == generation, case .listening = self.phase else { return }
            self.finishListening()
        }
    }

    private func finishListening() {
        guard case .listening = phase, var session else { return }
        timerTask?.cancel()
        session.releasedAt = environment.now()
        self.session = session
        let generation = self.generation
        phase = .transcribing(appName: session.target.appName)

        let startTask = self.startTask
        workTask = Task { [weak self] in
            await startTask?.value
            await self?.process(generation: generation)
        }
    }

    private func abandonListening() {
        generation += 1
        timerTask?.cancel()
        startTask?.cancel()
        environment.recorder.cancel()
        session = nil
    }

    private func recorderFailedToStart(_ error: any Error, generation: Int) {
        guard generation == self.generation else { return }
        switch phase {
        case .listening, .transcribing:
            stopForMicrophoneFailure(error)
        default:
            break
        }
    }

    private func handle(_ state: DictationState) {
        guard case .listening = phase else { return }
        switch state {
        case .recording(let elapsed, let level):
            self.elapsed = elapsed
            self.level = level
        case .failed(let error):
            stopForMicrophoneFailure(error)
        default:
            break
        }
    }

    private func stopForMicrophoneFailure(_ error: any Error) {
        generation += 1
        timerTask?.cancel()
        endSession(with: .microphone(Self.dictationError(error)))
    }

    private static func dictationError(_ error: any Error) -> DictationError {
        error as? DictationError ?? .engineFailure(error.localizedDescription)
    }

    // MARK: - Processing

    private func process(generation: Int) async {
        guard generation == self.generation, var session else { return }
        let settings = environment.settings()

        let clip: AudioClip
        do {
            clip = try await environment.recorder.stop()
            // Played after the microphone is off, so the sound is not in the recording.
            environment.feedback(.stoppedListening)
        } catch {
            guard generation == self.generation else { return }
            endSession(with: .microphone(Self.dictationError(error)))
            return
        }
        guard generation == self.generation else { return }

        guard clip.voicedDuration(threshold: settings.voiceThreshold) >= settings.minimumVoicedDuration else {
            endSession(with: .noSpeech)
            return
        }
        session.clip = clip
        self.session = session

        let transcriber = environment.transcriber()
        let vocabulary = environment.glossary().vocabularyHints
        let languages = settings.languages
        let transcript: Transcript
        do {
            transcript = try await Self.withTimeout(settings.transcriptionTimeout) {
                try await transcriber.transcribe(clip, languages: languages, vocabulary: vocabulary)
            }
        } catch {
            guard generation == self.generation, !(error is CancellationError) else { return }
            let failure = error as? TranscriptionError
            endSession(with: failure == .noSpeech ? .noSpeech : .transcription(failure ?? .network(error.localizedDescription)))
            return
        }
        guard generation == self.generation else { return }

        guard !transcript.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            endSession(with: .noSpeech)
            return
        }
        session.transcript = transcript
        self.session = session

        let finalText = TextPolicy().finalize(transcript.rawText, glossary: environment.glossary(), style: session.style)
        var reasons = Set<ReviewReason>()
        if transcript.isLowConfidence(threshold: settings.lowConfidenceThreshold) {
            reasons.insert(.lowConfidence)
        }
        if !finalText.suggestions.isEmpty {
            reasons.insert(.suggestions)
        }
        if !session.autoInsert {
            reasons.insert(.reviewMode)
        }

        let review = FlowPhase.Review(
            dictationID: session.id,
            transcript: transcript,
            finalText: finalText,
            decisions: PolicyDecisions(),
            editedText: nil,
            reasons: reasons,
            appName: session.target.appName
        )
        if reasons.isEmpty {
            await insert(review: review, generation: generation)
        } else {
            lastText = finalText.text
            phase = .review(review)
        }
    }

    private func insert(review: FlowPhase.Review, generation: Int) async {
        guard generation == self.generation, let session, session.clip != nil else { return }
        let text = review.text
        lastText = text
        phase = .inserting(appName: session.target.appName)

        let result = await environment.insert(text, session.target)
        guard generation == self.generation else { return }

        let offers = saveToHistory(review, session: session, result: result)

        self.session = nil
        phase = .finished(.init(
            dictationID: session.id,
            text: text,
            result: result,
            changes: review.finalText.visibleChanges,
            appName: session.target.appName,
            offers: offers
        ))
        environment.feedback(result.succeeded ? .inserted : .copied)
        let settings = environment.settings()
        let display = result.succeeded && offers.isEmpty ? settings.finishedDisplayDuration : settings.noticeDisplayDuration * 2
        scheduleDismiss(after: display)
    }

    /// Text the user did not insert still goes to history, so nothing is ever lost.
    private func recordUnsent(_ review: FlowPhase.Review, result: InsertionResult) {
        guard let session else { return }
        saveToHistory(review, session: session, result: result)
    }

    /// Saves the dictation, and the user's edit as a correction, when history is on. Returns any learning offers.
    @discardableResult
    private func saveToHistory(_ review: FlowPhase.Review, session: Session, result: InsertionResult) -> [LearningOffer] {
        let settings = environment.settings()
        guard settings.saveHistory else { return [] }
        let audioPath = settings.keepAudio ? session.clip.flatMap { environment.persistAudio($0, session.id) } : nil
        environment.record(makeRecord(review: review, session: session, result: result, audioPath: audioPath))
        guard let edited = review.editedText, edited != review.finalText.text else { return [] }
        return environment.applyCorrection(session.id, edited)?.offers ?? []
    }

    private func makeRecord(review: FlowPhase.Review, session: Session, result: InsertionResult, audioPath: String?) -> DictationRecord {
        DictationRecord(
            id: session.id,
            startedAt: session.startedAt,
            rawText: review.transcript.rawText,
            finalText: review.finalText.text,
            destinationBundleID: session.target.bundleID,
            destinationAppName: session.target.appName,
            confidence: review.transcript.confidence,
            providerID: review.transcript.providerID,
            audioDuration: session.clip?.duration ?? 0,
            latency: result == .cancelled ? nil : session.releasedAt.map { environment.now().timeIntervalSince($0) },
            insertion: result,
            changes: review.finalText.changes,
            audioPath: audioPath
        )
    }

    private func refinalize(_ review: inout FlowPhase.Review) {
        guard let session, let transcript = session.transcript else { return }
        review.finalText = TextPolicy().finalize(
            transcript.rawText,
            glossary: environment.glossary(),
            style: session.style,
            decisions: review.decisions
        )
        review.editedText = nil
        if review.finalText.suggestions.isEmpty {
            review.reasons.remove(.suggestions)
        }
    }

    // MARK: - Notices

    private func endSession(with kind: FlowPhase.Notice.Kind) {
        session = nil
        showNotice(kind)
    }

    private func showNotice(_ kind: FlowPhase.Notice.Kind) {
        phase = .notice(.init(kind: kind))
        if kind != .holdLonger {
            environment.feedback(.problem)
        }
        scheduleDismiss(after: environment.settings().noticeDisplayDuration)
    }

    private func scheduleDismiss(after duration: Duration) {
        dismissTask?.cancel()
        let generation = self.generation
        let sleep = environment.sleep
        dismissTask = Task { [weak self] in
            await sleep(duration)
            guard !Task.isCancelled, let self, self.generation == generation, self.isShowingResult else { return }
            self.phase = .idle
        }
    }

    private static func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TranscriptionError.timedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw TranscriptionError.timedOut }
            return result
        }
    }
}
