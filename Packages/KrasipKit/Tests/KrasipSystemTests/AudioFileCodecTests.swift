// AudioFileCodecTests.swift
// KrasipSystemTests
// WAV bytes are valid, M4A files round-trip, and audio of any sample rate reads back as 16 kHz mono.

import Foundation
import Testing
@testable import KrasipCore
@testable import KrasipSystem

struct AudioFileCodecTests {
    private func tone(seconds: Double, sampleRate: Double = 16_000) -> AudioClip {
        let count = Int(seconds * sampleRate)
        let samples = (0..<count).map { Float(sin(2 * Double.pi * 440 * Double($0) / sampleRate)) * 0.5 }
        return AudioClip(samples: samples, sampleRate: sampleRate)
    }

    private func temporaryURL(_ extension: String) -> URL {
        FileManager.default.temporaryDirectory.appending(path: "krasip-\(UUID().uuidString).\(`extension`)")
    }

    @Test func wavHeaderIsCorrect() {
        let clip = tone(seconds: 0.5)
        let data = AudioFileCodec.wavData(clip)
        #expect(data.count == 44 + clip.samples.count * 2)
        #expect(String(decoding: data[0..<4], as: UTF8.self) == "RIFF")
        #expect(String(decoding: data[8..<12], as: UTF8.self) == "WAVE")
        #expect(String(decoding: data[36..<40], as: UTF8.self) == "data")
        let sampleRate = data[24..<28].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        #expect(UInt32(littleEndian: sampleRate) == 16_000)
    }

    @Test func wavRoundTrips() throws {
        let clip = tone(seconds: 1)
        let url = temporaryURL("wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try AudioFileCodec.writeWAV(clip, to: url)
        let read = try AudioFileCodec.read(url)
        #expect(abs(read.duration - clip.duration) < 0.05)
        #expect(abs(read.rms - clip.rms) < 0.02)
    }

    @Test func m4aRoundTripsForKeptAudio() throws {
        let clip = tone(seconds: 1.5)
        let url = temporaryURL("m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        try AudioFileCodec.writeM4A(clip, to: url)
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        #expect(size > 0)
        #expect(size < AudioFileCodec.wavData(clip).count)
        let read = try AudioFileCodec.read(url)
        #expect(abs(read.duration - clip.duration) < 0.2)
        #expect(read.rms > 0.1)
    }

    @Test func resamplesOtherRatesTo16k() throws {
        let clip = tone(seconds: 1, sampleRate: 48_000)
        let url = temporaryURL("wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try AudioFileCodec.writeWAV(clip, to: url)
        let read = try AudioFileCodec.read(url)
        #expect(read.sampleRate == 16_000)
        #expect(abs(read.duration - 1) < 0.05)
    }

    @Test func voicedDurationSeparatesSpeechFromSilence() {
        let silence = AudioClip(samples: [Float](repeating: 0, count: 16_000))
        #expect(silence.voicedDuration(threshold: 0.005) == 0)
        #expect(tone(seconds: 1).voicedDuration(threshold: 0.005) > 0.9)
    }
}

struct AudioInputDevicesTests {
    @Test func listsDevicesWithNamesAndStableIDs() {
        let devices = AudioInputDevices.all()
        #expect(Set(devices.map(\.uid)).count == devices.count)
        #expect(devices.allSatisfy { !$0.name.isEmpty && !$0.uid.isEmpty })
    }
}
