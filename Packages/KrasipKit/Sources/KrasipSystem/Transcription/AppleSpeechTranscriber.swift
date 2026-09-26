// AppleSpeechTranscriber.swift
// KrasipKit
// Transcription adapter for Apple's Speech framework (SFSpeechRecognizer), available on macOS 14 and later.

import AVFoundation
import Speech
import KrasipCore

/// Uses Apple's server-based recognizer for Thai (on-device when the Mac supports it and
/// `requiresOnDevice` is set). Needs the Speech Recognition permission.
public final class AppleSpeechTranscriber: Transcriber {
    public let id: TranscriberID = .appleServer
    public let requiresOnDevice: Bool

    public init(requiresOnDevice: Bool = false) {
        self.requiresOnDevice = requiresOnDevice
    }

    public static var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    public static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    public func transcribe(_ audio: AudioClip, languages: [Language], vocabulary: [String]) async throws -> Transcript {
        var status = Self.authorizationStatus
        if status == .notDetermined {
            status = await Self.requestAuthorization()
        }
        guard status == .authorized else { throw TranscriptionError.notAuthorized }

        let language = Language.primary(of: languages)
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language.localeIdentifier)) else {
            throw TranscriptionError.unavailable("\(language.displayName) is not supported by Apple speech recognition.")
        }
        guard recognizer.isAvailable else {
            throw TranscriptionError.unavailable("Apple speech recognition is not reachable right now. Check your internet connection.")
        }
        guard let buffer = AudioFileCodec.pcmBuffer(audio) else { throw TranscriptionError.noSpeech }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        request.addsPunctuation = true
        request.contextualStrings = Array(vocabulary.prefix(100))
        if requiresOnDevice {
            guard recognizer.supportsOnDeviceRecognition else {
                throw TranscriptionError.unavailable("On-device recognition for \(language.displayName) is not available on this Mac.")
            }
            request.requiresOnDeviceRecognition = true
        }
        request.append(buffer)
        request.endAudio()

        let started = Date()
        let result = try await Self.recognize(recognizer, request)
        return Transcript(
            rawText: result.text,
            confidence: result.confidence,
            providerID: id.rawValue,
            processingDuration: Date().timeIntervalSince(started)
        )
    }

    private struct Recognition: Sendable {
        let text: String
        let confidence: Double?
    }

    private static func recognize(_ recognizer: SFSpeechRecognizer, _ request: SFSpeechAudioBufferRecognitionRequest) async throws -> Recognition {
        let holder = TaskHolder()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Recognition, any Error>) in
                let once = ResumeOnce(continuation)
                holder.task = recognizer.recognitionTask(with: request) { result, error in
                    if let result, result.isFinal {
                        once.resume(returning: Recognition(
                            text: result.bestTranscription.formattedString,
                            confidence: confidence(of: result.bestTranscription)
                        ))
                    } else if let error {
                        once.resume(throwing: map(error))
                    }
                }
            }
        } onCancel: {
            holder.task?.cancel()
        }
    }

    /// Duration-weighted mean of segment confidence. Apple reports 0 when it has no value.
    private static func confidence(of transcription: SFTranscription) -> Double? {
        let scored = transcription.segments.filter { $0.confidence > 0 }
        guard !scored.isEmpty else { return nil }
        let totalDuration = scored.reduce(0) { $0 + max($1.duration, 0.01) }
        let weighted = scored.reduce(0) { $0 + Double($1.confidence) * max($1.duration, 0.01) }
        return weighted / totalDuration
    }

    private static func map(_ error: any Error) -> TranscriptionError {
        let nsError = error as NSError
        if nsError.domain == "kAFAssistantErrorDomain", [203, 1110].contains(nsError.code) {
            return .noSpeech
        }
        if nsError.domain == NSURLErrorDomain {
            return .network(nsError.localizedDescription)
        }
        return .unavailable(nsError.localizedDescription)
    }
}

private final class TaskHolder: @unchecked Sendable {
    var task: SFSpeechRecognitionTask?
}

/// Resumes a continuation at most once; recognition callbacks can fire several times.
final class ResumeOnce<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?

    init(_ continuation: CheckedContinuation<Value, any Error>) {
        self.continuation = continuation
    }

    func resume(returning value: Value) {
        take()?.resume(returning: value)
    }

    func resume(throwing error: any Error) {
        take()?.resume(throwing: error)
    }

    private func take() -> CheckedContinuation<Value, any Error>? {
        lock.lock()
        defer { lock.unlock() }
        let current = continuation
        continuation = nil
        return current
    }
}
