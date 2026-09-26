// AppStylesModel.swift
// Krasip
// Observable per-app rules: punctuation override and whether to insert automatically in that app.

import Foundation
import Observation
import KrasipCore
import KrasipStorage

@MainActor
@Observable
final class AppStylesModel {
    private(set) var styles: [AppStyle] = []

    @ObservationIgnored private let repository: AppStyleRepository

    init(repository: AppStyleRepository) {
        self.repository = repository
        reload()
    }

    func reload() {
        styles = (try? repository.all()) ?? []
    }

    func style(for bundleID: String?) -> AppStyle? {
        guard let bundleID else { return nil }
        return styles.first { $0.bundleID == bundleID }
    }

    func save(_ style: AppStyle) {
        try? repository.upsert(style)
        reload()
    }

    func delete(_ bundleID: String) {
        try? repository.delete(bundleID: bundleID)
        reload()
    }
}
