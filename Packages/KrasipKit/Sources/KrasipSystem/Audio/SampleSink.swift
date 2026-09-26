// SampleSink.swift
// KrasipKit
// Thread-safe collector that converts microphone buffers to 16 kHz mono samples on the audio thread.

import AVFoundation
import KrasipCore

/// Receives buffers on the real-time audio thread. Everything it touches is guarded by a lock,
/// and the converter is only ever used from that one thread.
final class SampleSink: @unchecked Sendable {
    private let lock = NSLock()
    private var converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private var samples: [Float] = []
    private var currentLevel: Float = 0

    init(inputFormat: AVAudioFormat) throws {
        guard let output = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioClip.standardSampleRate,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: inputFormat, to: output) else {
            throw DictationError.engineFailure("This microphone format is not supported.")
        }
        outputFormat = output
        self.converter = converter
        samples.reserveCapacity(Int(AudioClip.standardSampleRate) * 30)
    }

    /// Switches to a new input format (the microphone changed mid-recording) and keeps the
    /// samples collected so far.
    func switchInput(to format: AVAudioFormat) -> Bool {
        guard let replacement = AVAudioConverter(from: format, to: outputFormat) else { return false }
        lock.lock()
        converter = replacement
        lock.unlock()
        return true
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        lock.lock()
        let converter = self.converter
        lock.unlock()
        guard converter.inputFormat == buffer.format else { return }

        let feeder = BufferFeeder(buffer)
        var error: NSError?
        let status = converter.convert(to: converted, error: &error) { _, inputStatus in
            feeder.next(inputStatus)
        }
        guard status != .error, let channel = converted.floatChannelData?[0] else { return }

        let count = Int(converted.frameLength)
        var sum: Float = 0
        for index in 0..<count {
            sum += channel[index] * channel[index]
        }
        let rms = count > 0 ? (sum / Float(count)).squareRoot() : 0

        lock.lock()
        samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: count))
        currentLevel = rms
        lock.unlock()
    }

    /// Loudness of the latest buffer mapped to 0...1 (-50 dBFS → 0, 0 dBFS → 1).
    var level: Float {
        lock.lock()
        defer { lock.unlock() }
        guard currentLevel > 0 else { return 0 }
        let decibels = 20 * log10(currentLevel)
        return min(max((decibels + 50) / 50, 0), 1)
    }

    func collected() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        return samples
    }
}

/// Hands one buffer to the converter, then reports "no data for now" so the converter keeps
/// its resampling state between buffers.
private final class BufferFeeder: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func next(_ status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        guard let buffer else {
            status.pointee = .noDataNow
            return nil
        }
        self.buffer = nil
        status.pointee = .haveData
        return buffer
    }
}
