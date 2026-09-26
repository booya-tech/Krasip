// OnDeviceRecognitionTests.swift
// KrasipSystemTests
// Optional live check of Apple's on-device Thai recognizer using speech made with the system Thai voice.

import Foundation
import Testing
@testable import KrasipCore
@testable import KrasipSystem

/// Runs only when KRASIP_LIVE_ASR=1, because it needs macOS 26, the Thai speech model,
/// and the "Kanya" voice. Synthetic speech is a smoke test, not a quality measurement.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["KRASIP_LIVE_ASR"] == "1"))
struct OnDeviceRecognitionTests {
    private func synthesize(_ text: String) throws -> AudioClip {
        let aiff = FileManager.default.temporaryDirectory.appending(path: "krasip-\(UUID().uuidString).aiff")
        defer { try? FileManager.default.removeItem(at: aiff) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = ["-v", "Kanya", "-o", aiff.path, text]
        try process.run()
        process.waitUntilExit()
        return try AudioFileCodec.read(aiff)
    }

    @Test func recognizesPlainThaiOnDevice() async throws {
        guard #available(macOS 26.0, *) else { return }
        let clip = try synthesize("สวัสดีครับ วันนี้อากาศดีมาก")
        let transcript = try await AppleOnDeviceTranscriber().transcribe(clip, languages: [.thai, .english])
        #expect(transcript.rawText.contains("สวัสดี"))
        #expect(transcript.confidence != nil)
        #expect(transcript.providerID == TranscriberID.appleOnDevice.rawValue)
    }

    @Test func fullPipelineProducesFinalText() async throws {
        guard #available(macOS 26.0, *) else { return }
        let clip = try synthesize("วันนี้จะต้องกลับบ้านไปทำงาน")
        let transcript = try await AppleOnDeviceTranscriber().transcribe(clip, languages: [.thai, .english])
        let final = TextPolicy().finalize(transcript.rawText, glossary: Glossary())
        #expect(final.text.contains("กลับบ้าน"))
    }
}
