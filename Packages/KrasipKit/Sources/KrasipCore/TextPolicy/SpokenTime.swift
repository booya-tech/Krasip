// SpokenTime.swift
// KrasipKit
// Turns spoken English clock times into digits: "ten AM" → "10 AM", "ten thirty PM" → "10:30 PM".

import Foundation

/// A spoken time found in the text, and the digits that take its place. Both the English and
/// the Thai converter return these, so the policy can run either one the same way.
struct TimeMatch {
    let range: Range<String.Index>
    let replacement: String
}

/// Only clock times with an explicit marker (AM, PM, o'clock) are converted. Other number
/// words ("two cats") and Thai number words are left exactly as spoken.
enum SpokenTime {
    static func matches(in text: String) -> [TimeMatch] {
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        return pattern.matches(in: text, range: whole).compactMap { match in
            guard let range = Range(match.range, in: text),
                  let hourText = group(1, of: match, in: text),
                  let hour = hours[hourText.lowercased()],
                  let separator = group(3, of: match, in: text),
                  let marker = group(4, of: match, in: text) else { return nil }

            var clock = String(hour)
            if let minuteText = group(2, of: match, in: text) {
                guard let minute = minutes(minuteText) else { return nil }
                clock += ":" + (minute < 10 ? "0\(minute)" : "\(minute)")
            }
            return TimeMatch(range: range, replacement: clock + separator + marker)
        }
    }

    private static func group(_ index: Int, of match: NSTextCheckingResult, in text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private static func minutes(_ spoken: String) -> Int? {
        let words = spoken.lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "-" })
            .map(String.init)
        switch words.count {
        case 1:
            return teens[words[0]] ?? tens[words[0]]
        case 2 where words[0] == "oh" || words[0] == "o":
            return units[words[1]]
        case 2:
            guard let ten = tens[words[0]], let unit = units[words[1]] else { return nil }
            return ten + unit
        default:
            return nil
        }
    }

    private static let units: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9
    ]
    private static let teens: [String: Int] = [
        "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19
    ]
    private static let tens: [String: Int] = ["twenty": 20, "thirty": 30, "forty": 40, "fifty": 50]
    private static let hours: [String: Int] = units.merging(["ten": 10, "eleven": 11, "twelve": 12]) { $1 }

    private static let pattern: NSRegularExpression = {
        let unit = "one|two|three|four|five|six|seven|eight|nine"
        let hour = "one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve"
        let teen = "ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen"
        let minute = "(?:oh|o)[ \\-](?:\(unit))|(?:twenty|thirty|forty|fifty)(?:[ \\-](?:\(unit)))?|\(teen)"
        let marker = "a\\.? ?m\\.?|p\\.? ?m\\.?|o'clock|o’clock"
        let source = "(?i)(?<![A-Za-z])(\(hour))(?:[ \\-](\(minute)))?( ?)(\(marker))(?![A-Za-z])"
        do {
            return try NSRegularExpression(pattern: source)
        } catch {
            preconditionFailure("Invalid spoken-time pattern: \(error)")
        }
    }()
}
