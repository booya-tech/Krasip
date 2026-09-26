// TranscriberFactory.swift
// Krasip
// Builds the transcription adapter for the chosen speech engine.

import Foundation
import KrasipCore
import KrasipSystem

enum TranscriberFactory {
    nonisolated static let openAIKeyAccount = "openai-api-key"

    static func make(_ engine: SpeechEngine, settings: AppSettings, keychain: KeychainStore) -> any Transcriber {
        switch engine {
        case .appleOnDevice:
            if #available(macOS 26.0, *) {
                return AppleOnDeviceTranscriber()
            }
            return AppleSpeechTranscriber()
        case .appleOnline:
            return AppleSpeechTranscriber()
        case .openAI:
            return OpenAITranscriber(configuration: settings.openAIConfiguration) {
                keychain.string(for: openAIKeyAccount)
            }
        }
    }
}
