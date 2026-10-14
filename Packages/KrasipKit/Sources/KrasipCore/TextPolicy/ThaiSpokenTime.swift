// ThaiSpokenTime.swift
// KrasipKit
// Writes Thai spoken times the way docs/THAI_TIME_RULES.md sets: "หกโมงเย็น" → "6 โมงเย็น", "บ่ายสองครึ่ง" → "14:30".

import Foundation

enum ThaiSpokenTime {
    /// One way of saying a time. `regex` may capture a spoken number in the `number` group,
    /// spoken minutes in `minute` or `minuteUnit`, and "ครึ่ง" in the `half` group; `hour` turns
    /// the number (nil for fixed phrases) into a 24-hour hour, or returns nil when the hour is
    /// not clear. When `asksWordBefore` is set, a period word just before the match decides the
    /// hour first. A `twentyFourHour` form was said the clock way, so it is always written as a clock.
    private struct Form: Sendable {
        let regex: NSRegularExpression
        let hour: @Sendable (Int?) -> Int?
        var asksWordBefore = false
        var twentyFourHour = false
    }

    /// A clear hour with minutes becomes a 24-hour clock. A whole hour, or an hour that stays
    /// unclear, keeps its spoken words with the numbers as digits. Other matches are not times.
    static func matches(in text: String) -> [TimeMatch] {
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        var found: [TimeMatch] = []
        for form in forms {
            for match in form.regex.matches(in: text, range: whole) {
                guard let range = Range(match.range, in: text),
                      !found.contains(where: { $0.range.overlaps(range) }) else { continue }
                let spoken = group("number", of: match, in: text).flatMap(number)
                var hour = form.hour(spoken)
                if form.asksWordBefore, let spoken, let period = periodWord(before: range.lowerBound, in: text) {
                    hour = period(spoken) ?? hour
                }
                let replacement: String
                if let hour, form.twentyFourHour || hasMinutes(match, in: text) {
                    replacement = String(format: "%02d:%02d", hour, minute(of: match, in: text))
                } else if hour != nil || form.asksWordBefore {
                    replacement = casual(match, range: range, in: text)
                } else {
                    continue
                }
                found.append(TimeMatch(range: range, replacement: replacement))
            }
        }
        return found
            .filter { text[$0.range] != $0.replacement }
            .sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    private static let numbers: [String: Int] = [
        "หนึ่ง": 1, "สอง": 2, "สาม": 3, "สี่": 4, "ห้า": 5, "หก": 6,
        "เจ็ด": 7, "แปด": 8, "เก้า": 9, "สิบ": 10, "สิบเอ็ด": 11, "สิบสอง": 12
    ]

    private static let clockNumbers: [String: Int] = numbers.merging([
        "ศูนย์": 0, "สิบสาม": 13, "สิบสี่": 14, "สิบห้า": 15, "สิบหก": 16, "สิบเจ็ด": 17, "สิบแปด": 18,
        "สิบเก้า": 19, "ยี่สิบ": 20, "ยี่สิบเอ็ด": 21, "ยี่สิบสอง": 22, "ยี่สิบสาม": 23
    ]) { first, _ in first }

    /// Longer words come first, because a regex alternation stops at the first branch that
    /// matches and "สิบ" starts "สิบเอ็ด".
    private static func alternation(_ words: some Sequence<String>) -> String {
        words
            .sorted { left, right in
                let (a, b) = (left.unicodeScalars.count, right.unicodeScalars.count)
                return a == b ? left < right : a > b
            }
            .joined(separator: "|")
    }

    private static let spokenNumber = "(?<number>\(alternation(numbers.keys))|1[0-2]|[1-9])"
    private static let afternoonClockNumber =
        "(?<number>\(alternation(clockNumbers.filter { $0.value >= 13 }.keys))|1[3-9]|2[0-3])"
    private static let clockNumber = "(?<number>\(alternation(clockNumbers.keys))|1[0-9]|2[0-3]|0?[0-9])"

    // Some speech models put a space between Thai words, so every joint inside a time may hold one.
    // After such a space, a word that starts the next phrase is left alone: "เย็นนี้", "ครึ่งวัน".
    private static let half = "(?: ?(?<half>ครึ่ง)(?!วัน|ชั่วโมง|ทาง|ราคา|เดือน|ปี))?"
    private static let morningWord = "(?:เช้า| เช้า(?!นี้|วัน))"
    private static let eveningWord = "(?:เย็น| เย็น(?!นี้|วัน))"

    private static let tens: [String: Int] = ["": 1, "ยี่": 2, "สาม": 3, "สี่": 4, "ห้า": 5]

    /// Spoken minutes after the hour: "สิบห้า", "45", "ห้านาที". Ten and above may stand alone;
    /// one to nine need "นาที", and a number followed by a counting word ("สิบคน") is not minutes.
    /// The atomic group stops "สิบห้าคน" from being read as "สิบ" minutes.
    private static let counted = "คน|บาท|ตัว|อัน|ชิ้น|ครั้ง|วัน|เดือน|ปี|ชั่วโมง|ข้อ|เครื่อง|%|เปอร์เซ็นต์"

    private static let minutes: String = {
        let unit = "หนึ่ง|สอง|สาม|สี่|ห้า|หก|เจ็ด|แปด|เก้า"
        let spoken = "(?:ยี่|สาม|สี่|ห้า)?สิบ(?:เอ็ด|สอง|สาม|สี่|ห้า|หก|เจ็ด|แปด|เก้า)?"
        let tenAndAbove = "(?<minute>(?>\(spoken)|[0-5][0-9](?![0-9])))(?: ?นาที|(?! ?(?:\(counted))))"
        let belowTen = "(?<minuteUnit>\(unit)|[1-9]) ?นาที"
        return "(?: ?(?:\(tenAndAbove)|\(belowTen)))?"
    }()

    private static func number(_ text: String) -> Int? {
        clockNumbers[text] ?? Int(text)
    }

    private static func hasMinutes(_ match: NSTextCheckingResult, in text: String) -> Bool {
        ["half", "minute", "minuteUnit"].contains { group($0, of: match, in: text) != nil }
    }

    private static func minute(of match: NSTextCheckingResult, in text: String) -> Int {
        if group("half", of: match, in: text) != nil { return 30 }
        let spoken = group("minute", of: match, in: text) ?? group("minuteUnit", of: match, in: text)
        return spoken.flatMap(minuteNumber) ?? 0
    }

    private static func minuteNumber(_ text: String) -> Int? {
        if let digits = Int(text) { return digits }
        guard let ten = text.range(of: "สิบ") else { return numbers[text] }
        guard let tensDigit = tens[String(text[..<ten.lowerBound])] else { return nil }
        let unit = String(text[ten.upperBound...])
        return tensDigit * 10 + (unit.isEmpty ? 0 : unit == "เอ็ด" ? 1 : numbers[unit] ?? 0)
    }

    /// The time as it was said, with digits for the spoken numbers and one space where a digit
    /// meets a Thai letter: "หก โมง เย็น" → "6 โมงเย็น", "หกโมงสิบห้า" → "6 โมง 15".
    private static func casual(_ match: NSTextCheckingResult, range: Range<String.Index>, in text: String) -> String {
        let digits: [(Range<String.Index>, Int)] = [("number", number), ("minute", minuteNumber), ("minuteUnit", minuteNumber)]
            .compactMap { name, parse in
                guard let part = Range(match.range(withName: name), in: text), let value = parse(String(text[part])) else { return nil }
                return (part, value)
            }
            .sorted { $0.0.lowerBound < $1.0.lowerBound }
        var said = ""
        var index = range.lowerBound
        for (part, value) in digits {
            said += text[index..<part.lowerBound] + String(value)
            index = part.upperBound
        }
        said += text[index..<range.upperBound]

        var result = ""
        for character in said where !character.isWhitespace {
            if let last = result.last, last.isNumber != character.isNumber {
                result.append(" ")
            }
            result.append(character)
        }
        return result
    }

    // Order matters: the first form to claim a piece of text wins.
    private static let forms: [Form] = [
        // สิบสามโมง … ยี่สิบสามโมง → 13:00 … 23:00, said the 24-hour way.
        form(#"(?<![0-9])\#(afternoonClockNumber) ?โมง\#(minutes)\#(half)"#, twentyFourHour: true) { $0 },
        // แปดนาฬิกา, สิบแปดนาฬิกาสามสิบนาที → 08:00, 18:30
        form(#"(?<![0-9])\#(clockNumber) ?นาฬิกา\#(minutes)\#(half)"#, twentyFourHour: true) { (0...23).contains($0) ? $0 : nil },
        // หนึ่งทุ่ม … ห้าทุ่ม, 1 ทุ่ม … 5 ทุ่ม → 19 … 23, หกทุ่ม → midnight
        form(#"(?<![0-9])\#(spokenNumber) ?ทุ่ม\#(minutes)\#(half)"#) {
            switch $0 {
            case 1...5: $0 + 18
            case 6: 0
            default: nil
            }
        },
        // ทุ่มหนึ่ง, ทุ่มนึง, ทุ่ม 1 → 19, ทุ่มครึ่ง → 19:30. Not after a number ("หกทุ่มครึ่ง"), and not
        // "ทุ่ม" as in spending: "ทุ่มหนึ่งล้านบาท", "ทุ่ม 1,000 บาท", "ทุ่มครึ่งหนึ่ง".
        phrase(
            #"(?<!(?:หนึ่ง|สอง|สาม|สี่|ห้า|หก|เจ็ด|แปด|เก้า|สิบ|เอ็ด|[0-9]) ?)ทุ่ม"#
                + #"(?: ?(?:หนึ่ง|นึง|1(?! ?(?:[0-9,.]|นาที|โมง|ทุ่ม|ครึ่ง|เท่า)))(?! ?(?:ล้าน|แสน|หมื่น|พัน|ร้อย|สิบ|\#(counted)))| ?(?<half>ครึ่ง)(?!หนึ่ง|นึง|วัน|ชั่วโมง|ทาง|ราคา|เดือน|ปี))"#,
            hour: 19
        ),
        // ตีหนึ่ง … ตีห้า, ตี 1 … ตี 5 → 1 … 5. The hour is the first number, so "ตีห้าสิบห้า" is 05:15.
        form(#"ตี ?\#(spokenNumber)(?![0-9])\#(minutes)\#(half)"#) { (1...5).contains($0) ? $0 : nil },
        // บ่ายหนึ่ง … บ่ายห้า, บ่าย 2, บ่ายสองโมง, บ่ายสองโมงสี่สิบ → 13 … 17
        form(#"บ่าย ?\#(spokenNumber)(?![0-9])(?: ?โมง\#(minutes))?\#(half)"#) { (1...5).contains($0) ? $0 + 12 : nil },
        form(#"(?<![0-9])\#(spokenNumber) ?โมง\#(morningWord)\#(minutes)\#(half)"#, hour: morning),
        form(#"(?<![0-9])\#(spokenNumber) ?โมง\#(eveningWord)\#(minutes)\#(half)"#, hour: evening),
        // หกโมงสิบห้าตอนเช้า, หกโมงตอนเช้า: the period word follows the minutes and is part of the time.
        form(#"(?<![0-9])\#(spokenNumber) ?โมง\#(minutes)\#(half) ?ตอน ?เช้า"#, hour: morning),
        form(#"(?<![0-9])\#(spokenNumber) ?โมง\#(minutes)\#(half) ?ตอน ?เย็น"#, hour: evening),
        // เจ็ดโมง … สิบเอ็ดโมง are morning, สี่โมง and ห้าโมง are afternoon. หกโมง can mean 6 AM or 6 PM,
        // so only เช้า or เย็น just before decides it: "ตอนเช้าหกโมงครึ่ง" → 06:30.
        form(#"(?<![0-9])\#(spokenNumber) ?โมง(?!\#(morningWord)|\#(eveningWord))\#(minutes)\#(half)"#, asksWordBefore: true) { number in
            switch number {
            case 7...11: number
            case 4, 5: number + 12
            default: nil
            }
        },
        phrase(#"เที่ยง ?คืน\#(minutes)\#(half)"#, hour: 0),
        // เที่ยง, but not มื้อเที่ยง, ข้าวเที่ยง, ไม่เที่ยง, เที่ยงธรรม, เที่ยงแท้
        phrase(#"(?<!ข้าว|มื้อ|ไม่|ความ)เที่ยง(?! ?คืน|ธรรม|แท้)\#(minutes)\#(half)"#, hour: 12),
        phrase(#"บ่าย ?โมง\#(minutes)\#(half)"#, hour: 13)
    ]

    /// สองโมงเช้า … ห้าโมงเช้า is the old way of counting from six, so สี่โมงเช้า is 10 AM.
    private static let morning: @Sendable (Int) -> Int? = {
        switch $0 {
        case 6...11: $0
        case 2...5: $0 + 6
        default: nil
        }
    }

    private static let evening: @Sendable (Int) -> Int? = { (4...6).contains($0) ? $0 + 12 : nil }

    /// The nearest เช้า or เย็น before `start`, as the rule for reading the hour. Only a few
    /// letters may sit in between ("เย็นนี้เจอกันหกโมง"), with no number and no other time of day,
    /// and เย็น meaning cold does not count ("น้ำเย็น").
    private static func periodWord(before start: String.Index, in text: String) -> (@Sendable (Int) -> Int?)? {
        let prefix = text[..<start]
        let morningAt = prefix.range(of: "เช้า", options: .backwards)
        let eveningAt = prefix.range(of: "เย็น", options: .backwards)
        let isEvening = switch (morningAt, eveningAt) {
        case let (morning?, evening?): evening.lowerBound > morning.lowerBound
        default: eveningAt != nil
        }
        guard let word = isEvening ? eveningAt : morningAt else { return nil }

        var between = String(prefix[word.upperBound...].filter { !$0.isWhitespace })
        if between.hasPrefix("นี้") { between.removeFirst("นี้".count) }
        guard between.unicodeScalars.count <= 10,
              !between.contains(where: \.isNumber),
              !["บ่าย", "คืน", "ทุ่ม", "เที่ยง"].contains(where: between.contains) else { return nil }
        if isEvening {
            let cold = ["น้ำ", "ใจ", "อากาศ", "กาแฟ", "ชา", "แอร์"].contains(where: prefix[..<word.lowerBound].hasSuffix)
            guard !cold, !between.hasPrefix("ชา"), !between.hasPrefix("ตาโฟ") else { return nil }
        }
        return isEvening ? evening : morning
    }

    private static func form(
        _ pattern: String,
        asksWordBefore: Bool = false,
        twentyFourHour: Bool = false,
        hour: @escaping @Sendable (Int) -> Int?
    ) -> Form {
        Form(regex: regex(pattern), hour: { $0.flatMap(hour) }, asksWordBefore: asksWordBefore, twentyFourHour: twentyFourHour)
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
