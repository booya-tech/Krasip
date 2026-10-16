// swift-tools-version: 6.2
// Package.swift
// Krasip
// Command line wrapper around the app's text policy. The relay runs it before the correction model, which was trained on text that went through the same rules.

import PackageDescription

let package = Package(
    name: "policy-runner",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../Packages/KrasipKit")
    ],
    targets: [
        .executableTarget(
            name: "policy-runner",
            dependencies: [.product(name: "KrasipCore", package: "KrasipKit")]
        )
    ]
)
