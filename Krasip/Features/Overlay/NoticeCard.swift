// NoticeCard.swift
// Krasip
// Overlay card for problems: no speech, password field, missing permission, recognizer errors.

import SwiftUI
import KrasipCore

struct NoticeCard: View {
    @Environment(AppController.self) private var app
    let notice: FlowPhase.Notice

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                if let detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let action {
                    Button(action.title, action: action.run)
                        .controlSize(.small)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .onHover { hovering in
            if hovering {
                app.flow.holdResult()
            } else {
                app.flow.releaseResult()
            }
        }
    }

    private struct Action {
        let title: String
        let run: () -> Void
    }

    private var symbol: String {
        switch notice.kind {
        case .noSpeech, .holdLonger: "waveform.slash"
        case .secureField: "lock.fill"
        case .microphone: "mic.slash.fill"
        case .transcription, .failure: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch notice.kind {
        case .noSpeech, .holdLonger: .secondary
        default: .orange
        }
    }

    private var title: String {
        let shortcut = app.settings.hotkey.displayString
        switch notice.kind {
        case .noSpeech: return AppString.Notice.noSpeech
        case .holdLonger: return AppString.Notice.holdLonger(shortcut)
        case .secureField: return AppString.Notice.secureField
        case .microphone(.microphoneDenied): return AppString.Notice.microphoneOff
        case .microphone: return AppString.Notice.microphoneProblem
        case .transcription(.missingAPIKey), .transcription(.invalidAPIKey): return AppString.Notice.apiKey
        case .transcription(.notAuthorized): return AppString.Notice.speechOff
        case .transcription: return AppString.Notice.transcriptionFailed
        case .failure: return AppString.Notice.somethingWrong
        }
    }

    private var detail: String? {
        let shortcut = app.settings.hotkey.displayString
        switch notice.kind {
        case .noSpeech: return AppString.Notice.noSpeechDetail(shortcut)
        case .holdLonger: return AppString.Notice.holdLongerDetail(shortcut)
        case .secureField: return AppString.Notice.secureFieldDetail
        case .microphone(let error): return error.localizedDescription
        case .transcription(let error): return error.localizedDescription
        case .failure(let message): return message
        }
    }

    private var action: Action? {
        switch notice.kind {
        case .microphone(.microphoneDenied):
            Action(title: AppString.Notice.openMicrophoneSettings) { Task { await app.permissions.requestMicrophone() } }
        case .transcription(.missingAPIKey), .transcription(.invalidAPIKey):
            Action(title: AppString.Notice.openLanguageSettings) { app.showSettings(.languages) }
        case .transcription(.notAuthorized):
            Action(title: AppString.Notice.allowSpeech) { Task { await app.permissions.requestSpeechRecognition() } }
        case .transcription(.unavailable):
            Action(title: AppString.Notice.openLanguageSettings) { app.showSettings(.languages) }
        default:
            nil
        }
    }
}
