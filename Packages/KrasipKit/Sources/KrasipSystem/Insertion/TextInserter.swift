// TextInserter.swift
// KrasipKit
// The insertion module on macOS: types final text into the focused field, or falls back to the clipboard.

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import KrasipCore

/// `insert(text) -> InsertionResult`.
///
/// 1. No Accessibility permission → clipboard.
/// 2. Password field → never typed; clipboard.
/// 3. Native text field → set the text through Accessibility and check it landed.
/// 4. Web content, Electron, or a field that ignored step 3 → paste with ⌘V, then restore
///    the user's clipboard.
/// 5. A paste the app visibly rejected → clipboard + "Copied — paste with ⌘V".
@MainActor
public final class TextInserter {
    public enum Mode: String, Codable, CaseIterable, Sendable {
        case automatic
        case pasteOnly
    }

    public var mode: Mode = .automatic

    public init() {}

    public var isTrusted: Bool { AXIsProcessTrusted() }

    /// The frontmost app and whether a secure field has focus, taken when dictation starts.
    public func captureTarget() -> InsertionTarget {
        let app = NSWorkspace.shared.frontmostApplication
        var isSecure = false
        if app?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            isSecure = NSApp.keyWindow?.firstResponder is NSSecureTextField
        } else if AXIsProcessTrusted(), let element = FocusInspector.focusedElement() {
            isSecure = FocusInspector.inspect(element).isSecure
        } else {
            isSecure = IsSecureEventInputEnabled()
        }
        return InsertionTarget(
            bundleID: app?.bundleIdentifier,
            appName: app?.localizedName,
            processID: app?.processIdentifier,
            isSecureField: isSecure
        )
    }

    public func copyToClipboard(_ text: String) {
        NSPasteboard.general.writeForUser(text)
    }

    public func insert(_ text: String, into target: InsertionTarget) async -> InsertionResult {
        // Krasip's own windows (e.g. the setup practice box). Accessibility calls into our own
        // process would block the main thread, so type through the responder chain instead.
        if target.processID == ProcessInfo.processInfo.processIdentifier {
            return insertIntoOwnWindow(text)
        }
        guard AXIsProcessTrusted() else {
            copyToClipboard(text)
            return .copiedToClipboard(.accessibilityNotTrusted)
        }

        await bringToFront(target)

        guard let element = FocusInspector.focusedElement() else {
            if IsSecureEventInputEnabled() {
                copyToClipboard(text)
                return .copiedToClipboard(.secureField)
            }
            return await pasteWithoutFocusInfo(text)
        }

        let focus = FocusInspector.inspect(element)
        if focus.isSecure {
            copyToClipboard(text)
            return .copiedToClipboard(.secureField)
        }

        if mode == .automatic, focus.isEditable, !focus.isWebContent, await setDirectly(text, into: element) {
            return .inserted(.accessibility)
        }

        guard focus.isEditable || focus.isWebContent else {
            // Some editors draw their own text and hide it from Accessibility. "Always paste"
            // is the user's way of saying "paste here anyway".
            if mode == .pasteOnly {
                return await pasteWithoutFocusInfo(text)
            }
            copyToClipboard(text)
            return .copiedToClipboard(.noFocusedField)
        }
        return await paste(text, into: element, verify: !focus.isWebContent)
    }

    private func insertIntoOwnWindow(_ text: String) -> InsertionResult {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView, textView.isEditable else {
            copyToClipboard(text)
            return .copiedToClipboard(.noFocusedField)
        }
        textView.insertText(text, replacementRange: textView.selectedRange())
        return .inserted(.accessibility)
    }

    // MARK: - Accessibility

    /// Sets the text through Accessibility and confirms it landed. Some apps update their
    /// Accessibility values a moment later, so this waits briefly before deciding it failed;
    /// deciding too early would paste the text a second time.
    private func setDirectly(_ text: String, into element: AXUIElement) async -> Bool {
        guard FocusInspector.isSettable(element, kAXSelectedTextAttribute),
              let before = FocusInspector.characterCount(element) else { return false }
        let selection = FocusInspector.selectedRange(element)
        let status = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)
        guard status == .success else { return false }

        for attempt in 0..<6 {
            if attempt > 0 {
                try? await Task.sleep(for: .milliseconds(30))
            }
            guard let after = FocusInspector.characterCount(element) else { return false }
            if after != before {
                return true
            }
            // Same length can still be a successful replacement of an equally long selection.
            if let selection, selection.length == text.utf16.count,
               FocusInspector.string(element, in: CFRange(location: selection.location, length: selection.length)) == text {
                return true
            }
        }
        return false
    }

    // MARK: - Paste

    private func paste(_ text: String, into element: AXUIElement, verify: Bool) async -> InsertionResult {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        let before = verify ? FocusInspector.characterCount(element) : nil

        pasteboard.writeTransient(text)
        let ourChange = pasteboard.changeCount
        await KeyboardEvents.waitForModifierRelease()
        KeyboardEvents.postCommandV()

        if let before {
            for _ in 0..<25 {
                try? await Task.sleep(for: .milliseconds(40))
                if FocusInspector.characterCount(element) != before {
                    await restore(snapshot, to: pasteboard, ifStill: ourChange)
                    return .inserted(.paste)
                }
            }
            copyToClipboard(text)
            return .copiedToClipboard(.appRejected)
        }

        await restore(snapshot, to: pasteboard, ifStill: ourChange)
        return .inserted(.paste)
    }

    /// The app gives no focus information, so paste and leave the text on the clipboard in
    /// case it did not land.
    private func pasteWithoutFocusInfo(_ text: String) async -> InsertionResult {
        copyToClipboard(text)
        await KeyboardEvents.waitForModifierRelease()
        KeyboardEvents.postCommandV()
        return .inserted(.pasteUnconfirmed)
    }

    private func restore(_ snapshot: PasteboardSnapshot, to pasteboard: NSPasteboard, ifStill changeCount: Int) async {
        // Give the target app time to read the pasteboard before putting the old contents back.
        try? await Task.sleep(for: .milliseconds(300))
        if pasteboard.changeCount == changeCount {
            snapshot.restore(to: pasteboard)
        }
    }

    // MARK: - Focus

    /// If Krasip took focus (for example while the user edited text in the overlay),
    /// give it back to the app the dictation was meant for.
    private func bringToFront(_ target: InsertionTarget) async {
        guard let pid = target.processID,
              NSWorkspace.shared.frontmostApplication?.processIdentifier != pid,
              let app = NSRunningApplication(processIdentifier: pid) else { return }
        app.activate()
        for _ in 0..<40 {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid { break }
            try? await Task.sleep(for: .milliseconds(25))
        }
        try? await Task.sleep(for: .milliseconds(120))
    }
}
