// TextPolicy.swift
// KrasipKit
// The text policy module: turns a raw transcript into final text using only deterministic, explainable rules.

import Foundation

/// `finalize(rawText, glossary, style) -> FinalText`.
///
/// Order of rules:
/// 1. Normalize Unicode and whitespace.
/// 1b. Assemble an email address spoken in parts ("beam at sign gmail dot com" →
///    "beam@gmail.com"), then put back the `@` of one the model wrote as a dotted token
///    ("support.at.grasip.app" → "support@grasip.app", "อีเมล admin.example.com" →
///    "อีเมล admin@example.com"), before step 2 seals every dotted token as code or a URL.
/// 2. Protect URLs, emails, and code so nothing below can touch them.
/// 3. Apply locked glossary aliases (before any formatting); collect `suggest` matches and
///    Thai spellings that only sound like an alias (suggested, never applied without the user).
/// 4. Convert spoken English clock times ("ten AM" → "10 AM") and write Thai spoken times the
///    way docs/THAI_TIME_RULES.md sets ("บ่ายสองครึ่ง" → "14:30", "หกโมงเย็น" → "6 โมงเย็น").
/// 4b. Turn a spoken symbol name into the symbol ("เครื่องหมายตกใจ" → "!", "100 ดอลลาร์" → "$100"),
///    after the times so the two rules never contend for the same colon, and before words are
///    protected because several names are English words.
/// 5. Protect remaining Latin words and numbers.
/// 6. Insert a space where Thai text touches English words or digits.
/// 7. Apply the punctuation mode.
/// 8. Tidy whitespace created by the rules above.
///
/// It never translates, rewrites tone, or invents words, and every edit is returned as a `TextChange`.
public struct TextPolicy: Sendable {
    public init() {}

    public func finalize(
        _ rawText: String,
        glossary: Glossary,
        style: TextStyle = .standard,
        decisions: PolicyDecisions = PolicyDecisions()
    ) -> FinalText {
        var log = ChangeLog()
        var normalized = normalize(rawText, log: &log)
        if !decisions.disabledKinds.contains(.spokenSymbol) {
            normalized = repairTokens(normalized, found: SpokenEmail.matches(in:), log: &log)
            normalized = repairTokens(normalized, found: DottedEmailRepair.matches(in:), log: &log)
            normalized = repairTokens(normalized, found: PortRepair.matches(in:), log: &log)
        }
        var segments = normalized.isEmpty ? [] : [TextSegment(text: normalized, origin: .transcript)]

        segments = protectStructured(segments)
        segments = applyGlossary(segments, glossary: glossary, decisions: decisions, log: &log)
        segments = applySoundAlikes(segments, glossary: glossary, style: style, decisions: decisions, log: &log)

        if !decisions.disabledKinds.contains(.spokenTime) {
            segments = applySpokenTimes(segments, found: SpokenTime.matches(in:), log: &log)
            segments = applySpokenTimes(segments, found: ThaiSpokenTime.matches(in:), log: &log)
        }

        if !decisions.disabledKinds.contains(.spokenSymbol) {
            segments = applySpokenSymbols(segments, log: &log)
        }

        segments = protectWords(segments)

        if !decisions.disabledKinds.contains(.spacing) {
            segments = applyScriptSpacing(segments, log: &log)
        }

        if !decisions.disabledKinds.contains(.punctuation) {
            segments = applyPunctuation(segments, mode: style.punctuation, log: &log)
        }

        segments = tidyWhitespace(segments)

        return FinalText(
            rawText: rawText,
            text: segments.map(\.text).joined(),
            changes: log.changes,
            suggestions: pendingSuggestions(in: segments, glossary: glossary),
            segments: segments
        )
    }

    // MARK: - 1. Normalization

    private func normalize(_ raw: String, log: inout ChangeLog) -> String {
        var text = raw.precomposedStringWithCanonicalMapping
        if !text.unicodeScalars.elementsEqual(raw.unicodeScalars) {
            log.add(.normalization, before: "decomposed Unicode", after: "composed Unicode", key: "unicode")
        }

        let visible = String(String.UnicodeScalarView(text.unicodeScalars.filter { !$0.isZeroWidth }))
        if visible != text {
            log.add(.normalization, before: "invisible characters", after: "removed", key: "invisible")
            text = visible
        }

        var result = ""
        var pendingSpace = false
        var pendingNewlines = 0
        for character in text {
            if character.isNewline {
                pendingNewlines += 1
            } else if character.isWhitespace {
                pendingSpace = true
            } else {
                if !result.isEmpty {
                    if pendingNewlines > 0 {
                        result += String(repeating: "\n", count: min(pendingNewlines, 2))
                    } else if pendingSpace {
                        result += " "
                    }
                }
                pendingSpace = false
                pendingNewlines = 0
                result.append(character)
            }
        }
        if result != text {
            log.add(.normalization, before: "extra or unusual spaces", after: "single spaces", key: "whitespace")
        }
        return result
    }

    // MARK: - 1b. Email addresses spoken in parts or written as a dotted token

    private func repairTokens(_ text: String, found: (String) -> [SymbolMatch], log: inout ChangeLog) -> String {
        var repaired = ""
        var cursor = text.startIndex
        for match in found(text) {
            log.add(.spokenSymbol, before: String(text[match.range]), after: match.replacement, key: "spokenSymbol")
            repaired += text[cursor..<match.range.lowerBound] + match.replacement
            cursor = match.range.upperBound
        }
        return repaired + text[cursor...]
    }

    // MARK: - 2. Structured spans

    private func protectStructured(_ segments: [TextSegment]) -> [TextSegment] {
        protect(segments, spans: ProtectedSpans.structured(in:))
    }

    // MARK: - 3. Glossary

    private func applyGlossary(
        _ segments: [TextSegment],
        glossary: Glossary,
        decisions: PolicyDecisions,
        log: inout ChangeLog
    ) -> [TextSegment] {
        let active = glossary.entries.compactMap { entry -> GlossaryEntry? in
            guard !decisions.revertedEntries.contains(entry.id) else { return nil }
            var entry = entry
            if entry.mode == .suggest, decisions.acceptedSuggestions.contains(entry.id) {
                entry.mode = .locked
            }
            return entry.mode == .disabled ? nil : entry
        }
        let matcher = GlossaryMatcher(entries: active)

        return replaceInOpenTranscript(segments) { segment in
            var pieces: [(Range<String.Index>, TextSegment)] = []
            for match in matcher.matches(in: segment.text) {
                switch match.mode {
                case .locked:
                    if match.matchedText != match.output {
                        log.addGlossary(match)
                    }
                    pieces.append((match.range, lockedOutput(match)))
                case .suggest:
                    let pending = TextSegment(text: match.matchedText, origin: .transcript, suggestionEntryID: match.entryID)
                    pieces.append((match.range, pending))
                case .disabled:
                    continue
                }
            }
            return pieces
        }
    }

    // MARK: - 3b. Sound-alike spellings

    /// Thai spellings that sound like a saved alias become suggestions, or replacements once
    /// the user has accepted them for this text.
    private func applySoundAlikes(
        _ segments: [TextSegment],
        glossary: Glossary,
        style: TextStyle,
        decisions: PolicyDecisions,
        log: inout ChangeLog
    ) -> [TextSegment] {
        guard style.suggestSoundAlikes || !decisions.acceptedSoundAlikes.isEmpty else { return segments }
        let entries = glossary.entries.filter { !decisions.revertedEntries.contains($0.id) }
        let matcher = SoundAlikeMatcher(entries: entries)
        guard !matcher.isEmpty else { return segments }

        return replaceInOpenTranscript(segments) { segment in
            var pieces: [(Range<String.Index>, TextSegment)] = []
            for match in matcher.matches(in: segment.text) {
                if decisions.acceptedSoundAlikes.contains(match.entryID) {
                    log.addGlossary(match)
                    pieces.append((match.range, lockedOutput(match)))
                } else if style.suggestSoundAlikes {
                    let pending = TextSegment(
                        text: match.matchedText,
                        origin: .transcript,
                        suggestionEntryID: match.entryID,
                        suggestionIsSoundAlike: true
                    )
                    pieces.append((match.range, pending))
                }
            }
            return pieces
        }
    }

    // MARK: - 4. Spoken times

    private func applySpokenTimes(
        _ segments: [TextSegment],
        found: (String) -> [TimeMatch],
        log: inout ChangeLog
    ) -> [TextSegment] {
        replaceInOpenTranscript(segments) { segment in
            found(segment.text).map { match in
                log.add(.spokenTime, before: String(segment.text[match.range]), after: match.replacement, key: "spokenTime")
                return (match.range, TextSegment(text: match.replacement, origin: .spokenTime, protection: .spokenTime))
            }
        }
    }

    // MARK: - 4b. Spoken symbols

    private func applySpokenSymbols(_ segments: [TextSegment], log: inout ChangeLog) -> [TextSegment] {
        segments.indices.flatMap { index -> [TextSegment] in
            let segment = segments[index]
            guard isOpenTranscript(segment) else { return [segment] }
            let neighbours = (before: segments[..<index].last?.text.last, after: segments[(index + 1)...].first?.text.first)
            let pieces = SpokenSymbol.matches(in: segment.text, neighbours: neighbours).map { match in
                log.add(.spokenSymbol, before: String(segment.text[match.range]), after: match.replacement, key: "spokenSymbol")
                return (match.range, TextSegment(text: match.replacement, origin: .spokenSymbol, protection: .spokenSymbol))
            }
            return split(segment, pieces)
        }
    }

    // MARK: - 5. Words and numbers

    private func protectWords(_ segments: [TextSegment]) -> [TextSegment] {
        protect(segments, spans: ProtectedSpans.words(in:))
    }

    // MARK: - 6. Thai ↔ Latin spacing

    private func applyScriptSpacing(_ segments: [TextSegment], log: inout ChangeLog) -> [TextSegment] {
        var result: [TextSegment] = []
        for segment in segments {
            if let previous = result.last,
               let left = previous.text.last,
               let right = segment.text.first,
               needsSpace(between: left, and: right) {
                let leftContext = tail(of: result.map(\.text).joined(), matching: left.scriptClass)
                let rightContext = head(of: segment.text)
                log.add(.spacing, before: leftContext + rightContext, after: leftContext + " " + rightContext, key: "spacing")
                result.append(TextSegment(text: " ", origin: .insertedSpace))
            }
            result.append(segment)
        }
        return result
    }

    private func needsSpace(between left: Character, and right: Character) -> Bool {
        (left.scriptClass == .thai && right.isLatinOrDigit) || (left.isLatinOrDigit && right.scriptClass == .thai)
    }

    /// The last word of `text`, for change descriptions ("ทำside-project -> ทำ side-project").
    private func tail(of text: String, matching script: ScriptClass) -> String {
        var characters: [Character] = []
        for character in text.reversed() {
            guard isSameRun(character, as: script), characters.count < 24 else { break }
            characters.insert(character, at: 0)
        }
        let run = String(characters)
        guard script == .thai, let last = WordSegmenter.wordRanges(in: run).last else { return run }
        return String(Array(run)[last])
    }

    /// The word-like run at the start of `text`, for change descriptions.
    private func head(of text: String) -> String {
        guard let first = text.first else { return "" }
        let script = first.scriptClass
        return String(text.prefix { isSameRun($0, as: script) }.prefix(16))
    }

    private func isSameRun(_ character: Character, as script: ScriptClass) -> Bool {
        switch script {
        case .thai: character.scriptClass == .thai
        case .latin, .digit: character.isLatinOrDigit || "-_.'".contains(character)
        default: false
        }
    }

    // MARK: - 7. Punctuation

    private static let sentenceMarks: Set<Character> = [".", ",", "!", "?", ";", ":", "…", "。", "，", "！", "？"]

    private func applyPunctuation(_ segments: [TextSegment], mode: PunctuationMode, log: inout ChangeLog) -> [TextSegment] {
        switch mode {
        case .keep:
            return segments

        case .noTrailingPeriod:
            var result = segments
            guard let index = result.lastIndex(where: { !$0.text.trimmed.isEmpty }),
                  !result[index].isProtected,
                  result[index].origin == .transcript else { return segments }
            let text = result[index].text
            let trimmedEnd = text.trimmingCharacters(in: .whitespaces)
            guard trimmedEnd.hasSuffix("."), !trimmedEnd.hasSuffix("..") else { return segments }
            let beforePeriod = result[..<index].map(\.text).joined() + String(trimmedEnd.dropLast())
            let context = tail(of: beforePeriod, matching: beforePeriod.last?.scriptClass ?? .thai)
            result[index].text = String(trimmedEnd.dropLast())
            log.add(.punctuation, before: context + ".", after: context, key: "trailingPeriod")
            return result

        case .none:
            return segments.map { segment in
                guard isOpenTranscript(segment) || (segment.origin == .transcript && segment.suggestionEntryID != nil) else {
                    return segment
                }
                var kept = ""
                for character in segment.text {
                    if Self.sentenceMarks.contains(character) {
                        log.add(.punctuation, before: String(character), after: "", key: "punctuation")
                    } else {
                        kept.append(character)
                    }
                }
                var updated = segment
                updated.text = kept
                return updated
            }
        }
    }

    // MARK: - 8. Whitespace

    private func tidyWhitespace(_ segments: [TextSegment]) -> [TextSegment] {
        var result: [TextSegment] = []
        var previousWasSpace = true
        for segment in segments {
            if segment.isProtected {
                result.append(segment)
                previousWasSpace = segment.text.last?.isWhitespace ?? previousWasSpace
                continue
            }
            var text = ""
            for character in segment.text {
                if character == " " {
                    if previousWasSpace { continue }
                    previousWasSpace = true
                } else {
                    previousWasSpace = character.isWhitespace
                }
                text.append(character)
            }
            if !text.isEmpty {
                var updated = segment
                updated.text = text
                result.append(updated)
            }
        }
        while let last = result.last, !last.isProtected, last.text.last?.isWhitespace == true {
            var updated = last
            updated.text = String(last.text.dropLast())
            result.removeLast()
            if !updated.text.isEmpty {
                result.append(updated)
            }
        }
        return result
    }

    // MARK: - Suggestions

    private func pendingSuggestions(in segments: [TextSegment], glossary: Glossary) -> [PendingSuggestion] {
        let outputs = Dictionary(glossary.entries.map { ($0.id, $0.preferredOutput) }, uniquingKeysWith: { first, _ in first })
        var suggestions: [PendingSuggestion] = []
        var offset = 0
        var index = 0
        while index < segments.count {
            let segment = segments[index]
            guard let entryID = segment.suggestionEntryID else {
                offset += segment.text.count
                index += 1
                continue
            }
            let start = offset
            var matched = ""
            var cursor = index
            var lastMatchedEnd = offset
            var runningOffset = offset
            while cursor < segments.count {
                let piece = segments[cursor]
                if piece.suggestionEntryID == entryID {
                    matched += piece.text
                    runningOffset += piece.text.count
                    lastMatchedEnd = runningOffset
                } else if piece.origin == .insertedSpace,
                          cursor + 1 < segments.count,
                          segments[cursor + 1].suggestionEntryID == entryID {
                    matched += piece.text
                    runningOffset += piece.text.count
                } else {
                    break
                }
                cursor += 1
            }
            if let output = outputs[entryID] {
                suggestions.append(PendingSuggestion(
                    entryID: entryID,
                    matchedText: matched,
                    preferredOutput: output,
                    range: start..<lastMatchedEnd,
                    isSoundAlike: segment.suggestionIsSoundAlike
                ))
            }
            offset = runningOffset
            index = cursor
        }
        return suggestions
    }

    // MARK: - Helpers

    private func isOpenTranscript(_ segment: TextSegment) -> Bool {
        segment.origin == .transcript && !segment.isProtected && segment.suggestionEntryID == nil
    }

    /// Runs `pieces` on each open transcript segment and splits the new segments into it.
    private func replaceInOpenTranscript(
        _ segments: [TextSegment],
        _ pieces: (TextSegment) -> [(Range<String.Index>, TextSegment)]
    ) -> [TextSegment] {
        segments.flatMap { segment -> [TextSegment] in
            isOpenTranscript(segment) ? split(segment, pieces(segment)) : [segment]
        }
    }

    private func lockedOutput(_ match: Replacement) -> TextSegment {
        TextSegment(text: match.output, origin: .glossary(match.entryID), protection: .glossaryOutput)
    }

    private func protect(_ segments: [TextSegment], spans: (String) -> [ProtectedSpan]) -> [TextSegment] {
        replaceInOpenTranscript(segments) { segment in
            spans(segment.text).map { span in
                (span.range, TextSegment(text: String(segment.text[span.range]), origin: .transcript, protection: span.protection))
            }
        }
    }

    /// Replaces the given ranges of `segment` with new segments, keeping the rest as-is.
    private func split(_ segment: TextSegment, _ pieces: [(Range<String.Index>, TextSegment)]) -> [TextSegment] {
        guard !pieces.isEmpty else { return [segment] }
        var result: [TextSegment] = []
        var cursor = segment.text.startIndex
        for (range, replacement) in pieces.sorted(by: { $0.0.lowerBound < $1.0.lowerBound }) {
            guard range.lowerBound >= cursor else { continue }
            if cursor < range.lowerBound {
                var rest = segment
                rest.text = String(segment.text[cursor..<range.lowerBound])
                result.append(rest)
            }
            result.append(replacement)
            cursor = range.upperBound
        }
        if cursor < segment.text.endIndex {
            var rest = segment
            rest.text = String(segment.text[cursor...])
            result.append(rest)
        }
        return result
    }
}

private struct ChangeLog {
    var changes: [TextChange] = []
    private var counters: [String: Int] = [:]

    mutating func add(_ kind: TextChange.Kind, before: String, after: String, entryID: UUID? = nil, key: String) {
        let occurrence = counters[key, default: 0]
        counters[key] = occurrence + 1
        changes.append(TextChange(id: "\(key)#\(occurrence)", kind: kind, before: before, after: after, entryID: entryID))
    }

    mutating func addGlossary(_ match: Replacement) {
        add(.glossary, before: match.matchedText, after: match.output, entryID: match.entryID, key: "glossary:\(match.entryID.uuidString)")
    }
}
