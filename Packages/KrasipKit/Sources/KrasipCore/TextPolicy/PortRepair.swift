// PortRepair.swift
// KrasipKit
// Takes out the slashes the speech model writes between a host and its port: "localhost://3000" → "localhost:3000".

import Foundation

/// The model hears the colon before a port as the start of a URL scheme and adds "//". A scheme's
/// slashes are followed by a host, never by a bare port number, so those slashes are dropped. It runs
/// before URLs are protected, which would otherwise seal the token as it stands.
enum PortRepair {
    private static let slashedPort: NSRegularExpression = {
        let pattern = #"(?<=[A-Za-z0-9]):/{1,2}(?=\d{1,5}(?![A-Za-z0-9.]))"#
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid slashed-port pattern: \(error)")
        }
    }()

    static func matches(in text: String) -> [SymbolMatch] {
        let whole = NSRange(text.startIndex..<text.endIndex, in: text)
        return slashedPort.matches(in: text, range: whole).compactMap { result in
            Range(result.range, in: text).map { SymbolMatch(range: $0, replacement: ":") }
        }
    }
}
