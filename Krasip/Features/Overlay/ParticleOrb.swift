// ParticleOrb.swift
// Krasip
// Third recording orb: a wobbling sphere built from glowing dots.

import SwiftUI

struct ParticleOrb: View {
    let level: Float
    var diameter: CGFloat = 44

    @Environment(\.displayScale) private var displayScale
    @State private var smoothed: Float = 0
    @State private var origin = Date()

    /// The shader paints a halo outside the ball, so the view is wider than the ball.
    private var side: CGFloat { diameter * 1.22 }

    /// Dot rows are picked from the real pixel size, so the lattice never aliases.
    private var rows: Float {
        min(70, max(22, Float(side * displayScale) * 0.28))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Rectangle()
                .fill(.black)
                .frame(width: side, height: side)
                .colorEffect(
                    ShaderLibrary.particleOrb(
                        .float2(side, side),
                        .float(Float(timeline.date.timeIntervalSince(origin))),
                        .float(smoothed),
                        .float(rows)
                    )
                )
        }
        .frame(width: side, height: side)
        .onChange(of: level) { _, newValue in
            smoothed = smoothed * 0.7 + newValue * 0.3
        }
        .accessibilityHidden(true)
    }

    /// The bright blue of the rim, reused by the level meter.
    static let accent = Color(red: 0.640, green: 0.850, blue: 1.0)
}
