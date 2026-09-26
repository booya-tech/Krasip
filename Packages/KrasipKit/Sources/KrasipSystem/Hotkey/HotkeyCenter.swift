// HotkeyCenter.swift
// KrasipKit
// Global shortcuts with separate press and release events (for push-to-talk), via Carbon hot keys.

import Carbon.HIToolbox
import Foundation

public struct HotkeyToken: Hashable, Sendable {
    fileprivate let id: UInt32
}

public enum HotkeyError: Error, Equatable, LocalizedError {
    /// Another app already uses this shortcut.
    case alreadyInUse
    case registrationFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .alreadyInUse:
            String(localized: "Another app already uses this shortcut. Choose a different one.", bundle: .module)
        case .registrationFailed(let status):
            String(localized: "The shortcut could not be registered (\(String(status))).", bundle: .module)
        }
    }
}

/// Carbon hot keys work without Accessibility permission, report key-up events, and swallow
/// the key so ⌥Space does not also type a space into the focused app.
@MainActor
public final class HotkeyCenter {
    public static let shared = HotkeyCenter()

    private struct Registration {
        let reference: EventHotKeyRef
        let onPress: @MainActor () -> Void
        let onRelease: @MainActor () -> Void
    }

    private var registrations: [UInt32: Registration] = [:]
    private var handler: EventHandlerRef?
    private var nextID: UInt32 = 1
    private static let signature: OSType = 0x5753_5046 // "WSPF"

    private init() {}

    public func register(
        _ combo: KeyCombo,
        onPress: @escaping @MainActor () -> Void,
        onRelease: @escaping @MainActor () -> Void = {}
    ) throws -> HotkeyToken {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1

        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetEventDispatcherTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            throw status == eventHotKeyExistsErr ? HotkeyError.alreadyInUse : HotkeyError.registrationFailed(status)
        }
        registrations[id] = Registration(reference: reference, onPress: onPress, onRelease: onRelease)
        return HotkeyToken(id: id)
    }

    public func unregister(_ token: HotkeyToken?) {
        guard let token, let registration = registrations.removeValue(forKey: token.id) else { return }
        UnregisterEventHotKey(registration.reference)
    }

    fileprivate func dispatch(id: UInt32, pressed: Bool) {
        guard let registration = registrations[id] else { return }
        if pressed {
            registration.onPress()
        } else {
            registration.onRelease()
        }
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        InstallEventHandler(GetEventDispatcherTarget(), hotkeyEventHandler, eventTypes.count, &eventTypes, nil, &handler)
    }
}

/// Carbon delivers hot key events on the main thread.
private func hotkeyEventHandler(_ callRef: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
    let id = hotKeyID.id
    MainActor.assumeIsolated {
        HotkeyCenter.shared.dispatch(id: id, pressed: pressed)
    }
    return noErr
}
