// ThaiSpokenTime.swift
// KrasipKit
// Turns Thai clock times with a marker word into digits: "สิบโมงเช้า" → "10:00".

import Foundation

enum ThaiSpokenTime {
    /// One way of saying a time. `regex` may capture a spoken number in the `number` group and
    /// "ครึ่ง" in the `half` group; `hour` turns the number (nil for fixed phrases) into a
    /// 24-hour hour, or returns nil when the match is not a time.
    private struct Form: Sendable {
        let regex: NSRegularExpression
        let hour: @Sendable (Int?) -> Int?
    }

    static func matches(in text: String) -> [TimeMatch] {
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        var found: [TimeMatch] = []
        for form in forms {
            for match in form.regex.matches(in: text, range: whole) {
                guard let range = Range(match.range, in: text),
                      !found.contains(where: { $0.range.overlaps(range) }),
                      let hour = form.hour(group("number", of: match, in: text).flatMap(number)) else { continue }
                let minute = group("half", of: match, in: text) == nil ? 0 : 30
                found.append(TimeMatch(range: range, replacement: String(format: "%02d:%02d", hour, minute)))
            }
        }
        return found.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    private static let numbers: [String: Int] = [
        "หนึ่ง": 1, "สอง": 2, "สาม": 3, "สี่": 4, "ห้า": 5, "หก": 6,
        "เจ็ด": 7, "แปด": 8, "เก้า": 9, "สิบ": 10, "สิบเอ็ด": 11, "สิบสอง": 12
    ]

    /// Built from `numbers` so the two can never disagree. Longer words come first, because a
    /// regex alternation stops at the first branch that matches and "สิบ" starts "สิบเอ็ด".
    private static let spokenNumber: String = {
        let words = numbers.keys
            .sorted { left, right in
                let (a, b) = (left.unicodeScalars.count, right.unicodeScalars.count)
                return a == b ? left < right : a > b
            }
            .joined(separator: "|")
        return "(?<number>\(words)|1[0-2]|[1-9])"
    }()

    private static let half = "(?<half>ครึ่ง)?"

    private static func number(_ text: String) -> Int? {
        numbers[text] ?? Int(text)
    }

    // Order matters: the first form to claim a piece of text wins.
    private static let forms: [Form] = [
        // หนึ่งทุ่ม … ห้าทุ่ม, 1 ทุ่ม … 5 ทุ่ม → 19:00 … 23:00
        form(#"(?<![0-9])\#(spokenNumber) ?ทุ่ม\#(half)"#) { (1...5).contains($0) ? $0 + 18 : nil },
        // ตีหนึ่ง … ตีห้า, ตี 1 … ตี 5 → 01:00 … 05:00
        form(#"ตี ?\#(spokenNumber)(?![0-9])\#(half)"#) { (1...5).contains($0) ? $0 : nil },
        // บ่ายหนึ่ง … บ่ายห้า, บ่าย 2, บ่ายสองโมง → 13:00 … 17:00
        form(#"บ่าย ?\#(spokenNumber)(?![0-9])(?: ?โมง)?\#(half)"#) { (1...5).contains($0) ? $0 + 12 : nil },
        // หกโมงเช้า … สิบเอ็ดโมงเช้า → 06:00 … 11:00
        form(#"(?<![0-9])\#(spokenNumber) ?โมงเช้า\#(half)"#) { (6...11).contains($0) ? $0 : nil },
        // สี่โมงเย็น … หกโมงเย็น → 16:00 … 18:00
        form(#"(?<![0-9])\#(spokenNumber) ?โมงเย็น\#(half)"#) { (4...6).contains($0) ? $0 + 12 : nil },
        // เจ็ดโมง … สิบเอ็ดโมง → 07:00 … 11:00, ห้าโมง → 17:00. หกโมง is left alone: it can mean 6 AM or 6 PM.
        form(#"(?<![0-9])\#(spokenNumber) ?โมง(?!เช้า|เย็น)\#(half)"#) { number in
            switch number {
            case 7...11: number
            case 5: 17
            default: nil
            }
        },
        // เที่ยงคืน → 00:00
        phrase(#"เที่ยงคืน\#(half)"#, hour: 0),
        // เที่ยง → 12:00, but not มื้อเที่ยง, ข้าวเที่ยง, ไม่เที่ยง, เที่ยงธรรม, เที่ยงแท้
        phrase(#"(?<!ข้าว|มื้อ|ไม่|ความ)เที่ยง(?!คืน|ธรรม|แท้)\#(half)"#, hour: 12),
        // บ่ายโมง → 13:00
        phrase(#"บ่ายโมง\#(half)"#, hour: 13)
    ]

    private static func form(_ pattern: String, hour: @escaping @Sendable (Int) -> Int?) -> Form {
        Form(regex: regex(pattern), hour: { $0.flatMap(hour) })
    }

    private static func phrase(_ pattern: String, hour: Int) -> Form {
        Form(regex: regex(pattern), hour: { _ in hour })
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid Thai time pattern \(pattern): \(error)")
        }
    }

    private static func group(_ name: String, of match: NSTextCheckingResult, in text: String) -> String? {
        let range = match.range(withName: name)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }
}
