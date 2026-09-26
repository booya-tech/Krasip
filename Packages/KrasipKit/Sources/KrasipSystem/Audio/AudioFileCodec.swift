// AudioFileCodec.swift
// KrasipKit
// Reads and writes recordings: WAV for uploads, M4A for kept audio, and any file back to a 16 kHz clip.

import AVFoundation
import KrasipCore

public enum AudioFileCodec {
    public enum CodecError: Error, Equatable {
        case emptyAudio
        case unreadable(String)
    }

    /// 16-bit PCM WAV bytes, the most widely accepted upload format.
    public static func wavData(_ clip: AudioClip) -> Data {
        let sampleRate = UInt32(clip.sampleRate)
        let dataSize = UInt32(clip.samples.count * 2)
        var data = Data(capacity: 44 + Int(dataSize))

        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36) + dataSize)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(sampleRate)
        append(sampleRate * 2)
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(dataSize)
        for sample in clip.samples {
            let clamped = max(-1, min(1, sample))
            append(Int16(clamped * Float(Int16.max)))
        }
        return data
    }

    public static func writeWAV(_ clip: AudioClip, to url: URL) throws {
        try wavData(clip).write(to: url, options: .atomic)
    }

    /// AAC in an M4A container: small enough to keep for "retry" without filling the disk.
    public static func writeM4A(_ clip: AudioClip, to url: URL) throws {
        guard !clip.samples.isEmpty else { throw CodecError.emptyAudio }
        guard let buffer = pcmBuffer(clip) else { throw CodecError.emptyAudio }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: clip.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
    }

    /// Decodes any audio file macOS understands into a 16 kHz mono clip.
    public static func read(_ url: URL) throws -> AudioClip {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard file.length > 0,
              let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw CodecError.emptyAudio
        }
        try file.read(into: input)

        guard let output = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: AudioClip.standardSampleRate, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: format, to: output) else {
            throw CodecError.unreadable("Unsupported audio format")
        }
        let capacity = AVAudioFrameCount(Double(input.frameLength) * output.sampleRate / format.sampleRate) + 1024
        guard let converted = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) else {
            throw CodecError.emptyAudio
        }
        let feeder = OneShotFeeder(input)
        var error: NSError?
        let status = converter.convert(to: converted, error: &error) { _, inputStatus in
            feeder.next(inputStatus)
        }
        if status == .error {
            throw CodecError.unreadable(error?.localizedDescription ?? "Conversion failed")
        }
        guard let channel = converted.floatChannelData?[0] else { throw CodecError.emptyAudio }
        return AudioClip(samples: Array(UnsafeBufferPointer(start: channel, count: Int(converted.frameLength))))
    }

    /// The clip as an AVAudioPCMBuffer (16 kHz mono Float32).
    public static func pcmBuffer(_ clip: AudioClip) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: clip.sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(clip.samples.count, 1))),
              let channel = buffer.floatChannelData?[0] else { return nil }
        clip.samples.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            channel.update(from: base, count: source.count)
        }
        buffer.frameLength = AVAudioFrameCount(clip.samples.count)
        return buffer
    }
}

/// Feeds a single buffer to a converter and then signals the end of the stream.
private final class OneShotFeeder: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func next(_ status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        guard let buffer else {
            status.pointee = .endOfStream
            return nil
        }
        self.buffer = nil
        status.pointee = .haveData
        return buffer
    }
}
