// Insertion.swift
// KrasipKit
// The insertion module seam: where final text should go and what happened when Krasip tried.

import Foundation

/// The app and field that had focus when dictation started.
public struct InsertionTarget: Codable, Equatable, Hashable, Sendable {
    public var bundleID: String?
    public var appName: String?
    public var processID: Int32?
    /// A password or other secure field has focus. Krasip never records or types there.
    public var isSecureField: Bool

    public init(bundleID: String? = nil, appName: String? = nil, processID: Int32? = nil, isSecureField: Bool = false) {
        self.bundleID = bundleID
        self.appName = appName
        self.processID = processID
        self.isSecureField = isSecureField
    }

    public static let unknown = InsertionTarget()
}

public enum InsertionMethod: String, Codable, Sendable {
    /// Set directly into the focused field through the Accessibility API.
    case accessibility
    /// Pasted with a synthetic Command-V; the user's clipboard is restored afterwards.
    case paste
    /// Pasted into an app that does not report its focused field, so success can't be
    /// confirmed. The text is also left on the clipboard.
    case pasteUnconfirmed
}

public enum InsertionFailure: String, Codable, Sendable {
    case accessibilityNotTrusted
    case noFocusedField
    case appRejected
    case secureField
    /// The user pressed Copy instead of Insert.
    case userChoseCopy
}

public enum InsertionResult: Equatable, Sendable {
    case inserted(InsertionMethod)
    /// Not inserted; the final text was put on the clipboard instead.
    case copiedToClipboard(InsertionFailure)
    /// The user dismissed the text before inserting it (it is still in history).
    case cancelled

    public var succeeded: Bool {
        if case .inserted = self { return true }
        return false
    }

    /// Compact form stored in history.
    public var storageValue: String {
        switch self {
        case .inserted(let method): "inserted.\(method.rawValue)"
        case .copiedToClipboard(let failure): "copied.\(failure.rawValue)"
        case .cancelled: "cancelled"
        }
    }

    public init?(storageValue: String) {
        let parts = storageValue.split(separator: ".", maxSplits: 1).map(String.init)
        switch (parts.first, parts.count > 1 ? parts[1] : nil) {
        case ("inserted", let method?):
            guard let method = InsertionMethod(rawValue: method) else { return nil }
            self = .inserted(method)
        case ("copied", let failure?):
            guard let failure = InsertionFailure(rawValue: failure) else { return nil }
            self = .copiedToClipboard(failure)
        case ("cancelled", nil):
            self = .cancelled
        default:
            return nil
        }
    }
}
