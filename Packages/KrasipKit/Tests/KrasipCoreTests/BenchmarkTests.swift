// BenchmarkTests.swift
// KrasipCoreTests
// The bundled benchmark set loads, is balanced, and its metrics score correctly.

import Foundation
import Testing
@testable import KrasipCore

struct BenchmarkTests {
    @Test func bundledSetHasUniqueItemsInEveryCategory() throws {
        let set = try BenchmarkSet.bundled()
        #expect(set.items.count == 56)
        #expect(Set(set.items.map(\.id)).count == set.items.count)
        for category in BenchmarkCategory.allCases {
            #expect(set.items.contains { $0.category == category })
        }
    }

    @Test func perfectTranscriptsOfTheScriptProduceTheExpectedText() throws {
        // If the recognizer heard the script perfectly, the text policy must produce the
        // expected output exactly. Thai time conversion is on, matching the app's own default.
        let set = try BenchmarkSet.bundled()
        let glossary = Glossary(set.glossary)
        let style = TextStyle(convertThaiTimes: true)
        for item in set.items {
            let result = TextPolicy().finalize(item.script, glossary: glossary, style: style)
            #expect(result.text == item.expected, "\(item.id): \(result.text)")
        }
    }

    @Test func expectedTextsAreStableUnderThePolicy() throws {
        let set = try BenchmarkSet.bundled()
        let glossary = Glossary(set.glossary)
        for item in set.items {
            #expect(TextPolicy().finalize(item.expected, glossary: glossary).text == item.expected, "\(item.id)")
        }
    }

    @Test func keyTermsAppearInExpectedText() throws {
        for item in try BenchmarkSet.bundled().items {
            for term in item.keyTerms {
                #expect(BenchmarkScore.containsTerm(term, in: item.expected), "\(item.id): \(term)")
            }
        }
    }

    @Test func scoresPerfectOutput() {
        let item = BenchmarkItem(id: "X", category: .workTerms, script: "", expected: "เดี๋ยว push code ขึ้น GitHub", keyTerms: ["push", "code", "GitHub"])
        let score = BenchmarkScore.score(item: item, providerID: "test", rawText: item.expected, finalText: item.expected)
        #expect(score.preservedTerms.count == 3)
        #expect(score.transliteratedTerms.isEmpty)
        #expect(score.characterErrorRate == 0)
        #expect(score.exactMatch)
    }

    @Test func detectsUnwantedTransliteration() {
        let item = BenchmarkItem(id: "X", category: .workTerms, script: "", expected: "เดี๋ยว push code ขึ้น GitHub", keyTerms: ["push", "code", "GitHub"])
        let score = BenchmarkScore.score(item: item, providerID: "test", rawText: "", finalText: "เดี๋ยว push code ขึ้น กิตฮับ")
        #expect(score.missingTerms == ["GitHub"])
        #expect(score.transliteratedTerms == ["GitHub"])
        #expect(score.characterErrorRate > 0)
    }

    @Test func termMatchNeedsWholeWord() {
        #expect(BenchmarkScore.containsTerm("code", in: "push code now"))
        #expect(!BenchmarkScore.containsTerm("code", in: "encode it"))
        #expect(BenchmarkScore.containsTerm("พี่แบงก์", in: "นัดกับพี่แบงก์ตอน 10 AM"))
    }

    @Test func summaryAggregatesRates() {
        let item = BenchmarkItem(id: "X", category: .workTerms, script: "", expected: "ขึ้น GitHub", keyTerms: ["GitHub"])
        let good = BenchmarkScore.score(item: item, providerID: "p", rawText: "", finalText: "ขึ้น GitHub", latency: 1)
        let bad = BenchmarkScore.score(item: item, providerID: "p", rawText: "", finalText: "ขึ้น กิตฮับ", latency: 3)
        let summary = BenchmarkSummary(providerID: "p", scores: [good, bad])
        #expect(summary.termPreservationRate == 0.5)
        #expect(summary.unwantedTransliterationRate == 0.5)
        #expect(summary.exactMatchRate == 0.5)
    }
}
