// OverlayCardView.swift
// Krasip
// The overlay card for one dictation phase, on a solid near-black background.

import SwiftUI
import KrasipCore

struct OverlayCardView: View {
    let phase: FlowPhase

    /// Solid, not a blur: a translucent card disappears into a white desktop.
    private static let cardFill = Color(white: 0.071)
    private static let cardBorder = Color(white: 0.141)

    var body: some View {
        card
            .padding(.horizontal, isBare ? 10 : 16)
            .padding(.vertical, isBare ? 10 : 14)
            .frame(width: width, alignment: isBare ? .center : .leading)
            .background {
                if !isBare {
                    RoundedRectangle(cornerRadius: 16).fill(Self.cardFill)
                }
            }
            .overlay {
                if !isBare {
                    RoundedRectangle(cornerRadius: 16).strokeBorder(Self.cardBorder)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .animation(.snappy(duration: 0.2), value: phaseKey)
    }

    @ViewBuilder
    private var card: some View {
        switch phase {
        case .idle:
            Color.clear.frame(height: 1)
        case .listening(let listening):
            ListeningCard(listening: listening)
        case .transcribing(let appName):
            WorkingCard(title: AppString.Overlay.transcribing, appName: appName, showsCancel: true)
        case .inserting(let appName):
            WorkingCard(title: AppString.Overlay.inserting(appName), appName: nil, showsCancel: false)
        case .review(let review):
            ReviewCard(review: review)
        case .finished(let finished):
            ResultCard(finished: finished)
        case .notice(let notice):
            NoticeCard(notice: notice)
        }
    }

    private var width: CGFloat {
        switch phase {
        case .review, .finished: 440
        case .notice: 380
        case .listening: 140
        case .idle: 140
        default: 340
        }
    }

    /// Phases drawn with no card behind them. Idle is included so the panel never
    /// flashes an empty blurred rectangle on its way into the listening orb.
    private var isBare: Bool {
        switch phase {
        case .listening, .idle: true
        default: false
        }
    }

    private var phaseKey: String {
        switch phase {
        case .idle: "idle"
        case .listening(let listening): listening.handsFree ? "handsFree" : "listening"
        case .transcribing: "transcribing"
        case .inserting: "inserting"
        case .review: "review"
        case .finished: "finished"
        case .notice: "notice"
        }
    }
}
