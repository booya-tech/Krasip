// FocusInspector.swift
// KrasipKit
// Reads the focused UI element through the Accessibility API: role, secure-field flag, editability, text length.

import AppKit
import ApplicationServices

/// A snapshot of the focused element.
struct FocusInfo {
    let element: AXUIElement
    let role: String?
    let subrole: String?
    let isSecure: Bool
    let isEditable: Bool
    let isWebContent: Bool
}

@MainActor
enum FocusInspector {
    private static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

    static func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.5)
        if let element = elementAttribute(systemWide, kAXFocusedUIElementAttribute) {
            return element
        }

        // Electron apps (Slack, VS Code, Notion…) hide their tree until asked for it.
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.5)
        if let element = elementAttribute(appElement, kAXFocusedUIElementAttribute) {
            return element
        }
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        return elementAttribute(appElement, kAXFocusedUIElementAttribute)
    }

    static func inspect(_ element: AXUIElement) -> FocusInfo {
        let role: String? = attribute(element, kAXRoleAttribute)
        let subrole: String? = attribute(element, kAXSubroleAttribute)
        let isSecure = subrole == (kAXSecureTextFieldSubrole as String) || role == "AXSecureTextField"
        let isEditable = role.map(textRoles.contains) == true
            || isSettable(element, kAXValueAttribute)
            || isSettable(element, kAXSelectedTextAttribute)
        return FocusInfo(
            element: element,
            role: role,
            subrole: subrole,
            isSecure: isSecure,
            isEditable: isEditable,
            isWebContent: hasWebAreaAncestor(element)
        )
    }

    /// Number of UTF-16 characters in the element, when the app reports it.
    static func characterCount(_ element: AXUIElement) -> Int? {
        if let count: Int = attribute(element, kAXNumberOfCharactersAttribute) {
            return count
        }
        if let value: String = attribute(element, kAXValueAttribute) {
            return value.utf16.count
        }
        return nil
    }

    static func selectedRange(_ element: AXUIElement) -> CFRange? {
        guard let value = rawAttribute(element, kAXSelectedTextRangeAttribute),
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return range
    }

    static func string(_ element: AXUIElement, in range: CFRange) -> String? {
        var mutableRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &mutableRange) else { return nil }
        var result: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &result
        )
        return status == .success ? result as? String : nil
    }

    static func isSettable(_ element: AXUIElement, _ name: String) -> Bool {
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(element, name as CFString, &settable) == .success && settable.boolValue
    }

    static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        rawAttribute(element, name) as? T
    }

    private static func rawAttribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = rawAttribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func hasWebAreaAncestor(_ element: AXUIElement) -> Bool {
        var current: AXUIElement? = element
        for _ in 0..<30 {
            guard let node = current else { return false }
            if (attribute(node, kAXRoleAttribute) as String?) == "AXWebArea" {
                return true
            }
            current = elementAttribute(node, kAXParentAttribute)
        }
        return false
    }
}
