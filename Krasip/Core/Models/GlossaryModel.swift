// GlossaryModel.swift
// Krasip
// Observable glossary for the UI: add, edit, delete, import, export, and turn suggestions into rules.

import Foundation
import Observation
import KrasipCore
import KrasipStorage

@MainActor
@Observable
final class GlossaryModel {
    private(set) var entries: [GlossaryEntry] = []
    private(set) var lastError: String?

    @ObservationIgnored private let repository: GlossaryRepository

    init(repository: GlossaryRepository) {
        self.repository = repository
        reload()
    }

    var glossary: Glossary { Glossary(entries) }

    func reload() {
        do {
            entries = try repository.all()
            lastError = nil
        } catch {
            lastError = AppString.Glossary.loadFailed(error.localizedDescription)
        }
    }

    @discardableResult
    func save(_ entry: GlossaryEntry) -> Bool {
        var updated = entry
        updated.aliases = GlossaryEntry.cleanAliases(entry.aliases)
        updated.preferredOutput = entry.preferredOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = .now
        guard !updated.preferredOutput.isEmpty else {
            lastError = AppString.Glossary.needsOutput
            return false
        }
        guard !updated.aliases.isEmpty else {
            lastError = AppString.Glossary.needsAlias
            return false
        }
        do {
            try repository.upsert(updated)
            reload()
            return true
        } catch {
            lastError = AppString.Glossary.saveFailed(error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func add(aliases: [String], preferredOutput: String, mode: GlossaryEntry.Mode = .locked) -> Bool {
        if let existing = entries.first(where: { $0.preferredOutput == preferredOutput.trimmingCharacters(in: .whitespacesAndNewlines) }) {
            var merged = existing
            merged.aliases += aliases
            merged.mode = mode
            return save(merged)
        }
        return save(GlossaryEntry(aliases: aliases, preferredOutput: preferredOutput, mode: mode))
    }

    /// Adds a spelling the user confirmed (e.g. a sound-alike) as a new alias of an entry.
    func addAlias(_ alias: String, to entryID: UUID) {
        guard var entry = entries.first(where: { $0.id == entryID }) else { return }
        entry.aliases.append(alias)
        save(entry)
    }

    func delete(_ ids: Set<UUID>) {
        do {
            for id in ids {
                try repository.delete(id: id)
            }
            reload()
        } catch {
            lastError = AppString.Glossary.saveFailed(error.localizedDescription)
        }
    }

    /// Turns a learned suggestion into a locked rule.
    @discardableResult
    func apply(_ suggestion: Suggestion) -> Bool {
        switch suggestion.kind {
        case .newEntry:
            return add(aliases: [suggestion.alias], preferredOutput: suggestion.preferredOutput, mode: .locked)
        case .addAlias(let entryID), .lockEntry(let entryID):
            guard var entry = entries.first(where: { $0.id == entryID }) else {
                return add(aliases: [suggestion.alias], preferredOutput: suggestion.preferredOutput, mode: .locked)
            }
            entry.aliases.append(suggestion.alias)
            entry.mode = .locked
            return save(entry)
        }
    }

    func importEntries(from url: URL) -> String {
        do {
            let entries = try GlossaryJSON.decode(Data(contentsOf: url))
            let summary = try repository.importEntries(entries)
            reload()
            return AppString.Glossary.importSummary(added: summary.added, updated: summary.updated)
        } catch {
            return AppString.Glossary.importFailed(error.localizedDescription)
        }
    }

    func importEntries(_ entries: [GlossaryEntry]) -> String {
        do {
            let summary = try repository.importEntries(entries)
            reload()
            return AppString.Glossary.importSummary(added: summary.added, updated: summary.updated)
        } catch {
            return AppString.Glossary.importFailed(error.localizedDescription)
        }
    }

    func export(to url: URL) throws {
        try GlossaryJSON.encode(entries).write(to: url, options: .atomic)
    }

    func clearError() {
        lastError = nil
    }

    /// Brings in entries saved as glossary.json by an earlier build, either in this app's
    /// Application Support folder or in the one it used before the rename from WispFlow.
    /// Entries are merged by preferred spelling, so nothing is duplicated.
    static func importLegacyGlossary(into store: KrasipStore) {
        let folders = [KrasipStore.supportDirectory, KrasipStore.previousSupportDirectory]
        for folder in folders {
            let legacy = folder.appending(path: "glossary.json")
            guard let data = try? Data(contentsOf: legacy), let entries = try? GlossaryJSON.decode(data), !entries.isEmpty else { continue }
            _ = try? store.glossary.importEntries(entries)
        }
    }

    /// The spec's example entry, added on first launch so the primary case works right away.
    static let sideProjectExample = GlossaryEntry(
        aliases: ["side project", "ไซต์โปรเจกต์", "ไซด์โปรเจกต์"],
        preferredOutput: "side-project",
        mode: .locked
    )

    /// Common English work terms and the Thai spellings recognizers tend to produce for them.
    /// Offered, never added automatically.
    static let starterTerms: [(output: String, aliases: [String])] = [
        ("GitHub", ["กิตฮับ", "กิทฮับ", "กิตฮัพ"]),
        ("pull request", ["พูลรีเควสต์", "พูลรีเควส", "พุลรีเควสต์"]),
        ("commit", ["คอมมิต", "คอมมิท"]),
        ("merge", ["เมิร์จ"]),
        ("deploy", ["ดีพลอย"]),
        ("branch", ["แบรนช์", "แบรนซ์"]),
        ("feature", ["ฟีเจอร์"]),
        ("deadline", ["เดดไลน์"]),
        ("meeting", ["มีตติ้ง", "มีทติ้ง"]),
        ("feedback", ["ฟีดแบ็ก", "ฟีดแบค"]),
        ("database", ["ดาต้าเบส"]),
        ("backend", ["แบ็กเอนด์", "แบคเอนด์"]),
        ("frontend", ["ฟรอนต์เอนด์", "ฟร้อนท์เอนด์"]),
        ("Slack", ["สแล็ก", "สแลค"]),
        ("Figma", ["ฟิกมา"]),
        ("Notion", ["โนชั่น"]),
        ("API", ["เอพีไอ"]),
        ("sprint", ["สปรินต์"]),
        ("refactor", ["รีแฟกเตอร์"]),
        ("release", ["รีลีส"])
    ]

    func starterEntries(mode: GlossaryEntry.Mode) -> [GlossaryEntry] {
        Self.starterTerms.map { GlossaryEntry(aliases: $0.aliases, preferredOutput: $0.output, mode: mode) }
    }
}
