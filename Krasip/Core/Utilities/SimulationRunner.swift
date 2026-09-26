// SimulationRunner.swift
// Krasip
// Debug-only: `Krasip --simulate-dictation <folder>` runs real dictations with a fake microphone and transcript, logging the overlay.

#if DEBUG
import AppKit
import SwiftUI
import KrasipCore
import KrasipStorage

/// Drives the real flow, overlay panel, hotkey bindings, and history with a simulated microphone,
/// a fixed transcript, and an insertion that touches nothing. Writes `simulation.log` and PNGs
/// of the overlay panel in each phase, then quits.
@MainActor
enum SimulationRunner {
    static var isRequested: Bool {
        CommandLine.arguments.contains("--simulate-dictation")
    }

    private static var outputFolder: URL? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--simulate-dictation"), index + 1 < arguments.count else { return nil }
        return URL(fileURLWithPath: arguments[index + 1])
    }

    private static var inserted: [String] = []

    static func makeController() -> AppController {
        let defaults = UserDefaults(suiteName: "com.boopannachai.Krasip.simulation") ?? .standard
        defaults.removePersistentDomain(forName: "com.boopannachai.Krasip.simulation")
        let overrides = FlowOverrides(
            recorder: SimulatedRecorder(),
            transcriber: FixtureTranscriber(text: "วันนี้จะต้องกลับบ้านไปทำ side project", confidence: 0.9, delay: .milliseconds(400)),
            captureTarget: { InsertionTarget(bundleID: "com.apple.Notes", appName: "Notes", processID: nil) },
            insert: { text, _ in
                inserted.append(text)
                return .inserted(.paste)
            }
        )
        let app = AppController(defaults: defaults, store: try! KrasipStore.inMemory(), overrides: overrides)
        app.settings.playSounds = false
        return app
    }

    static func run(app: AppController) {
        guard let folder = outputFolder else {
            NSApp.terminate(nil)
            return
        }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        Task { @MainActor in
            // 1. Hold, speak, release: inserted right away.
            app.flow.hotkeyDown()
            await snapshot(app, folder, "1-listening")
            try? await Task.sleep(for: .milliseconds(900))
            app.flow.hotkeyUp()
            await snapshot(app, folder, "2-transcribing")
            try? await Task.sleep(for: .milliseconds(900))
            await snapshot(app, folder, "3-finished")
            try? await Task.sleep(for: .seconds(3))
            await snapshot(app, folder, "4-after-dismiss")

            // 2. Review before inserting, then Return.
            app.settings.reviewBeforeInsert = true
            app.flow.hotkeyDown()
            try? await Task.sleep(for: .milliseconds(900))
            app.flow.hotkeyUp()
            try? await Task.sleep(for: .milliseconds(1_200))
            await snapshot(app, folder, "5-review")
            app.flow.confirm()
            try? await Task.sleep(for: .milliseconds(500))
            await snapshot(app, folder, "6-finished-after-review")

            // 3. Quick tap: hands-free, then finish with a second press.
            app.settings.reviewBeforeInsert = false
            app.flow.hotkeyDown()
            try? await Task.sleep(for: .milliseconds(120))
            app.flow.hotkeyUp()
            await snapshot(app, folder, "7-hands-free")
            try? await Task.sleep(for: .milliseconds(800))
            app.flow.hotkeyDown()
            try? await Task.sleep(for: .milliseconds(1_200))
            await snapshot(app, folder, "8-finished-hands-free")

            // 4. Esc while listening.
            app.flow.hotkeyDown()
            try? await Task.sleep(for: .milliseconds(500))
            app.flow.cancel()
            await snapshot(app, folder, "9-cancelled")

            log.append("inserted: \(inserted)")
            log.append("history: \(app.history.records.map(\.finalText))")
            log.append("stats: dictations=\(app.history.stats.dictationCount) insertionRate=\(app.history.stats.insertionSuccessRate ?? -1)")
            try? log.joined(separator: "\n").write(to: folder.appending(path: "simulation.log"), atomically: true, encoding: .utf8)
            NSApp.terminate(nil)
        }
    }

    private static var log: [String] = []

    private static func snapshot(_ app: AppController, _ folder: URL, _ name: String) async {
        try? await Task.sleep(for: .milliseconds(350))
        let panel = app.overlay.debugPanel
        let screen = (panel.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        log.append("\(name): phase=\(describe(app.flow.phase)) visible=\(panel.isVisible) frame=\(panel.frame.integral) screenMidX=\(screen.midX.rounded()) bottomGap=\((panel.frame.minY - screen.minY).rounded())")
        guard panel.isVisible, let view = panel.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: folder.appending(path: "\(name).png"))
    }

    private static func describe(_ phase: FlowPhase) -> String {
        switch phase {
        case .idle: "idle"
        case .listening(let listening): listening.handsFree ? "listening(hands-free)" : "listening"
        case .transcribing: "transcribing"
        case .review: "review"
        case .inserting: "inserting"
        case .finished(let finished): "finished(\(finished.result.storageValue))"
        case .notice(let notice): "notice(\(notice.kind))"
        }
    }
}

/// A microphone that "hears" a steady tone, so the flow sees voiced audio.
@MainActor
private final class SimulatedRecorder: DictationRecording {
    let states: AsyncStream<DictationState>
    private let continuation: AsyncStream<DictationState>.Continuation
    private var startedAt: Date?
    private var meter: Task<Void, Never>?

    init() {
        (states, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(16))
    }

    func start() async throws {
        let started = Date()
        startedAt = started
        let continuation = self.continuation
        meter = Task {
            var tick = 0.0
            while !Task.isCancelled {
                tick += 1
                continuation.yield(.recording(elapsed: Date().timeIntervalSince(started), level: Float(0.4 + 0.3 * sin(tick / 2))))
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    func stop() async throws -> AudioClip {
        meter?.cancel()
        let seconds = max(Date().timeIntervalSince(startedAt ?? Date()), 0.5)
        let samples = (0..<Int(seconds * 16_000)).map { Float(sin(Double($0) * 0.06)) * 0.3 }
        continuation.yield(.finished(duration: seconds))
        return AudioClip(samples: samples)
    }

    func cancel() {
        meter?.cancel()
        continuation.yield(.cancelled)
    }
}
#endif
