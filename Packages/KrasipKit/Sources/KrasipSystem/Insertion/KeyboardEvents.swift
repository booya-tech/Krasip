// KeyboardEvents.swift
// KrasipKit
// Posts a synthetic Command-V that works with any keyboard layout, including Thai Kedmanee.

import Carbon.HIToolbox
import CoreGraphics

/// Main thread only: the keyboard layout APIs abort when used from a background thread.
@MainActor
enum KeyboardEvents {
    /// The key that types "v" in the current ASCII-capable layout. Command shortcuts use that
    /// layout even while Thai input is active, so this also covers Dvorak and similar layouts.
    static func keyCode(for character: String) -> CGKeyCode? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        return layoutData.withUnsafeBytes { buffer -> CGKeyCode? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for code in 0..<128 {
                var deadKeyState: UInt32 = 0
                var characters = [UniChar](repeating: 0, count: 4)
                var length = 0
                let status = UCKeyTranslate(
                    layout,
                    UInt16(code),
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    characters.count,
                    &length,
                    &characters
                )
                if status == noErr, length > 0, String(utf16CodeUnits: characters, count: length) == character {
                    return CGKeyCode(code)
                }
            }
            return nil
        }
    }

    static func postCommandV() {
        let key = keyCode(for: "v") ?? CGKeyCode(kVK_ANSI_V)
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    /// Waits until the user lets go of ⌥/⌘/⌃/⇧ so they don't turn ⌘V into another shortcut.
    static func waitForModifierRelease(timeout: Duration = .milliseconds(800)) async {
        let modifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if CGEventSource.flagsState(.hidSystemState).intersection(modifiers).isEmpty {
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}
