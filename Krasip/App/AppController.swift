// AppController.swift
// Krasip
// Composition root: builds every module, wires the dictation flow to the hotkey, overlay, and windows.

import AppKit
import Observation
import SwiftUI
import KrasipCore
import KrasipStorage
import KrasipSystem

/// Replacement parts for simulations and tests; `nil` uses the real ones.
struct FlowOverrides {
    var recorder: (any DictationRecording)?
    var transcriber: (any Transcriber)?
    var captureTarget: (() -> InsertionTarget)?
    var insert: ((String, InsertionTarget) async -> InsertionResult)?
}

enum SettingsTab: String, Hashable {
    case general
    case languages
    case glossary
    case privacy
}

@MainActor
@Observable
final class AppController {
    let settings: AppSettings
    let store: KrasipStore
    let glossary: GlossaryModel
    let history: HistoryModel
    let appStyles: AppStylesModel
    let permissions = PermissionCenter()
    let speechModel = SpeechModelStatus()

    @ObservationIgnored let recorder = MicrophoneRecorder()
    @ObservationIgnored let inserter = TextInserter()
    @ObservationIgnored let keychain = KeychainStore(service: "com.boopannachai.Krasip")
    @ObservationIgnored let audioArchive = AudioArchive()
    @ObservationIgnored private(set) var feedback: FeedbackPlayer!
    @ObservationIgnored private(set) var windows: WindowManager!
    @ObservationIgnored private(set) var overlay: OverlayController!
    @ObservationIgnored private(set) var flow: DictationFlow!
    @ObservationIgnored private(set) lazy var benchmark = BenchmarkModel(app: self)

    var settingsTab: SettingsTab = .general
    /// True while the user edits review text inside the overlay.
    var isEditingOverlay = false
    private(set) var hotkeyProblem: String?
    private(set) var storageProblem: String?
    private(set) var isRecordingShortcut = false

    @ObservationIgnored private let overrides: FlowOverrides
    @ObservationIgnored private var activity: (any NSObjectProtocol)?
    @ObservationIgnored private var hotkeyToken: HotkeyToken?
    @ObservationIgnored private var escapeToken: HotkeyToken?
    @ObservationIgnored private var returnToken: HotkeyToken?

    init(defaults: UserDefaults = .standard, store: KrasipStore? = nil, overrides: FlowOverrides = FlowOverrides()) {
        settings = AppSettings(defaults: defaults)
        self.overrides = overrides

        var problem: String?
        let openedStore: KrasipStore
        if let store {
            openedStore = store
        } else {
            do {
                openedStore = try KrasipStore(url: KrasipStore.defaultDatabaseURL)
            } catch {
                problem = AppString.Common.storageUnavailable(error.localizedDescription)
                openedStore = try! KrasipStore.inMemory()
            }
        }
        self.store = openedStore
        storageProblem = problem

        if !defaults.bool(forKey: "didSeedGlossary") {
            try? openedStore.seedGlossaryIfEmpty([GlossaryModel.sideProjectExample])
            if store == nil {
                GlossaryModel.importLegacyGlossary(into: openedStore)
            }
            defaults.set(true, forKey: "didSeedGlossary")
        }

        let glossary = GlossaryModel(repository: openedStore.glossary)
        self.glossary = glossary
        history = HistoryModel(store: openedStore.history, audioArchive: audioArchive) { glossary.glossary }
        appStyles = AppStylesModel(repository: openedStore.appStyles)

        let settings = self.settings
        recorder.preferredDeviceUID = settings.inputDeviceUID
        feedback = FeedbackPlayer { settings.playSounds }
        windows = WindowManager { [unowned self] kind in self.content(for: kind) }
        flow = DictationFlow(environment: makeFlowEnvironment())
        overlay = OverlayController(app: self)
        flow.onPhaseChange = { [weak self] phase in
            self?.phaseChanged(phase)
        }
    }

    // MARK: - Lifecycle

    func start() {
        registerHotkey()
        history.enforceRetention(settings.retention)
        permissions.refresh()
        if !settings.hasCompletedOnboarding {
            windows.show(.onboarding)
        }
        Task {
            await speechModel.refresh(for: Language.primary(of: settings.languages))
        }
    }

    // MARK: - Hotkeys

    func registerHotkey() {
        HotkeyCenter.shared.unregister(hotkeyToken)
        hotkeyToken = nil
        do {
            hotkeyToken = try HotkeyCenter.shared.register(
                settings.hotkey,
                onPress: { [weak self] in self?.flow.hotkeyDown() },
                onRelease: { [weak self] in self?.flow.hotkeyUp() }
            )
            hotkeyProblem = nil
        } catch {
            hotkeyProblem = error.localizedDescription
        }
    }

    func setInputDevice(_ uid: String?) {
        settings.inputDeviceUID = uid
        recorder.preferredDeviceUID = uid
    }

    func updateHotkey(_ combo: KeyCombo) {
        settings.hotkey = combo
        registerHotkey()
    }

    /// While the shortcut recorder listens, the current shortcut must not start a dictation.
    func suspendHotkey() {
        HotkeyCenter.shared.unregister(hotkeyToken)
        hotkeyToken = nil
        isRecordingShortcut = true
    }

    func resumeHotkey() {
        isRecordingShortcut = false
        registerHotkey()
    }

    /// Esc and Return are claimed only while the overlay needs them, so other apps keep them.
    func refreshKeyBindings() {
        let phase = flow.phase
        setEscapeActive(phase.isActive)
        var wantsReturn = false
        if case .review = phase, !overlay.isEditing {
            wantsReturn = true
        }
        setReturnActive(wantsReturn)
    }

    private func setEscapeActive(_ active: Bool) {
        if active, escapeToken == nil {
            escapeToken = try? HotkeyCenter.shared.register(.escape, onPress: { [weak self] in self?.flow.cancel() })
        } else if !active, escapeToken != nil {
            HotkeyCenter.shared.unregister(escapeToken)
            escapeToken = nil
        }
    }

    private func setReturnActive(_ active: Bool) {
        if active, returnToken == nil {
            returnToken = try? HotkeyCenter.shared.register(.returnKey, onPress: { [weak self] in self?.flow.confirm() })
        } else if !active, returnToken != nil {
            HotkeyCenter.shared.unregister(returnToken)
            returnToken = nil
        }
    }

    private func phaseChanged(_ phase: FlowPhase) {
        overlay.update(for: phase)
        refreshKeyBindings()
        keepResponsive(phase.isActive)
    }

    /// Krasip runs in the background while you dictate into another app. Tell macOS not to
    /// slow it down (App Nap) until the text is inserted.
    private func keepResponsive(_ active: Bool) {
        if active, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "Dictation")
        } else if !active, let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    // MARK: - Actions

    func showSettings(_ tab: SettingsTab? = nil) {
        if let tab {
            settingsTab = tab
        }
        windows.show(.settings)
    }

    func copyLastDictation() {
        guard let text = flow.lastText ?? history.latest?.finalText else { return }
        inserter.copyToClipboard(text)
    }

    var lastDictationText: String? {
        flow.lastText ?? history.latest?.finalText
    }

    func accept(_ offer: LearningOffer) {
        glossary.apply(offer.suggestion)
        history.markAccepted(offer)
        flow.resolveOffer(offer)
    }

    func decline(_ offer: LearningOffer, forever: Bool) {
        if forever {
            history.dismiss(offer)
        }
        flow.resolveOffer(offer)
    }

    var currentTranscriber: any Transcriber {
        TranscriberFactory.make(settings.engine, settings: settings, keychain: keychain)
    }

    func style(forApp bundleID: String?) -> TextStyle {
        appStyles.style(for: bundleID)?.applied(to: settings.textStyle) ?? settings.textStyle
    }

    /// Transcribes a kept recording again with the current engine and glossary.
    func retranscribe(_ record: DictationRecord) async throws -> FinalText {
        guard let path = record.audioPath, let clip = audioArchive.load(path: path) else {
            throw TranscriptionError.unavailable(AppString.History.audioMissing)
        }
        let transcript = try await currentTranscriber.transcribe(
            clip,
            languages: settings.languages,
            vocabulary: glossary.glossary.vocabularyHints
        )
        return TextPolicy().finalize(transcript.rawText, glossary: glossary.glossary, style: style(forApp: record.destinationBundleID))
    }

    var openAIKey: String {
        get { keychain.string(for: TranscriberFactory.openAIKeyAccount) ?? "" }
        set { try? keychain.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), for: TranscriberFactory.openAIKeyAccount) }
    }

    var menuBarSymbol: String {
        switch flow.phase {
        case .listening: "waveform.circle.fill"
        case .transcribing, .inserting: "ellipsis.circle"
        case .review: "text.bubble"
        default: permissions.isReady(for: settings.engine) ? "waveform" : "exclamationmark.triangle"
        }
    }

    // MARK: - Wiring

    private func makeFlowEnvironment() -> DictationFlowEnvironment {
        DictationFlowEnvironment(
            recorder: overrides.recorder ?? recorder,
            transcriber: { [unowned self] in self.overrides.transcriber ?? self.currentTranscriber },
            glossary: { [unowned self] in self.glossary.glossary },
            settings: { [unowned self] in self.settings.flowSettings },
            appStyle: { [unowned self] bundleID in self.appStyles.style(for: bundleID) },
            captureTarget: { [unowned self] in self.overrides.captureTarget?() ?? self.inserter.captureTarget() },
            insert: { [unowned self] text, target in
                self.inserter.mode = self.settings.insertionMode
                self.overlay.endEditing()
                if let insert = self.overrides.insert {
                    return await insert(text, target)
                }
                return await self.inserter.insert(text, into: target)
            },
            copyToClipboard: { [unowned self] text in self.inserter.copyToClipboard(text) },
            record: { [unowned self] record in self.history.add(record) },
            applyCorrection: { [unowned self] id, text in self.history.applyCorrection(id: id, text: text) },
            persistAudio: { [unowned self] clip, id in self.audioArchive.save(clip, id: id) },
            confirmAlias: { [unowned self] entryID, alias in self.glossary.addAlias(alias, to: entryID) },
            feedback: { [unowned self] event in self.feedback.play(event) }
        )
    }

    private func content(for kind: AppWindow) -> AnyView {
        switch kind {
        case .settings: AnyView(SettingsView().environment(self))
        case .history: AnyView(HistoryView().environment(self))
        case .onboarding: AnyView(OnboardingView().environment(self))
        case .benchmark: AnyView(BenchmarkView(model: benchmark).environment(self))
        }
    }
}
