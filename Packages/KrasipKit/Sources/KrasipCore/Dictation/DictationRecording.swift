// DictationRecording.swift
// KrasipKit
// The dictation module seam: start, stop, cancel, and a stream of recording states.

import Foundation

public enum DictationState: Equatable, Sendable {
    case idle
    case requestingPermission
    case recording(elapsed: TimeInterval, level: Float)
    case stopping
    case finished(duration: TimeInterval)
    case cancelled
    case failed(DictationError)
}

public enum DictationError: Error, Equatable, Sendable, LocalizedError {
    case microphoneDenied
    case noInputDevice
    case engineFailure(String)
    case notRecording

    public var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            String(localized: "Krasip can't use the microphone. Allow it in System Settings → Privacy & Security → Microphone.", bundle: .module)
        case .noInputDevice:
            String(localized: "No microphone was found.", bundle: .module)
        case .engineFailure(let message):
            String(localized: "The microphone stopped unexpectedly: \(message)", bundle: .module)
        case .notRecording:
            String(localized: "Nothing is being recorded.", bundle: .module)
        }
    }
}

/// Owns microphone permission, audio buffering, and the recording timer.
/// Callers never handle audio chunks; they get one finished `AudioClip`.
@MainActor
public protocol DictationRecording: AnyObject {
    var states: AsyncStream<DictationState> { get }
    func start() async throws
    func stop() async throws -> AudioClip
    func cancel()
}
