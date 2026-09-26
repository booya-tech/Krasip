// OnboardingView.swift
// Krasip
// First-run setup: welcome, microphone, accessibility, speech engine, practice, done.

import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case microphone
    case accessibility
    case engine
    case practice
    case done
}

struct OnboardingView: View {
    @Environment(AppController.self) private var app
    @State private var step: OnboardingStep

    init(initialStep: OnboardingStep = .welcome) {
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: WelcomeStep()
                case .microphone: MicrophoneStep()
                case .accessibility: AccessibilityStep()
                case .engine: EngineStep()
                case .practice: PracticeStep()
                case .done: DoneStep()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 44)
            .padding(.top, 36)

            Divider()
            HStack {
                StepDots(current: step)
                Spacer()
                if step != .welcome {
                    Button(AppString.Common.back) { move(-1) }
                }
                Button(step == .done ? AppString.Onboarding.finish : AppString.Common.continueLabel) {
                    if step == .done {
                        app.settings.hasCompletedOnboarding = true
                        app.windows.close(.onboarding)
                    } else {
                        move(1)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 660, height: 560)
        .onAppear { app.permissions.startPolling() }
        .onDisappear { app.permissions.stopPolling() }
    }

    private func move(_ delta: Int) {
        withAnimation(.snappy) {
            step = OnboardingStep(rawValue: step.rawValue + delta) ?? step
        }
    }
}

private struct StepDots: View {
    let current: OnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(step == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }
}
