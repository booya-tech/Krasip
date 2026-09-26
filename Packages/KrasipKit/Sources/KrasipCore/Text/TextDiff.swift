// TextDiff.swift
// KrasipKit
// Character diff between two versions of a text, grown to whole-word changes.

import Foundation

/// One changed region: `before` offsets in the old text, `after` offsets in the new text.
public struct TextDiffHunk: Equatable, Sendable {
    public var before: Range<Int>
    public var after: Range<Int>
}

public enum TextDiff {
    /// Changed regions between `old` and `new`, expanded so each hunk starts and ends on
    /// word boundaries in both texts. Offsets count Swift `Character`s.
    public static func wordHunks(from old: String, to new: String) -> [TextDiffHunk] {
        let a = Array(old)
        let b = Array(new)
        let raw = characterHunks(a, b)
        guard !raw.isEmpty else { return [] }
        return expandToWords(raw, a: a, b: b)
    }

    /// Minimal character-level hunks computed from a longest common subsequence.
    static func characterHunks(_ a: [Character], _ b: [Character]) -> [TextDiffHunk] {
        var prefix = 0
        while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < a.count - prefix, suffix < b.count - prefix,
              a[a.count - 1 - suffix] == b[b.count - 1 - suffix] {
            suffix += 1
        }

        let aMid = Array(a[prefix..<(a.count - suffix)])
        let bMid = Array(b[prefix..<(b.count - suffix)])
        if aMid.isEmpty && bMid.isEmpty { return [] }
        if aMid.isEmpty || bMid.isEmpty || aMid.count * bMid.count > 4_000_000 {
            return [TextDiffHunk(before: prefix..<(a.count - suffix), after: prefix..<(b.count - suffix))]
        }

        let n = aMid.count
        let m = bMid.count
        var table = [Int32](repeating: 0, count: (n + 1) * (m + 1))
        let width = m + 1
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                if aMid[i] == bMid[j] {
                    table[i * width + j] = table[(i + 1) * width + (j + 1)] + 1
                } else {
                    table[i * width + j] = max(table[(i + 1) * width + j], table[i * width + (j + 1)])
                }
            }
        }

        var hunks: [TextDiffHunk] = []
        var i = 0
        var j = 0
        var open: (Int, Int)?
        func close() {
            if let (si, sj) = open {
                hunks.append(TextDiffHunk(before: (prefix + si)..<(prefix + i), after: (prefix + sj)..<(prefix + j)))
                open = nil
            }
        }
        while i < n || j < m {
            if i < n, j < m, aMid[i] == bMid[j] {
                close()
                i += 1
                j += 1
            } else {
                if open == nil { open = (i, j) }
                if j < m, i == n || table[i * width + (j + 1)] >= table[(i + 1) * width + j] {
                    j += 1
                } else {
                    i += 1
                }
            }
        }
        close()
        return hunks
    }

    private static func expandToWords(_ hunks: [TextDiffHunk], a: [Character], b: [Character]) -> [TextDiffHunk] {
        let aBounds = WordSegmenter.boundaryOffsets(in: a)
        let bBounds = WordSegmenter.boundaryOffsets(in: b)
        func onBoundary(_ offsetA: Int, _ offsetB: Int) -> Bool {
            aBounds.contains(offsetA) && bBounds.contains(offsetB)
        }

        var result: [TextDiffHunk] = []
        for (index, hunk) in hunks.enumerated() {
            var lowerA = hunk.before.lowerBound
            var lowerB = hunk.after.lowerBound
            var upperA = hunk.before.upperBound
            var upperB = hunk.after.upperBound

            if let last = result.last, last.before.upperBound >= lowerA || last.after.upperBound >= lowerB {
                lowerA = last.before.lowerBound
                lowerB = last.after.lowerBound
                result.removeLast()
            }

            // Text between hunks is identical in both versions, so both offsets move together.
            let leftA = result.last?.before.upperBound ?? 0
            let leftB = result.last?.after.upperBound ?? 0
            while !onBoundary(lowerA, lowerB), lowerA > leftA, lowerB > leftB {
                lowerA -= 1
                lowerB -= 1
            }
            if let last = result.last, !onBoundary(lowerA, lowerB) {
                lowerA = last.before.lowerBound
                lowerB = last.after.lowerBound
                result.removeLast()
            }

            let rightA = index + 1 < hunks.count ? hunks[index + 1].before.lowerBound : a.count
            let rightB = index + 1 < hunks.count ? hunks[index + 1].after.lowerBound : b.count
            while !onBoundary(upperA, upperB), upperA < rightA, upperB < rightB {
                upperA += 1
                upperB += 1
            }

            result.append(TextDiffHunk(before: lowerA..<upperA, after: lowerB..<upperB))
        }
        return result
    }
}
