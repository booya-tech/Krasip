// SpeechModelStatus.swift
// Krasip
// Tracks whether Apple's on-device Thai speech model is installed, and downloads it on request.

import Foundation
import Observation
import KrasipCore
import KrasipSystem

@MainActor
@Observable
final class SpeechModelStatus {
    enum State: Equatable {
        case checking
        case unsupported
        case notInstalled
        case downloading(Double)
        case installed
        case failed(String)
    }

    private(set) var state: State = .checking

    func refresh(for language: Language) async {
        guard #available(macOS 26.0, *) else {
            state = .unsupported
            return
        }
        if case .downloading = state { return }
        switch await AppleOnDeviceTranscriber.modelState(for: language) {
        case .unsupported: state = .unsupported
        case .notInstalled: state = .notInstalled
        case .downloading: state = .downloading(0)
        case .installed: state = .installed
        }
    }

    func download(for language: Language) async {
        guard #available(macOS 26.0, *) else { return }
        state = .downloading(0)
        do {
            try await AppleOnDeviceTranscriber.prepareModel(for: language) { [weak self] fraction in
                Task { @MainActor in
                    guard let self, case .downloading = self.state else { return }
                    self.state = .downloading(fraction)
                }
            }
            state = .installed
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
