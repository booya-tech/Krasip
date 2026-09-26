// PermissionCenter.swift
// Krasip
// Observable permission status. Accessibility has no change callback, so it is polled while setup screens are open.

import AppKit
import Observation
import KrasipSystem

@MainActor
@Observable
final class PermissionCenter {
    private(set) var microphone: PermissionStatus = Permissions.microphone
    private(set) var accessibility: PermissionStatus = Permissions.accessibility
    private(set) var speechRecognition: PermissionStatus = Permissions.speechRecognition

    @ObservationIgnored private var pollers = 0
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var activationObserver: (any NSObjectProtocol)?

    init() {
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        microphone = Permissions.microphone
        accessibility = Permissions.accessibility
        speechRecognition = Permissions.speechRecognition
    }

    /// Everything dictation needs for the chosen speech engine.
    func isReady(for engine: SpeechEngine) -> Bool {
        microphone == .granted && accessibility == .granted
            && (engine != .appleOnline || speechRecognition == .granted)
    }

    func requestMicrophone() async {
        if microphone == .notDetermined {
            _ = await Permissions.requestMicrophone()
        } else {
            Permissions.open(.microphone)
        }
        refresh()
    }

    func requestAccessibility() {
        Permissions.requestAccessibility()
        refresh()
    }

    func requestSpeechRecognition() async {
        if speechRecognition == .notDetermined {
            _ = await Permissions.requestSpeechRecognition()
        } else {
            Permissions.open(.speechRecognition)
        }
        refresh()
    }

    /// Call from `onAppear`; balance with `stopPolling` in `onDisappear`.
    func startPolling() {
        pollers += 1
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopPolling() {
        pollers = max(pollers - 1, 0)
        if pollers == 0 {
            pollTask?.cancel()
            pollTask = nil
        }
    }
}
