// MicrophoneRecorder.swift
// KrasipKit
// The dictation module on macOS: microphone permission, AVAudioEngine capture, timer, and level meter.

import AVFoundation
import KrasipCore

@MainActor
public final class MicrophoneRecorder: DictationRecording {
    public let states: AsyncStream<DictationState>
    private let continuation: AsyncStream<DictationState>.Continuation

    private var engine: AVAudioEngine?
    private var sink: SampleSink?
    private var startedAt: Date?
    private var meterTask: Task<Void, Never>?
    private var configurationObserver: (any NSObjectProtocol)?

    /// Extra audio kept after the key is released, so the last syllable is not cut off.
    public var releaseTail: Duration = .milliseconds(180)
    /// A specific microphone (Core Audio UID). `nil`, or a device that is not connected,
    /// means the system default input.
    public var preferredDeviceUID: String?

    public init() {
        (states, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(16))
    }

    public static var permission: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    public static func requestPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    public var isRecording: Bool { engine != nil }

    public func start() async throws {
        if engine != nil {
            cancel()
        }

        switch Self.permission {
        case .authorized:
            break
        case .notDetermined:
            continuation.yield(.requestingPermission)
            guard await Self.requestPermission() else {
                continuation.yield(.failed(.microphoneDenied))
                throw DictationError.microphoneDenied
            }
        default:
            continuation.yield(.failed(.microphoneDenied))
            throw DictationError.microphoneDenied
        }
        try Task.checkCancellation()

        let engine = AVAudioEngine()
        let input = engine.inputNode
        selectPreferredDevice(on: input)
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            continuation.yield(.failed(.noInputDevice))
            throw DictationError.noInputDevice
        }

        let sink = try SampleSink(inputFormat: format)
        input.installTap(onBus: 0, bufferSize: 2048, format: format, block: Self.tapBlock(for: sink))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            let failure = DictationError.engineFailure(error.localizedDescription)
            continuation.yield(.failed(failure))
            throw failure
        }

        self.engine = engine
        self.sink = sink
        let startedAt = Date()
        self.startedAt = startedAt
        observeConfigurationChanges(of: engine)
        startMeter(sink: sink, startedAt: startedAt)
    }

    public func stop() async throws -> AudioClip {
        guard let engine, let sink else { throw DictationError.notRecording }
        continuation.yield(.stopping)
        try? await Task.sleep(for: releaseTail)
        guard self.engine === engine else { throw CancellationError() }

        tearDown(engine)
        let clip = AudioClip(samples: sink.collected())
        reset()
        continuation.yield(.finished(duration: clip.duration))
        return clip
    }

    public func cancel() {
        guard let engine else { return }
        tearDown(engine)
        reset()
        continuation.yield(.cancelled)
    }

    // MARK: - Private

    /// Built outside the main actor so the closure is not main-actor isolated; AVAudioEngine
    /// calls it on its real-time thread.
    private nonisolated static func tapBlock(for sink: SampleSink) -> AVAudioNodeTapBlock {
        { buffer, _ in sink.append(buffer) }
    }

    private func selectPreferredDevice(on input: AVAudioInputNode) {
        guard let uid = preferredDeviceUID,
              let device = AudioInputDevices.device(uid: uid),
              let unit = input.audioUnit else { return }
        var deviceID = device.deviceID
        AudioUnitSetProperty(
            unit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
    }

    private func startMeter(sink: SampleSink, startedAt: Date) {
        meterTask?.cancel()
        let continuation = self.continuation
        meterTask = Task { [weak self] in
            while !Task.isCancelled, self?.engine != nil {
                continuation.yield(.recording(elapsed: Date().timeIntervalSince(startedAt), level: sink.level))
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func observeConfigurationChanges(of engine: AVAudioEngine) {
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleConfigurationChange()
            }
        }
    }

    /// The input device changed mid-recording, e.g. AirPods switching to their microphone
    /// mode or being unplugged. Reconnect to the new input and keep recording; fail only if
    /// there is no usable microphone left.
    private func handleConfigurationChange() {
        guard let engine, let sink, !engine.isRunning else { return }
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0, sink.switchInput(to: format) else {
            tearDown(engine)
            reset()
            continuation.yield(.failed(.noInputDevice))
            return
        }
        input.installTap(onBus: 0, bufferSize: 2048, format: format, block: Self.tapBlock(for: sink))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            tearDown(engine)
            reset()
            continuation.yield(.failed(.engineFailure("The microphone changed while recording.")))
        }
    }

    private func tearDown(_ engine: AVAudioEngine) {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func reset() {
        meterTask?.cancel()
        meterTask = nil
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
        engine = nil
        sink = nil
        startedAt = nil
    }
}
