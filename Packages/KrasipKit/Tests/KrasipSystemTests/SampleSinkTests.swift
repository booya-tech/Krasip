// SampleSinkTests.swift
// KrasipSystemTests
// Microphone buffers of any format become 16 kHz mono samples, even when the device changes mid-recording.

import AVFoundation
import Testing
@testable import KrasipCore
@testable import KrasipSystem

struct SampleSinkTests {
    private func tone(format: AVAudioFormat, seconds: Double) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(format.sampleRate * seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for channel in 0..<Int(format.channelCount) {
            let data = buffer.floatChannelData![channel]
            for frame in 0..<Int(frames) {
                data[frame] = Float(sin(2 * Double.pi * 440 * Double(frame) / format.sampleRate)) * 0.5
            }
        }
        return buffer
    }

    @Test func convertsStereo48kTo16kMono() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let sink = try SampleSink(inputFormat: format)
        for _ in 0..<10 {
            sink.append(tone(format: format, seconds: 0.1))
        }
        let samples = sink.collected()
        #expect(abs(samples.count - 16_000) < 400)
        #expect(sink.level > 0.5)
        #expect(AudioClip(samples: samples).rms > 0.2)
    }

    @Test func keepsRecordingAfterTheMicrophoneChanges() throws {
        let first = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        let second = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!
        let sink = try SampleSink(inputFormat: first)
        for _ in 0..<5 {
            sink.append(tone(format: first, seconds: 0.1))
        }
        #expect(sink.switchInput(to: second))
        for _ in 0..<5 {
            sink.append(tone(format: second, seconds: 0.1))
        }
        #expect(abs(sink.collected().count - 16_000) < 600)
    }

    @Test func ignoresBuffersInAnOldFormat() throws {
        let first = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        let second = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let sink = try SampleSink(inputFormat: first)
        #expect(sink.switchInput(to: second))
        sink.append(tone(format: first, seconds: 0.1))
        #expect(sink.collected().isEmpty)
    }

    @Test func silenceHasZeroLevel() throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let sink = try SampleSink(inputFormat: format)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410)!
        buffer.frameLength = 4_410
        sink.append(buffer)
        #expect(sink.level == 0)
    }
}
