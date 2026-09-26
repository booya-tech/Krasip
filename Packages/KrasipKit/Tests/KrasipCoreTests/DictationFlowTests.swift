// DictationFlowTests.swift
// KrasipCoreTests
// End-to-end flow with fake microphone, recognizer, and inserter: every path keeps the final text.

import Foundation
import Testing
@testable import KrasipCore

@MainActor
final class FakeRecorder: DictationRecording {
    let states: AsyncStream<DictationState>
    private let continuation: AsyncStream<DictationState>.Continuation
    var clip = AudioClip(samples: FakeRecorder.speech(seconds: 1.5))
    var startError: (any Error)?
    private(set) var startCount = 0
    private(set) var cancelCount = 0

    init() {
        (states, continuation) = AsyncStream.makeStream()
    }

    func start() async throws {
        startCount += 1
        if let startError { throw startError }
        continuation.yield(.recording(elapsed: 0, level: 0.2))
    }

    func stop() async throws -> AudioClip {
        continuation.yield(.finished(duration: clip.duration))
        return clip
    }

    func cancel() {
        cancelCount += 1
        continuation.yield(.cancelled)
    }

    func fail(_ error: DictationError) {
        continuation.yield(.failed(error))
    }

    static func speech(seconds: Double) -> [Float] {
        (0..<Int(seconds * 16_000)).map { Float(sin(Double($0) * 0.05)) * 0.3 }
    }
}

@MainActor
final class FlowHarness {
    let recorder = FakeRecorder()
    var transcriber: any Transcriber = FixtureTranscriber(text: "วันนี้จะต้องกลับบ้านไปทำ side project")
    var settings = FlowSettings()
    var glossary = Glossary([AcceptanceTests.sideProject])
    var target = InsertionTarget(bundleID: "com.apple.Notes", appName: "Notes", processID: 42)
    var insertResult: InsertionResult = .inserted(.accessibility)
    var appStyles: [String: AppStyle] = [:]
    var clock = Date(timeIntervalSince1970: 1_000)
    /// When false, result cards stay on screen so tests can inspect them.
    var instantTimers = false

    private(set) var inserted: [String] = []
    private(set) var copied: [String] = []
    private(set) var records: [DictationRecord] = []
    private(set) var corrections: [(UUID, String)] = []
    var correctionOutcome: CorrectionOutcome?
    var onConfirmAlias: (UUID, String) -> Void = { _, _ in }

    private(set) var flow: DictationFlow!

    init() {
        flow = DictationFlow(environment: DictationFlowEnvironment(
            recorder: recorder,
            transcriber: { [unowned self] in self.transcriber },
            glossary: { [unowned self] in self.glossary },
            settings: { [unowned self] in self.settings },
            appStyle: { [unowned self] bundleID in bundleID.flatMap { self.appStyles[$0] } },
            captureTarget: { [unowned self] in self.target },
            insert: { @MainActor [unowned self] text, _ in
                self.inserted.append(text)
                if case .copiedToClipboard = self.insertResult { self.copied.append(text) }
                return self.insertResult
            },
            copyToClipboard: { [unowned self] text in self.copied.append(text) },
            record: { [unowned self] record in self.records.append(record) },
            applyCorrection: { [unowned self] id, text in
                self.corrections.append((id, text))
                return self.correctionOutcome
            },
            confirmAlias: { [unowned self] id, alias in self.onConfirmAlias(id, alias) },
            now: { [unowned self] in self.clock },
            sleep: { @MainActor [unowned self] _ in
                if self.instantTimers {
                    await Task.yield()
                } else {
                    try? await Task.sleep(for: .seconds(3_600))
                }
            }
        ))
    }

    /// Hold the hotkey for `seconds`, then release.
    func dictate(holding seconds: TimeInterval = 1.5) async {
        flow.hotkeyDown()
        await settle()
        clock.addTimeInterval(seconds)
        flow.hotkeyUp()
        await settle()
    }

    func settle() async {
        for _ in 0..<50 { await Task.yield() }
    }
}

@MainActor
struct DictationFlowTests {
    @Test func holdSpeakReleaseInsertsFinalTextAndRecordsHistory() async {
        let harness = FlowHarness()
        await harness.dictate()

        #expect(harness.inserted == ["วันนี้จะต้องกลับบ้านไปทำ side-project"])
        #expect(harness.records.count == 1)
        let record = harness.records[0]
        #expect(record.rawText == "วันนี้จะต้องกลับบ้านไปทำ side project")
        #expect(record.finalText == "วันนี้จะต้องกลับบ้านไปทำ side-project")
        #expect(record.destinationBundleID == "com.apple.Notes")
        #expect(record.insertion == .inserted(.accessibility))
        #expect(record.latency == 0)
        if case .finished(let finished) = harness.flow.phase {
            #expect(finished.text == "วันนี้จะต้องกลับบ้านไปทำ side-project")
            #expect(finished.changes.map(\.description) == ["side project -> side-project (glossary)"])
        } else {
            Issue.record("Expected finished phase, got \(harness.flow.phase)")
        }
    }

    @Test func insertionFailureStillKeepsTheText() async {
        let harness = FlowHarness()
        harness.insertResult = .copiedToClipboard(.appRejected)
        await harness.dictate()

        #expect(harness.copied == ["วันนี้จะต้องกลับบ้านไปทำ side-project"])
        #expect(harness.records.first?.insertion == .copiedToClipboard(.appRejected))
        #expect(harness.flow.lastText == "วันนี้จะต้องกลับบ้านไปทำ side-project")
    }

    @Test func lowConfidenceShowsRawTranscriptForReview() async {
        let harness = FlowHarness()
        harness.transcriber = FixtureTranscriber(text: "ทำไซต์โปรเจกต์", confidence: 0.2)
        await harness.dictate()

        guard case .review(let review) = harness.flow.phase else {
            Issue.record("Expected review, got \(harness.flow.phase)")
            return
        }
        #expect(review.reasons.contains(.lowConfidence))
        #expect(review.transcript.rawText == "ทำไซต์โปรเจกต์")
        #expect(review.text == "ทำ side-project")
        #expect(harness.inserted.isEmpty)

        harness.flow.confirm()
        await harness.settle()
        #expect(harness.inserted == ["ทำ side-project"])
    }

    @Test func confirmingTwiceInsertsOnce() async {
        let harness = FlowHarness()
        harness.settings.reviewBeforeInsert = true
        await harness.dictate()
        harness.flow.confirm()
        harness.flow.confirm()
        await harness.settle()
        #expect(harness.inserted.count == 1)
        #expect(harness.records.count == 1)
    }

    @Test func suggestionsWaitForTheUser() async {
        let harness = FlowHarness()
        let entry = GlossaryEntry(aliases: ["กิตฮับ"], preferredOutput: "GitHub", mode: .suggest)
        harness.glossary = Glossary([entry])
        harness.transcriber = FixtureTranscriber(text: "push ขึ้น กิตฮับ")
        await harness.dictate()

        guard case .review(let review) = harness.flow.phase, let suggestion = review.finalText.suggestions.first else {
            Issue.record("Expected a suggestion to review")
            return
        }
        harness.flow.accept(suggestion)
        guard case .review(let accepted) = harness.flow.phase else { return }
        #expect(accepted.text == "push ขึ้น GitHub")
        harness.flow.confirm()
        await harness.settle()
        #expect(harness.inserted == ["push ขึ้น GitHub"])
    }

    @Test func editedReviewTextIsInsertedAndRecordedAsCorrection() async {
        let harness = FlowHarness()
        harness.settings.reviewBeforeInsert = true
        harness.transcriber = FixtureTranscriber(text: "ทำไซด์โปรเจ็กต์")
        await harness.dictate()

        harness.flow.updateReviewText("ทำ side-project")
        harness.flow.confirm()
        await harness.settle()

        #expect(harness.inserted == ["ทำ side-project"])
        #expect(harness.records.first?.finalText == "ทำไซด์โปรเจ็กต์")
        #expect(harness.corrections.count == 1)
        #expect(harness.corrections.first?.1 == "ทำ side-project")
    }

    @Test func undoingAChangeInReview() async {
        let harness = FlowHarness()
        harness.settings.reviewBeforeInsert = true
        harness.transcriber = FixtureTranscriber(text: "ทำไซต์โปรเจกต์")
        await harness.dictate()

        guard case .review(let review) = harness.flow.phase,
              let change = review.finalText.visibleChanges.first(where: { $0.kind == .glossary }) else {
            Issue.record("Expected review with a glossary change")
            return
        }
        harness.flow.undo(change)
        guard case .review(let undone) = harness.flow.phase else { return }
        #expect(undone.text == "ทำไซต์โปรเจกต์")
    }

    @Test func cancellingAReviewStillSavesItToHistory() async {
        let harness = FlowHarness()
        harness.settings.reviewBeforeInsert = true
        await harness.dictate()
        harness.flow.cancel()

        #expect(harness.flow.phase == .idle)
        #expect(harness.inserted.isEmpty)
        #expect(harness.records.first?.insertion == .cancelled)
    }

    @Test func secureFieldBlocksRecording() async {
        let harness = FlowHarness()
        harness.target.isSecureField = true
        harness.flow.hotkeyDown()
        await harness.settle()

        #expect(harness.recorder.startCount == 0)
        #expect(harness.flow.phase == .notice(.init(kind: .secureField)))
    }

    @Test func escapeWhileListeningCancelsWithoutTranscribing() async {
        let harness = FlowHarness()
        harness.flow.hotkeyDown()
        await harness.settle()
        harness.flow.cancel()
        await harness.settle()

        #expect(harness.flow.phase == .idle)
        #expect(harness.recorder.cancelCount == 1)
        #expect(harness.inserted.isEmpty)
        #expect(harness.records.isEmpty)
    }

    @Test func quickTapStartsHandsFreeAndSecondPressFinishes() async {
        let harness = FlowHarness()
        await harness.dictate(holding: 0.1)
        guard case .listening(let listening) = harness.flow.phase else {
            Issue.record("Expected hands-free listening, got \(harness.flow.phase)")
            return
        }
        #expect(listening.handsFree)

        harness.clock.addTimeInterval(3)
        harness.flow.hotkeyDown()
        await harness.settle()
        #expect(harness.inserted.count == 1)
    }

    @Test func quickTapWithoutHandsFreeAsksToHoldLonger() async {
        let harness = FlowHarness()
        harness.settings.handsFreeOnQuickTap = false
        await harness.dictate(holding: 0.1)
        #expect(harness.flow.phase == .notice(.init(kind: .holdLonger)))
        #expect(harness.inserted.isEmpty)
    }

    @Test func silenceIsNotSentToTheRecognizer() async {
        let harness = FlowHarness()
        harness.recorder.clip = AudioClip(samples: [Float](repeating: 0, count: 16_000))
        await harness.dictate()
        #expect(harness.flow.phase == .notice(.init(kind: .noSpeech)))
        #expect(harness.records.isEmpty)
    }

    @Test func microphoneDeniedShowsNotice() async {
        let harness = FlowHarness()
        harness.recorder.startError = DictationError.microphoneDenied
        harness.flow.hotkeyDown()
        await harness.settle()
        #expect(harness.flow.phase == .notice(.init(kind: .microphone(.microphoneDenied))))
    }

    @Test func transcriptionErrorShowsNotice() async {
        struct Failing: Transcriber {
            var id: TranscriberID { .openAI }
            func transcribe(_ audio: AudioClip, languages: [Language], vocabulary: [String]) async throws -> Transcript {
                throw TranscriptionError.invalidAPIKey
            }
        }
        let harness = FlowHarness()
        harness.transcriber = Failing()
        await harness.dictate()
        #expect(harness.flow.phase == .notice(.init(kind: .transcription(.invalidAPIKey))))
    }

    @Test func perAppStyleCanForceReview() async {
        let harness = FlowHarness()
        harness.appStyles["com.apple.Notes"] = AppStyle(bundleID: "com.apple.Notes", autoInsert: false)
        await harness.dictate()
        guard case .review(let review) = harness.flow.phase else {
            Issue.record("Expected review")
            return
        }
        #expect(review.reasons == [.reviewMode])
    }

    @Test func perAppPunctuationIsApplied() async {
        let harness = FlowHarness()
        harness.transcriber = FixtureTranscriber(text: "เสร็จแล้วครับ.")
        harness.appStyles["com.apple.Notes"] = AppStyle(bundleID: "com.apple.Notes", punctuationMode: .noTrailingPeriod)
        await harness.dictate()
        #expect(harness.inserted == ["เสร็จแล้วครับ"])
    }

    @Test func historyCanBeTurnedOff() async {
        let harness = FlowHarness()
        harness.settings.saveHistory = false
        await harness.dictate()
        #expect(harness.inserted.count == 1)
        #expect(harness.records.isEmpty)
    }

    @Test func repeatedCorrectionOfferIsShownAfterInsert() async {
        let harness = FlowHarness()
        harness.settings.reviewBeforeInsert = true
        harness.transcriber = FixtureTranscriber(text: "ทำไซด์โปรเจ็กต์")
        let suggestion = Suggestion(alias: "ไซด์โปรเจ็กต์", preferredOutput: "side-project", kind: .newEntry)
        harness.correctionOutcome = CorrectionOutcome(
            correction: Correction(dictationID: UUID(), beforeText: "a", afterText: "b"),
            suggestions: [suggestion],
            offers: [LearningOffer(suggestion: suggestion, occurrences: 2, correctionID: UUID())]
        )
        await harness.dictate()
        harness.flow.updateReviewText("ทำ side-project")
        harness.flow.confirm()
        await harness.settle()

        guard case .finished(let finished) = harness.flow.phase else {
            Issue.record("Expected finished")
            return
        }
        #expect(finished.offers.map(\.suggestion) == [suggestion])
        harness.flow.resolveOffer(finished.offers[0])
        if case .finished(let resolved) = harness.flow.phase {
            #expect(resolved.offers.isEmpty)
        }
    }

    @Test func finishedCardHidesAutomatically() async {
        let harness = FlowHarness()
        harness.instantTimers = true
        await harness.dictate()
        await harness.settle()
        #expect(harness.flow.phase == .idle)
    }
}
