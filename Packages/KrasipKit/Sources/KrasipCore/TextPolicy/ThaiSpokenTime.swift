// ThaiSpokenTime.swift
// KrasipKit
// Turns Thai clock times with a marker word into digits: "สิบโมงเช้า" → "10:00".

import Foundation

enum ThaiSpokenTime {
    struct Match {
        let range: Range<String.Index>
        let replacement: String
    }

    /// One way of saying a time. `regex` captures the number in group 1 and an optional
    /// "ครึ่ง" in group 2; `hour` turns the spoken number into a 24-hour hour, or nil if out of range.
    private struct Form: Sendable {
        let regex: NSRegularExpression
        let hour: @Sendable (Int) -> Int?
    }

    static func matches(in text: String) -> [Match] {
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        var found: [Match] = []
        for form in forms {
            for match in form.regex.matches(in: text, range: whole) {
                guard let range = Range(match.range, in: text),
                      !found.contains(where: { $0.range.overlaps(range) }),
                      let numberText = group(1, of: match, in: text),
                      let number = number(numberText),
                      let hour = form.hour(number) else { continue }
                let minute = group(2, of: match, in: text) == nil ? 0 : 30
                found.append(Match(range: range, replacement: String(format: "%02d:%02d", hour, minute)))
            }
        }
        return found.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    // Longest words first, so "สิบเอ็ด" is tried before "สิบ".
    private static let numberPattern = "สิบเอ็ด|สิบสอง|สิบ|หนึ่ง|สอง|สาม|สี่|ห้า|หก|เจ็ด|แปด|เก้า|1[0-2]|[1-9]"

    private static let numbers: [String: Int] = [
        "หนึ่ง": 1, "สอง": 2, "สาม": 3, "สี่": 4, "ห้า": 5, "หก": 6,
        "เจ็ด": 7, "แปด": 8, "เก้า": 9, "สิบ": 10, "สิบเอ็ด": 11, "สิบสอง": 12
    ]

    private static func number(_ text: String) -> Int? {
        numbers[text] ?? Int(text)
    }

    private static let forms: [Form] = [
        // หนึ่งทุ่ม … ห้าทุ่ม, 1 ทุ่ม … 5 ทุ่ม → 19:00 … 23:00
        form(#"(?<![0-9])(\#(numberPattern)) ?ทุ่ม(ครึ่ง)?"#) { (1...5).contains($0) ? $0 + 18 : nil },
        // ตีหนึ่ง … ตีห้า, ตี 1 … ตี 5 → 01:00 … 05:00
        form(#"ตี ?(\#(numberPattern))(?![0-9])(ครึ่ง)?"#) { (1...5).contains($0) ? $0 : nil },
        // บ่ายหนึ่ง … บ่ายห้า, บ่าย 2, บ่ายสองโมง → 13:00 … 17:00
        form(#"บ่าย ?(\#(numberPattern))(?![0-9])(?: ?โมง)?(ครึ่ง)?"#) { (1...5).contains($0) ? $0 + 12 : nil }
    ]

    private static func form(_ pattern: String, hour: @escaping @Sendable (Int) -> Int?) -> Form {
        do {
            return Form(regex: try NSRegularExpression(pattern: pattern), hour: hour)
        } catch {
            preconditionFailure("Invalid Thai time pattern \(pattern): \(error)")
        }
    }

    private static func group(_ index: Int, of match: NSTextCheckingResult, in text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }
}
