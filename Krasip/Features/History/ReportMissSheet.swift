// ReportMissSheet.swift
// Krasip
// Turns one dictation into a filled-in GitHub issue: model misses go to the correction repo, anything else to the app repo.

import AppKit
import SwiftUI
import KrasipCore

struct ReportMissSheet: View {
    @Environment(\.dismiss) private var dismiss

    let record: DictationRecord

    @State private var report: MissReport

    init(record: DictationRecord, initialKind: MissKind = .notSure) {
        self.record = record
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        var report = MissReport(record: record, appVersion: version)
        report.kind = initialKind
        _report = State(initialValue: report)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppString.History.reportTitle)
                .font(.title2.weight(.semibold))
            Text(AppString.History.reportIntro)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            known

            if report.kind.isModelMiss {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppString.History.reportWanted)
                        .font(.headline)
                    TextEditor(text: $report.wantedText)
                        .font(.system(size: 15))
                        .frame(height: 64)
                        .padding(6)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(AppString.History.reportKind)
                    .font(.headline)
                Picker("", selection: $report.kind) {
                    ForEach(MissKind.allCases) { kind in
                        Text(AppString.History.reportKindName(kind)).tag(kind)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            if report.kind == .somethingElse {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppString.History.reportNote)
                        .font(.headline)
                    TextField("", text: $report.note, prompt: Text(AppString.History.reportNotePrompt))
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                }
            }

            Text(report.kind.isModelMiss ? AppString.History.reportModelHelp : AppString.History.reportAppHelp)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button(AppString.History.reportCancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(AppString.History.reportSend, action: send)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!report.canSend)
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    private var known: some View {
        VStack(alignment: .leading, spacing: 6) {
            labelled(AppString.History.reportHeard, record.rawText)
            labelled(AppString.History.reportTyped, record.finalText)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func labelled(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 14))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func send() {
        guard let url = report.issueURL else { return }
        NSWorkspace.shared.open(url)
        dismiss()
    }
}
