// KeyComboTests.swift
// KrasipSystemTests
// Shortcut names, modifier conversion, and which shortcuts are safe to register globally.

import AppKit
import Carbon.HIToolbox
import Testing
@testable import KrasipSystem

@MainActor
struct KeyComboTests {
    @Test func defaultShortcutIsOptionSpace() {
        #expect(KeyCombo.optionSpace.displayString == "⌥Space")
        #expect(KeyCombo.optionSpace.isUsableGlobally)
    }

    @Test func convertsAppKitModifiers() {
        let combo = KeyCombo(keyCode: UInt32(kVK_ANSI_D), modifierFlags: [.command, .shift])
        #expect(combo.modifiers == UInt32(cmdKey) | UInt32(shiftKey))
        #expect(combo.displayString.hasPrefix("⇧⌘"))
    }

    @Test func plainLettersAreNotGlobalShortcuts() {
        #expect(!KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: 0).isUsableGlobally)
        #expect(!KeyCombo(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(shiftKey)).isUsableGlobally)
        #expect(KeyCombo(keyCode: UInt32(kVK_F5), modifiers: 0).isUsableGlobally)
    }

    @Test func combosSurviveCoding() throws {
        let data = try JSONEncoder().encode(KeyCombo.optionSpace)
        #expect(try JSONDecoder().decode(KeyCombo.self, from: data) == .optionSpace)
    }

    @Test func pasteKeyIsFoundInCurrentLayout() {
        #expect(KeyboardEvents.keyCode(for: "v") != nil)
    }
}
