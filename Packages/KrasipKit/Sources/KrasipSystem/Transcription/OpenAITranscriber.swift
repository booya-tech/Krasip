// OpenAITranscriber.swift
// KrasipKit
// Cloud transcription adapter for OpenAI-compatible /audio/transcriptions endpoints (OpenAI, Groq, and others).

import Foundation
import KrasipCore

public struct OpenAIConfiguration: Codable, Equatable, Sendable {
    public var baseURL: URL
    public var model: String
    /// Send the primary language ("th") as a hint. Turning it off lets the service guess.
    public var sendLanguageHint: Bool

    public init(baseURL: URL = OpenAIConfiguration.defaultBaseURL, model: String = "gpt-4o-transcribe", sendLanguageHint: Bool = true) {
        self.baseURL = baseURL
        self.model = model
        self.sendLanguageHint = sendLanguageHint
    }

    public static let defaultBaseURL = URL(string: "https://api.openai.com/v1")!
    public static let suggestedModels = ["gpt-4o-transcribe", "gpt-4o-mini-transcribe", "whisper-1"]

    var endpoint: URL { baseURL.appending(path: "audio/transcriptions") }

    /// A Whisper server on this Mac (e.g. whisper.cpp or LocalAI) usually needs no key.
    public var isLocal: Bool {
        guard let host = baseURL.host()?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasSuffix(".local")
    }

    var requiresAPIKey: Bool { !isLocal }
    var usesVerboseJSON: Bool { model.lowercased().contains("whisper") }
    var supportsLogprobs: Bool { model.lowercased().hasPrefix("gpt-4o") }
}

/// Sends the recording as WAV. Only audio and spelling hints are sent: the transcript is never
/// sent anywhere to be rewritten.
public final class OpenAITranscriber: Transcriber {
    public let id: TranscriberID = .openAI
    private let configuration: OpenAIConfiguration
    private let apiKey: @Sendable () -> String?
    private let session: URLSession

    public init(configuration: OpenAIConfiguration, session: URLSession = .shared, apiKey: @escaping @Sendable () -> String?) {
        self.configuration = configuration
        self.session = session
        self.apiKey = apiKey
    }

    public func transcribe(_ audio: AudioClip, languages: [Language], vocabulary: [String]) async throws -> Transcript {
        let key = apiKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty || !configuration.requiresAPIKey else {
            throw TranscriptionError.missingAPIKey
        }
        let request = OpenAIRequest.make(
            configuration: configuration,
            apiKey: key,
            wav: AudioFileCodec.wavData(audio),
            languages: languages,
            vocabulary: vocabulary
        )

        let started = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw TranscriptionError.timedOut
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw TranscriptionError.network(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300:
            let parsed = try OpenAIRequest.parse(data)
            return Transcript(
                rawText: parsed.text.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: parsed.confidence,
                providerID: id.rawValue,
                processingDuration: Date().timeIntervalSince(started)
            )
        case 401, 403:
            throw TranscriptionError.invalidAPIKey
        case 429:
            throw TranscriptionError.rateLimited
        default:
            throw TranscriptionError.provider(status: status, message: OpenAIRequest.errorMessage(data) ?? "HTTP \(status)")
        }
    }

    /// Sends a short silent clip to check the key and endpoint. Returns nil on success.
    public func checkConnection() async -> TranscriptionError? {
        let silence = AudioClip(samples: [Float](repeating: 0, count: 8_000))
        do {
            _ = try await transcribe(silence, languages: [.english], vocabulary: [])
            return nil
        } catch let error as TranscriptionError {
            return error == .noSpeech ? nil : error
        } catch {
            return .network(error.localizedDescription)
        }
    }
}

enum OpenAIRequest {
    struct Parsed: Equatable {
        let text: String
        let confidence: Double?
        let language: String?
    }

    static func make(
        configuration: OpenAIConfiguration,
        apiKey: String,
        wav: Data,
        languages: [Language],
        vocabulary: [String],
        boundary: String = "Krasip-\(UUID().uuidString)"
    ) -> URLRequest {
        var fields: [(String, String)] = [
            ("model", configuration.model),
            ("response_format", configuration.usesVerboseJSON ? "verbose_json" : "json"),
            ("temperature", "0")
        ]
        if configuration.sendLanguageHint {
            fields.append(("language", Language.primary(of: languages).isoCode))
        }
        if let prompt = prompt(languages: languages, vocabulary: vocabulary, model: configuration.model) {
            fields.append(("prompt", prompt))
        }
        if configuration.supportsLogprobs {
            fields.append(("include[]", "logprobs"))
        }

        var request = URLRequest(url: configuration.endpoint, timeoutInterval: 60)
        request.httpMethod = "POST"
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(boundary: boundary, fields: fields, file: wav, fileName: "dictation.wav", mimeType: "audio/wav")
        return request
    }

    /// Spelling guidance only. GPT-4o transcription models follow instructions; Whisper models
    /// follow the style of example text, so they get a short mixed Thai-English sample instead.
    static func prompt(languages: [Language], vocabulary: [String], model: String) -> String? {
        let mixed = languages.contains(.thai) && languages.contains(.english)
        let terms = vocabulary.prefix(40).joined(separator: ", ")
        if model.lowercased().hasPrefix("gpt-4o") {
            var prompt = "Transcribe exactly what is said, without translating or rewording."
            if mixed {
                prompt += " The speaker mixes Thai and English: write Thai words in Thai script and English words in English letters."
            }
            if !terms.isEmpty {
                prompt += " Preferred spellings: \(terms)."
            }
            return prompt
        }
        var parts: [String] = []
        if mixed {
            parts.append("วันนี้ต้อง push code ขึ้น GitHub แล้วส่ง pull request ให้ทีม review นะครับ")
        }
        if !terms.isEmpty {
            parts.append(terms)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    static func multipartBody(boundary: String, fields: [(String, String)], file: Data, fileName: String, mimeType: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        for (name, value) in fields {
            body.append(Data("--\(boundary)\(lineBreak)".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak)\(lineBreak)".utf8))
            body.append(Data("\(value)\(lineBreak)".utf8))
        }
        body.append(Data("--\(boundary)\(lineBreak)".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(lineBreak)".utf8))
        body.append(Data("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".utf8))
        body.append(file)
        body.append(Data("\(lineBreak)--\(boundary)--\(lineBreak)".utf8))
        return body
    }

    static func parse(_ data: Data) throws -> Parsed {
        struct Body: Decodable {
            struct LogProb: Decodable { let logprob: Double }
            struct Segment: Decodable {
                let start: Double?
                let end: Double?
                let avg_logprob: Double?
            }
            let text: String
            let language: String?
            let logprobs: [LogProb]?
            let segments: [Segment]?
        }
        let body: Body
        do {
            body = try JSONDecoder().decode(Body.self, from: data)
        } catch {
            throw TranscriptionError.provider(status: 200, message: "Unexpected response from the speech service.")
        }

        var confidence: Double?
        if let logprobs = body.logprobs, !logprobs.isEmpty {
            let mean = logprobs.reduce(0) { $0 + $1.logprob } / Double(logprobs.count)
            confidence = exp(mean)
        } else if let segments = body.segments?.filter({ $0.avg_logprob != nil }), !segments.isEmpty {
            var total = 0.0
            var weight = 0.0
            for segment in segments {
                let duration = max((segment.end ?? 0) - (segment.start ?? 0), 0.1)
                total += (segment.avg_logprob ?? 0) * duration
                weight += duration
            }
            confidence = exp(total / weight)
        }
        return Parsed(text: body.text, confidence: confidence, language: body.language)
    }

    static func errorMessage(_ data: Data) -> String? {
        struct Body: Decodable {
            struct Detail: Decodable { let message: String }
            let error: Detail
        }
        return (try? JSONDecoder().decode(Body.self, from: data))?.error.message
    }
}
