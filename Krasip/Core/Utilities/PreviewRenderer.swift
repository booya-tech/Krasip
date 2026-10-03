// PreviewRenderer.swift
// Krasip
// Debug-only: `Krasip --render-previews <folder>` saves PNGs of the overlay and every window, then quits.

#if DEBUG
import AppKit
import SwiftUI
import KrasipCore
import KrasipStorage

@MainActor
enum PreviewRenderer {
    static var isRequested: Bool {
        CommandLine.arguments.contains("--render-previews")
    }

    private static var outputFolder: URL? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--render-previews"), index + 1 < arguments.count else { return nil }
        return URL(fileURLWithPath: arguments[index + 1])
    }

    /// A controller on throwaway storage, filled with sample data. Real user data is never touched.
    static func makeController() -> AppController {
        let defaults = UserDefaults(suiteName: "com.bliumworks.krasip.previews") ?? .standard
        defaults.removePersistentDomain(forName: "com.bliumworks.krasip.previews")
        let store = try! KrasipStore.inMemory()
        let app = AppController(defaults: defaults, store: store)
        app.glossary.save(GlossaryEntry(aliases: ["กิตฮับ", "กิทฮับ"], preferredOutput: "GitHub", mode: .suggest))
        app.glossary.save(GlossaryEntry(aliases: ["พูลรีเควสต์"], preferredOutput: "pull request", mode: .locked))

        let glossary = app.glossary.glossary
        let samples: [(String, String, Double, InsertionResult)] = [
            ("วันนี้จะต้องกลับบ้านไปทำ side project", "Notes", 0.92, .inserted(.accessibility)),
            ("เดี๋ยว push code ขึ้น GitHub", "Slack", 0.88, .inserted(.paste)),
            ("นัดกับพี่แบงก์ตอน ten AM", "Calendar", 0.81, .inserted(.paste)),
            ("ส่ง พูลรีเควสต์ ให้ทีม", "Google Chrome", 0.41, .copiedToClipboard(.appRejected)),
            ("ทำไซด์โปรเจ็กต์ต่อ", "Notes", 0.77, .inserted(.accessibility)),
            ("ไปทำไซด์โปรเจ็กต์ก่อน", "Notes", 0.74, .inserted(.accessibility))
        ]
        var ids: [UUID] = []
        for (offset, sample) in samples.enumerated() {
            let final = TextPolicy().finalize(sample.0, glossary: glossary)
            let record = DictationRecord(
                startedAt: Date().addingTimeInterval(Double(-offset * 900)),
                rawText: sample.0,
                finalText: final.text,
                destinationBundleID: "com.example.\(sample.1)",
                destinationAppName: sample.1,
                confidence: sample.2,
                providerID: TranscriberID.appleOnDevice.rawValue,
                audioDuration: 2.4,
                latency: 0.6 + Double(offset) * 0.1,
                insertion: sample.3,
                changes: final.changes
            )
            app.history.add(record)
            ids.append(record.id)
        }
        app.history.applyCorrection(id: ids[4], text: "ทำ side-project ต่อ")
        app.history.applyCorrection(id: ids[5], text: "ไปทำ side-project ก่อน")
        app.history.selection = ids[0]
        return app
    }

    static func run(app: AppController) {
        guard let folder = outputFolder else {
            NSApp.terminate(nil)
            return
        }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        Task {
            await render(app: app, to: folder)
            NSApp.terminate(nil)
        }
    }

    private static func render(app: AppController, to folder: URL) async {
        for (name, phase) in samplePhases(app: app) {
            let card = OverlayCardView(phase: phase)
                .environment(app)
                .padding(28)
                .background(LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
            await snapshot(AnyView(card), size: nil, dark: true, name: "overlay-\(name)", folder: folder)
        }
        for tab in [SettingsTab.general, .languages, .glossary, .privacy] {
            app.settingsTab = tab
            await snapshot(AnyView(SettingsView().environment(app)), size: CGSize(width: 784, height: 644), dark: false, name: "settings-\(tab.rawValue)", folder: folder)
        }
        await snapshot(AnyView(HistoryView().environment(app)), size: CGSize(width: 1080, height: 700), dark: false, name: "history", folder: folder)
        await snapshot(AnyView(HistorySidebar().environment(app)), size: CGSize(width: 360, height: 700), dark: false, name: "history-sidebar", folder: folder)
        await snapshot(AnyView(BenchmarkSidebar(model: app.benchmark).environment(app)), size: CGSize(width: 340, height: 700), dark: false, name: "benchmark-sidebar", folder: folder)
        for step in OnboardingStep.allCases {
            await snapshot(AnyView(OnboardingView(initialStep: step).environment(app)), size: CGSize(width: 660, height: 560), dark: false, name: "onboarding-\(step.rawValue)", folder: folder)
        }
        await snapshot(AnyView(BenchmarkView(model: app.benchmark).environment(app)), size: CGSize(width: 1120, height: 760), dark: false, name: "benchmark", folder: folder)
    }

    private static func snapshot(_ view: AnyView, size: CGSize?, dark: Bool, name: String, folder: URL) async {
        let hosting = NSHostingView(rootView: view)
        let frameSize = size ?? hosting.fittingSize
        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: 40, y: 40), size: frameSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = hosting
        window.alphaValue = 0.01
        window.orderFrontRegardless()
        try? await Task.sleep(for: .milliseconds(700))
        hosting.layoutSubtreeIfNeeded()
        if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: folder.appending(path: "\(name).png"))
        }
        window.orderOut(nil)
    }

    private static func samplePhases(app: AppController) -> [(String, FlowPhase)] {
        let glossary = app.glossary.glossary
        let raw = "วันนี้จะต้องกลับบ้านไปทำไซต์โปรเจกต์แล้ว push ขึ้น กิตฮับ ตอน ten PM"
        let final = TextPolicy().finalize(raw, glossary: glossary)
        let transcript = Transcript(rawText: raw, confidence: 0.38, providerID: TranscriberID.appleOnDevice.rawValue)
        let suggestion = Suggestion(alias: "ไซด์โปรเจ็กต์", preferredOutput: "side-project", kind: .addAlias(entryID: UUID()))
        let offer = LearningOffer(suggestion: suggestion, occurrences: 2, correctionID: UUID())
        let clean = TextPolicy().finalize("วันนี้จะต้องกลับบ้านไปทำ side project", glossary: glossary)
        return [
            ("1-listening", .listening(.init(startedAt: .now, handsFree: false, appName: "Notes"))),
            ("2-handsfree", .listening(.init(startedAt: .now, handsFree: true, appName: "Slack"))),
            ("3-transcribing", .transcribing(appName: "Notes")),
            ("4-review", .review(.init(
                dictationID: UUID(),
                transcript: transcript,
                finalText: final,
                decisions: PolicyDecisions(),
                editedText: nil,
                reasons: [.lowConfidence, .suggestions],
                appName: "Notes"
            ))),
            ("5-inserted", .finished(.init(dictationID: UUID(), text: clean.text, result: .inserted(.accessibility), changes: clean.visibleChanges, appName: "Notes", offers: []))),
            ("6-copied", .finished(.init(dictationID: UUID(), text: clean.text, result: .copiedToClipboard(.appRejected), changes: [], appName: "Figma", offers: []))),
            ("7-offer", .finished(.init(dictationID: UUID(), text: "ทำ side-project ต่อ", result: .inserted(.paste), changes: [], appName: "Notes", offers: [offer]))),
            ("8-nospeech", .notice(.init(kind: .noSpeech))),
            ("9-secure", .notice(.init(kind: .secureField))),
            ("10-apikey", .notice(.init(kind: .transcription(.missingAPIKey))))
        ]
    }
}
#endif
