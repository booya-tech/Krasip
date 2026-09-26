// OpenAIRequestTests.swift
// KrasipSystemTests
// The cloud adapter builds correct multipart requests, sends only spelling hints, and parses both response shapes.

import Foundation
import Testing
@testable import KrasipCore
@testable import KrasipSystem

struct OpenAIRequestTests {
    private func body(_ request: URLRequest) -> String {
        String(decoding: request.httpBody ?? Data(), as: UTF8.self)
    }

    @Test func buildsMultipartRequestForGPT4oTranscribe() {
        let request = OpenAIRequest.make(
            configuration: OpenAIConfiguration(),
            apiKey: "sk-test",
            wav: Data("RIFF".utf8),
            languages: [.thai, .english],
            vocabulary: ["side-project", "GitHub"],
            boundary: "B"
        )
        #expect(request.url?.absoluteString == "https://api.openai.com/v1/audio/transcriptions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=B")

        let text = body(request)
        #expect(text.contains("name=\"model\"\r\n\r\ngpt-4o-transcribe\r\n"))
        #expect(text.contains("name=\"response_format\"\r\n\r\njson\r\n"))
        #expect(text.contains("name=\"language\"\r\n\r\nth\r\n"))
        #expect(text.contains("name=\"include[]\"\r\n\r\nlogprobs\r\n"))
        #expect(text.contains("Preferred spellings: side-project, GitHub."))
        #expect(text.contains("filename=\"dictation.wav\""))
        #expect(text.hasSuffix("--B--\r\n"))
    }

    @Test func whisperModelsUseVerboseJSONAndExamplePrompt() {
        let configuration = OpenAIConfiguration(model: "whisper-1")
        let request = OpenAIRequest.make(configuration: configuration, apiKey: "k", wav: Data(), languages: [.thai, .english], vocabulary: [], boundary: "B")
        let text = body(request)
        #expect(text.contains("verbose_json"))
        #expect(!text.contains("include[]"))
        #expect(text.contains("push code ขึ้น GitHub"))
    }

    @Test func languageHintCanBeTurnedOff() {
        let configuration = OpenAIConfiguration(sendLanguageHint: false)
        let request = OpenAIRequest.make(configuration: configuration, apiKey: "k", wav: Data(), languages: [.thai], vocabulary: [], boundary: "B")
        #expect(!body(request).contains("name=\"language\""))
    }

    @Test func customEndpointIsUsed() {
        let configuration = OpenAIConfiguration(baseURL: URL(string: "https://api.groq.com/openai/v1")!, model: "whisper-large-v3")
        let request = OpenAIRequest.make(configuration: configuration, apiKey: "k", wav: Data(), languages: [.thai], vocabulary: [], boundary: "B")
        #expect(request.url?.absoluteString == "https://api.groq.com/openai/v1/audio/transcriptions")
    }

    @Test func parsesJSONWithLogprobs() throws {
        let json = #"{"text":"เดี๋ยว push code ขึ้น GitHub","logprobs":[{"token":"a","logprob":-0.1},{"token":"b","logprob":-0.3}]}"#
        let parsed = try OpenAIRequest.parse(Data(json.utf8))
        #expect(parsed.text == "เดี๋ยว push code ขึ้น GitHub")
        #expect(abs((parsed.confidence ?? 0) - exp(-0.2)) < 0.0001)
    }

    @Test func parsesVerboseJSONSegments() throws {
        let json = #"{"task":"transcribe","language":"thai","text":"ส่ง pull request","segments":[{"start":0,"end":1,"avg_logprob":-0.2},{"start":1,"end":3,"avg_logprob":-0.5}]}"#
        let parsed = try OpenAIRequest.parse(Data(json.utf8))
        #expect(parsed.language == "thai")
        #expect(abs((parsed.confidence ?? 0) - exp(-0.4)) < 0.0001)
    }

    @Test func plainJSONHasNoConfidence() throws {
        let parsed = try OpenAIRequest.parse(Data(#"{"text":"hello"}"#.utf8))
        #expect(parsed.confidence == nil)
    }

    @Test func readsErrorMessages() {
        let message = OpenAIRequest.errorMessage(Data(#"{"error":{"message":"Invalid file format.","type":"invalid_request_error"}}"#.utf8))
        #expect(message == "Invalid file format.")
    }

    @Test func localServersNeedNoKey() {
        let local = OpenAIConfiguration(baseURL: URL(string: "http://localhost:8080/v1")!, model: "whisper-large-v3")
        #expect(local.isLocal)
        #expect(!OpenAIConfiguration().isLocal)
        let request = OpenAIRequest.make(configuration: local, apiKey: "", wav: Data(), languages: [.thai], vocabulary: [], boundary: "B")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.url?.absoluteString == "http://localhost:8080/v1/audio/transcriptions")
    }

    @Test func missingKeyFailsBeforeAnyNetworkCall() async {
        let transcriber = OpenAITranscriber(configuration: OpenAIConfiguration()) { nil }
        await #expect(throws: TranscriptionError.missingAPIKey) {
            try await transcriber.transcribe(AudioClip(samples: [0.1]), languages: [.thai])
        }
    }
}
