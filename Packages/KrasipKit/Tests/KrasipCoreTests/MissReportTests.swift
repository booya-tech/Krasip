// MissReportTests.swift
// KrasipKit
// Checks the report a user files: which repo it goes to, what the pasted block says, and when sending is allowed.

import Foundation
import Testing
@testable import KrasipCore

private let bangkok = TimeZone(identifier: "Asia/Bangkok")!

private func sample(
    kind: MissKind = .misheard,
    wanted: String = "ใส่ github_token ใน env ด้วย",
    note: String = ""
) -> MissReport {
    MissReport(
        kind: kind,
        wantedText: wanted,
        note: note,
        heardText: "ใส่ github.com.th ใน env ด้วย",
        policyText: "ใส่ github.com.th ใน env ด้วย",
        typedText: "ใส่ github.com.th ใน env ด้วย",
        appName: "Cursor",
        confidence: 0.71,
        latency: 1.04,
        audioDuration: 3.2,
        engine: "openai-compatible",
        appVersion: "1.0.0",
        startedAt: Date(timeIntervalSince1970: 1_793_000_000),
        timeZone: bangkok
    )
}

@Suite struct MissReportDestinationTests {
    @Test func modelMissesGoToTheCorrectionRepo() {
        for kind in [MissKind.misheard, .overCorrected, .discardedFix, .notSure] {
            #expect(sample(kind: kind).destination == MissReport.modelRepo)
        }
    }

    @Test func somethingElseGoesToTheAppRepo() {
        #expect(sample(kind: .somethingElse, note: "the text landed in the wrong window").destination == MissReport.appRepo)
    }

    @Test func theTwoFormsAreDifferentAndNeitherIsThePublicRepo() {
        #expect(MissReport.modelRepo.template == "miss.yml")
        #expect(MissReport.appRepo.template == "bug.yml")
        #expect(MissReport.modelRepo.template != MissReport.appRepo.template)
        // Every report carries the reporter's own speech, and booya-tech/Krasip is public.
        for destination in [MissReport.modelRepo, MissReport.appRepo] {
            #expect(destination.repo == "krasip-correction")
        }
    }
}

@Suite struct MissReportSendingTests {
    @Test func aModelMissNeedsTheWantedText() {
        #expect(sample(wanted: "").canSend == false)
        #expect(sample(wanted: "   \n ").canSend == false)
        #expect(sample(wanted: "ใส่ github_token").canSend)
    }

    @Test func somethingElseNeedsTheNoteAndIgnoresTheWantedText() {
        #expect(sample(kind: .somethingElse, wanted: "anything", note: "").canSend == false)
        #expect(sample(kind: .somethingElse, wanted: "", note: "the hotkey did not fire").canSend)
    }
}

@Suite struct MissReportBodyTests {
    @Test func theBlockCarriesWhatTheBucketsNeed() {
        let body = sample().body
        #expect(body.contains("heard     ใส่ github.com.th ใน env ด้วย"))
        #expect(body.contains("policy    ใส่ github.com.th ใน env ด้วย"))
        #expect(body.contains("typed     ใส่ github.com.th ใน env ด้วย"))
        #expect(body.contains("wanted    ใส่ github_token ใน env ด้วย"))
        #expect(body.contains("app       Cursor"))
        #expect(body.contains("engine    openai-compatible"))
        #expect(body.contains("krasip    1.0.0"))
    }

    @Test func theBlockIsFencedBecauseTheIssueFormCannotRenderIt() {
        let body = sample().body
        #expect(body.hasPrefix("```\n"))
        #expect(body.hasSuffix("\n```"))
    }

    @Test func numbersAreRoundedForReading() {
        #expect(sample().body.contains("confidence 71%   latency 1.04s   audio 3.2s"))
    }

    @Test func theTimeIsStampedInTheUsersOwnZone() {
        #expect(sample().body.contains("at        2026-10-26 14:33:20 +0700"))
    }

    @Test func fieldsNobodyMeasuredAreLeftOutRatherThanPrintedEmpty() {
        var report = sample(wanted: "")
        report.appName = nil
        report.confidence = nil
        report.latency = nil
        report.audioDuration = 0
        report.engine = ""
        let body = report.body
        #expect(body.contains("app") == false)
        #expect(body.contains("wanted") == false)
        #expect(body.contains("engine") == false)
        #expect(body.contains("numbers   none recorded"))
    }
}

@Suite struct MissReportURLTests {
    @Test func aModelMissOpensTheCorrectionFormWithTheDropdownChosen() throws {
        let url = try #require(sample(kind: .overCorrected).issueURL)
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        #expect(url.host == "github.com")
        #expect(url.path == "/booya-tech/krasip-correction/issues/new")
        #expect(byName["template"] == "miss.yml")
        #expect(byName["kind"] == "It changed something that was already right")
        #expect(byName["wanted"] == "ใส่ github_token ใน env ด้วย")
        #expect(byName["history"]?.contains("heard") == true)
    }

    @Test func somethingElseOpensTheAppBugFormInstead() throws {
        let report = sample(kind: .somethingElse, note: "the text landed in the wrong window")
        let url = try #require(report.issueURL)
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        #expect(url.path == "/booya-tech/krasip-correction/issues/new")
        #expect(byName["template"] == "bug.yml")
        #expect(byName["what"] == "the text landed in the wrong window")
        #expect(byName["kind"] == nil)
    }

    @Test func theFormIsNeverHandedAnEmptyFieldItWouldShowAsBlank() throws {
        let url = try #require(sample().issueURL)
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.contains { $0.name == "said" } == false)
    }

    @Test func thaiSurvivesTheRoundTripThroughTheURL() throws {
        let url = try #require(sample().issueURL)
        #expect(url.absoluteString.contains("%E0%B9%83"))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let wanted = items.first { $0.name == "wanted" }?.value
        #expect(wanted == "ใส่ github_token ใน env ด้วย")
    }

    @Test func aHugeDictationIsClippedSoTheBrowserStillOpensIt() throws {
        var report = sample()
        report.typedText = String(repeating: "ก", count: 5000)
        let url = try #require(report.issueURL)
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let typed = try #require(items.first { $0.name == "typed" }?.value)
        #expect(typed.count == MissReport.fieldLimit + 1)
        #expect(typed.hasSuffix("…"))
    }

    @Test func theTitleStaysShortEnoughToRead() {
        var report = sample()
        report.typedText = String(repeating: "ก", count: 500)
        #expect(report.title.count <= 80)
        #expect(report.title.hasSuffix("…"))
    }
}

@Suite struct MissReportFromRecordTests {
    @Test func aRecordFillsInEverythingTheUserShouldNotHaveToType() {
        let record = DictationRecord(
            rawText: "ใส่ github.com.th",
            finalText: "ใส่ github.com.th แล้ว",
            policyText: "ใส่ github.com.th",
            destinationAppName: "Notes",
            confidence: 0.5,
            providerID: "appleOnDevice",
            audioDuration: 2,
            latency: 0.9
        )
        let report = MissReport(record: record, appVersion: "1.0.0")

        #expect(report.heardText == "ใส่ github.com.th")
        #expect(report.policyText == "ใส่ github.com.th")
        #expect(report.typedText == "ใส่ github.com.th แล้ว")
        #expect(report.appName == "Notes")
        #expect(report.engine == "appleOnDevice")
        #expect(report.kind == .notSure)
        #expect(report.canSend == false)
    }
}
