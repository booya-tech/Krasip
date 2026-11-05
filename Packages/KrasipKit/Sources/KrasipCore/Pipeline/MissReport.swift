// MissReport.swift
// KrasipKit
// Turns one dictation into a report the user can file, as plain text and as a pre-filled GitHub issue.

import Foundation

public enum MissKind: String, CaseIterable, Sendable, Identifiable {
    case misheard
    case overCorrected
    case discardedFix
    case notSure
    case somethingElse

    public var id: String { rawValue }

    /// Everything but `somethingElse` blames the speech or correction model, so it belongs with the model.
    public var isModelMiss: Bool { self != .somethingElse }
}

public struct MissReport: Equatable, Sendable {
    public struct Destination: Equatable, Sendable {
        public let owner: String
        public let repo: String
        public let template: String

        public init(owner: String, repo: String, template: String) {
            self.owner = owner
            self.repo = repo
            self.template = template
        }
    }

    public static let modelRepo = Destination(owner: "booya-tech", repo: "krasip-correction", template: "miss.yml")
    /// App bugs land in the private repo too, because every report carries the reporter's own speech
    /// and the Krasip repo is public.
    public static let appRepo = Destination(owner: "booya-tech", repo: "krasip-correction", template: "bug.yml")

    /// A long dictation would otherwise build a URL no browser will open.
    static let fieldLimit = 1500

    public var kind: MissKind
    public var wantedText: String
    public var note: String
    public var heardText: String
    public var policyText: String
    public var typedText: String
    public var appName: String?
    public var confidence: Double?
    public var latency: TimeInterval?
    public var audioDuration: TimeInterval
    public var engine: String
    public var appVersion: String
    public var startedAt: Date
    public var timeZone: TimeZone

    public init(
        kind: MissKind = .notSure,
        wantedText: String = "",
        note: String = "",
        heardText: String,
        policyText: String,
        typedText: String,
        appName: String? = nil,
        confidence: Double? = nil,
        latency: TimeInterval? = nil,
        audioDuration: TimeInterval = 0,
        engine: String = "",
        appVersion: String = "",
        startedAt: Date = .now,
        timeZone: TimeZone = .current
    ) {
        self.kind = kind
        self.wantedText = wantedText
        self.note = note
        self.heardText = heardText
        self.policyText = policyText
        self.typedText = typedText
        self.appName = appName
        self.confidence = confidence
        self.latency = latency
        self.audioDuration = audioDuration
        self.engine = engine
        self.appVersion = appVersion
        self.startedAt = startedAt
        self.timeZone = timeZone
    }

    public init(record: DictationRecord, appVersion: String, timeZone: TimeZone = .current) {
        self.init(
            heardText: record.rawText,
            policyText: record.policyText,
            typedText: record.finalText,
            appName: record.destinationAppName,
            confidence: record.confidence,
            latency: record.latency,
            audioDuration: record.audioDuration,
            engine: record.providerID,
            appVersion: appVersion,
            startedAt: record.startedAt,
            timeZone: timeZone
        )
    }

    public var destination: Destination {
        kind.isModelMiss ? Self.modelRepo : Self.appRepo
    }

    /// A report with no answer in it wastes the reader's time, so sending waits for one.
    public var canSend: Bool {
        let filled = kind == .somethingElse ? note : wantedText
        return !filled.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var title: String {
        let subject = kind == .somethingElse ? note : typedText
        let cleaned = subject.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        let short = cleaned.count > 60 ? String(cleaned.prefix(60)) + "…" : cleaned
        return short.isEmpty ? kind.rawValue : "\(kind.rawValue): \(short)"
    }

    /// The block the user pastes into the issue. Fields nobody measured are left out, not printed empty.
    public var body: String {
        var lines = [
            row("heard", heardText),
            row("policy", policyText),
            row("typed", typedText)
        ]
        if !wantedText.isEmpty { lines.append(row("wanted", wantedText)) }
        if let appName { lines.append(row("app", appName)) }
        lines.append(row("numbers", numbers))
        if !engine.isEmpty { lines.append(row("engine", engine)) }
        if !appVersion.isEmpty { lines.append(row("krasip", appVersion)) }
        lines.append(row("at", timestamp))
        // Fenced, because the issue form cannot render it and the alignment is the point.
        return "```\n" + lines.joined(separator: "\n") + "\n```"
    }

    public var issueURL: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = "/\(destination.owner)/\(destination.repo)/issues/new"

        var items = [
            URLQueryItem(name: "template", value: destination.template),
            URLQueryItem(name: "title", value: clipped(title))
        ]
        if kind == .somethingElse {
            items.append(URLQueryItem(name: "what", value: clipped(note)))
        } else {
            items.append(URLQueryItem(name: "kind", value: formLabel))
            items.append(URLQueryItem(name: "typed", value: clipped(typedText)))
            items.append(URLQueryItem(name: "wanted", value: clipped(wantedText)))
        }
        items.append(URLQueryItem(name: "history", value: clipped(body)))
        components.queryItems = items
        return components.url
    }

    /// Must match an option in the issue form's dropdown, or GitHub ignores the pre-fill.
    var formLabel: String {
        switch kind {
        case .misheard: "It heard the wrong words"
        case .overCorrected: "It changed something that was already right"
        case .discardedFix: "It threw away a good fix"
        case .notSure: "Not sure"
        case .somethingElse: "Something else"
        }
    }

    private var numbers: String {
        var parts: [String] = []
        if let confidence { parts.append("confidence \(Int((confidence * 100).rounded()))%") }
        if let latency { parts.append(String(format: "latency %.2fs", latency)) }
        if audioDuration > 0 { parts.append(String(format: "audio %.1fs", audioDuration)) }
        return parts.isEmpty ? "none recorded" : parts.joined(separator: "   ")
    }

    private var timestamp: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZ"
        return formatter.string(from: startedAt)
    }

    private func row(_ label: String, _ value: String) -> String {
        let padded = label.padding(toLength: 9, withPad: " ", startingAt: 0)
        return "\(padded) \(value)"
    }

    private func clipped(_ text: String) -> String {
        text.count > Self.fieldLimit ? String(text.prefix(Self.fieldLimit)) + "…" : text
    }
}
