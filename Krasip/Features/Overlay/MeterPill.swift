// MeterPill.swift
// Krasip
// The dark capsule under the recording orb: level bars, and in hands-free mode a cancel and a finish button.

import SwiftUI

struct MeterPill: View {
    let level: Float
    let showsActions: Bool
    let onCancel: () -> Void
    let onFinish: () -> Void

    private static let height: CGFloat = 29
    private static let circle: CGFloat = 17.5
    private static let gap: CGFloat = 8.5
    private static let buttonInset: CGFloat = 6
    private static let bareInset: CGFloat = 12
    private static let fill = Color(white: 0.039)
    private static let border = Color(white: 0.141)

    var body: some View {
        HStack(spacing: Self.gap) {
            if showsActions {
                cancelButton
            }
            LevelMeter(level: level)
            if showsActions {
                finishButton
            }
        }
        .padding(.horizontal, showsActions ? Self.buttonInset : Self.bareInset)
        .frame(height: Self.height)
        // Circular, not the macOS 26 default: a continuous capsule flattens the ends into straight sides.
        .background(Capsule(style: .circular).fill(Self.fill))
        .overlay(Capsule(style: .circular).strokeBorder(Self.border, lineWidth: 1))
        .animation(.snappy(duration: 0.2), value: showsActions)
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Self.circle, height: Self.circle)
                .background(Circle().fill(.white.opacity(0.24)))
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(AppString.Overlay.cancel)
    }

    private var finishButton: some View {
        Button(action: onFinish) {
            Image(systemName: "checkmark")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: Self.circle, height: Self.circle)
                .background(Circle().fill(.white))
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(AppString.Overlay.finish)
    }
}
