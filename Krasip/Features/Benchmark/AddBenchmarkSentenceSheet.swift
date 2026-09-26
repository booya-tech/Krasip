// AddBenchmarkSentenceSheet.swift
// Krasip
// Adds one of your own sentences to the benchmark, with its expected output and key terms.

import SwiftUI
import KrasipCore

struct AddBenchmarkSentenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let model: BenchmarkModel

    @State private var category: BenchmarkCategory = .workTerms
    @State private var script = ""
    @State private var expected = ""
    @State private var keyTerms = ""
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppString.Benchmark.addTitle)
                .font(.title2.weight(.semibold))
            Text(AppString.Benchmark.addIntro)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Form {
                Picker(AppString.Benchmark.category, selection: $category) {
                    ForEach(BenchmarkCategory.allCases) { category in
                        Text(AppString.Benchmark.categoryName(category)).tag(category)
                    }
                }
                TextField(AppString.Benchmark.scriptField, text: $script, prompt: Text(verbatim: "เดี๋ยว push code ขึ้น GitHub"))
                VStack(alignment: .leading, spacing: 4) {
                    TextField(AppString.Benchmark.expectedField, text: $expected)
                    Text(AppString.Benchmark.expectedHelp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField(AppString.Benchmark.keyTermsField, text: $keyTerms)
                    Text(AppString.Benchmark.keyTermsHelp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField(AppString.Benchmark.noteField, text: $note)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(AppString.Common.cancel, role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(AppString.Benchmark.add) {
                    let terms = keyTerms.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    let trimmedNote = note.trimmingCharacters(in: .whitespaces)
                    model.addCustom(
                        category: category,
                        script: script,
                        expected: expected.trimmingCharacters(in: .whitespaces).isEmpty ? script : expected,
                        keyTerms: terms,
                        note: trimmedNote.isEmpty ? nil : trimmedNote
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(script.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 540)
    }
}
