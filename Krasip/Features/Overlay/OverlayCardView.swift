// OverlayCardView.swift
// Krasip
// The overlay card for one dictation phase, on a dark blurred background.

import SwiftUI
import KrasipCore

struct OverlayCardView: View {
    let phase: FlowPhase

    var body: some View {
        card
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(width: width, alignment: .leading)
            .background(VisualEffectBackground(material: .hudWindow, cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12)))
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
        default: 340
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
