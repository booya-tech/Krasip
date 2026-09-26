// PermissionRow.swift
// Krasip
// One permission with its status and a button to grant it.

import SwiftUI
import KrasipSystem

struct PermissionRow: View {
    let title: String
    let detail: String
    let status: PermissionStatus
    let grant: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: status == .granted ? "checkmark.circle.fill" : "circle.dashed")
                .font(.title3)
                .foregroundStyle(status == .granted ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if status == .granted {
                Text(AppString.Permissions.allowed)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Button(status == .notDetermined ? AppString.Permissions.allow : AppString.Permissions.openSettings, action: grant)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
