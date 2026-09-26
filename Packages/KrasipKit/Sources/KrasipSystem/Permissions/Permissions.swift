// Permissions.swift
// KrasipKit
// Reads and requests the three macOS permissions Krasip needs: Microphone, Accessibility, Speech Recognition.

import AppKit
import ApplicationServices
import AVFoundation
import Speech

public enum PermissionStatus: Equatable, Sendable {
    case granted
    case denied
    case notDetermined
}

@MainActor
public enum Permissions {
    public enum Pane: String {
        case microphone = "Privacy_Microphone"
        case accessibility = "Privacy_Accessibility"
        case speechRecognition = "Privacy_SpeechRecognition"
    }

    public static var microphone: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    public static func requestMicrophone() async -> PermissionStatus {
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        return microphone
    }

    /// Accessibility has no "not determined" state: the app is trusted or it is not.
    public static var accessibility: PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    /// Shows the system prompt that adds Krasip to the Accessibility list, then opens the pane.
    public static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            open(.accessibility)
        }
    }

    public static var speechRecognition: PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    public static func requestSpeechRecognition() async -> PermissionStatus {
        _ = await AppleSpeechTranscriber.requestAuthorization()
        return speechRecognition
    }

    public static func open(_ pane: Pane) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)") {
            NSWorkspace.shared.open(url)
        }
    }
}
