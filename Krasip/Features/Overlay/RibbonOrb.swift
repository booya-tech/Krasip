// RibbonOrb.swift
// Krasip
// Alternative recording orb: glowing ribbons curling inside a dark glass ball.

import SwiftUI

struct RibbonOrb: View {
    let level: Float
    var diameter: CGFloat = 44

    @State private var smoothed: Float = 0
    @State private var origin = Date()

    /// The shader paints a halo outside the ball, so the view is wider than the ball.
    private var side: CGFloat { diameter * 1.25 }

    var body: some View {
        TimelineView(.animation) { timeline in
            Rectangle()
                .fill(.black)
                .frame(width: side, height: side)
                .colorEffect(
                    ShaderLibrary.ribbonOrb(
                        .float2(side, side),
                        .float(Float(timeline.date.timeIntervalSince(origin))),
                        .float(smoothed)
                    )
                )
        }
        .frame(width: side, height: side)
        .onChange(of: level) { _, newValue in
            smoothed = smoothed * 0.7 + newValue * 0.3
        }
        .accessibilityHidden(true)
    }

    /// The brightest blue in the ribbons, reused by the level meter.
    static let accent = Color(red: 0.776, green: 0.820, blue: 1.0)
}
