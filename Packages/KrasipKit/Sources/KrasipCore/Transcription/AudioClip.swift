// AudioClip.swift
// KrasipKit
// A finished recording: 16 kHz mono samples plus simple loudness measurements.

import Foundation

public struct AudioClip: Sendable, Equatable {
    public static let standardSampleRate: Double = 16_000

    /// Mono PCM samples in -1...1.
    public var samples: [Float]
    public var sampleRate: Double

    public init(samples: [Float], sampleRate: Double = AudioClip.standardSampleRate) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    public var duration: TimeInterval {
        sampleRate > 0 ? Double(samples.count) / sampleRate : 0
    }

    public var peak: Float {
        samples.reduce(0) { max($0, abs($1)) }
    }

    public var rms: Float {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sum / Float(samples.count)).squareRoot()
    }

    /// Seconds of audio whose 20 ms windows are louder than `threshold` (RMS).
    /// Used to skip transcription of silent recordings, where recognizers invent text.
    public func voicedDuration(threshold: Float) -> TimeInterval {
        let window = max(Int(sampleRate * 0.02), 1)
        guard samples.count >= window else { return 0 }
        var voicedWindows = 0
        var start = 0
        while start + window <= samples.count {
            var sum: Float = 0
            for index in start..<(start + window) {
                sum += samples[index] * samples[index]
            }
            if (sum / Float(window)).squareRoot() > threshold {
                voicedWindows += 1
            }
            start += window
        }
        return Double(voicedWindows * window) / sampleRate
    }
}
