// HistoryModel.swift
// Krasip
// Observable dictation history for the UI: list, search, corrections, learning offers, and quality stats.

import Foundation
import Observation
import KrasipCore
import KrasipStorage

@MainActor
@Observable
final class HistoryModel {
    private(set) var records: [DictationRecord] = []
    private(set) var stats = QualityStats()
    private(set) var offers: [LearningOffer] = []
    private(set) var lastError: String?
    var selection: UUID?
    var searchText = "" {
        didSet { reload() }
    }

    @ObservationIgnored private let store: HistoryStore
    @ObservationIgnored private let audioArchive: AudioArchive
    @ObservationIgnored private let glossary: () -> Glossary

    init(store: HistoryStore, audioArchive: AudioArchive, glossary: @escaping () -> Glossary) {
        self.store = store
        self.audioArchive = audioArchive
        self.glossary = glossary
        reload()
    }

    var selectedRecord: DictationRecord? {
        selection.flatMap { id in records.first { $0.id == id } }
    }

    var latest: DictationRecord? { records.first }

    func reload() {
        do {
            records = try store.recent(limit: 500, matching: searchText)
            stats = try store.stats()
            offers = try store.pendingOffers(glossary: glossary())
            lastError = nil
        } catch {
            lastError = AppString.History.loadFailed(error.localizedDescription)
        }
    }

    func add(_ record: DictationRecord) {
        do {
            try store.record(record)
            reload()
        } catch {
            lastError = AppString.History.saveFailed(error.localizedDescription)
        }
    }

    /// Saves an edit to a dictation. Returns what the correction taught, if anything.
    @discardableResult
    func applyCorrection(id: UUID, text: String) -> CorrectionOutcome? {
        do {
            let outcome = try store.applyCorrection(id: id, finalText: text, glossary: glossary())
            reload()
            return outcome
        } catch {
            lastError = AppString.History.saveFailed(error.localizedDescription)
            return nil
        }
    }

    func corrections(for id: UUID) -> [Correction] {
        (try? store.corrections(for: id)) ?? []
    }

    func markAccepted(_ offer: LearningOffer) {
        try? store.markSuggestionAccepted(correctionID: offer.correctionID)
        reload()
    }

    func markAccepted(correctionID: UUID) {
        try? store.markSuggestionAccepted(correctionID: correctionID)
        reload()
    }

    func dismiss(_ offer: LearningOffer) {
        try? store.dismissOffer(key: offer.suggestion.key)
        reload()
    }

    func updateAudioPath(id: UUID, path: String?) {
        try? store.updateAudioPath(id: id, path: path)
        reload()
    }

    func delete(_ id: UUID) {
        do {
            if let path = try store.delete(id: id) {
                audioArchive.delete(paths: [path])
            }
            if selection == id {
                selection = nil
            }
            reload()
        } catch {
            lastError = AppString.History.saveFailed(error.localizedDescription)
        }
    }

    func deleteAll() {
        do {
            audioArchive.delete(paths: try store.deleteAll())
            audioArchive.deleteAll()
            selection = nil
            reload()
        } catch {
            lastError = AppString.History.saveFailed(error.localizedDescription)
        }
    }

    func deleteAllAudio() {
        do {
            audioArchive.delete(paths: try store.removeAllAudioReferences())
            audioArchive.deleteAll()
            reload()
        } catch {
            lastError = AppString.History.saveFailed(error.localizedDescription)
        }
    }

    func enforceRetention(_ retention: HistoryRetention, now: Date = .now) {
        guard retention != .forever else { return }
        let cutoff = now.addingTimeInterval(-Double(retention.rawValue) * 86_400)
        if let paths = try? store.deleteOlderThan(cutoff) {
            audioArchive.delete(paths: paths)
            reload()
        }
    }

    /// Destination apps seen in history, for the per-app rules picker.
    var recentApps: [(bundleID: String, name: String)] {
        var seen = Set<String>()
        return records.compactMap { record in
            guard let bundleID = record.destinationBundleID, seen.insert(bundleID).inserted else { return nil }
            return (bundleID, record.destinationAppName ?? bundleID)
        }
    }
}
