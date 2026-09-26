// AudioArchive.swift
// Krasip
// Saves recordings only when "Keep audio for retry" is on, and deletes them on request.

import Foundation
import KrasipCore
import KrasipStorage
import KrasipSystem

@MainActor
final class AudioArchive {
    let directory: URL

    init(directory: URL = KrasipStore.audioDirectory) {
        self.directory = directory
    }

    /// Writes the clip as M4A and returns its path, or nil if it could not be saved.
    func save(_ clip: AudioClip, id: UUID) -> String? {
        let url = directory.appending(path: "\(id.uuidString).m4a")
        do {
            try AudioFileCodec.writeM4A(clip, to: url)
            return url.path
        } catch {
            return nil
        }
    }

    func load(path: String) -> AudioClip? {
        try? AudioFileCodec.read(URL(fileURLWithPath: path))
    }

    func exists(path: String?) -> Bool {
        guard let path else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    func delete(paths: [String]) {
        for path in paths {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    func deleteAll() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "m4a" {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Bytes used by kept recordings.
    var totalSize: Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { total, file in
            total + Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }
}
