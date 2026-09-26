// swift-tools-version: 6.2
// Package.swift
// KrasipKit
// Pipeline modules for Krasip: text policy, local storage, and macOS system adapters.

import PackageDescription

let package = Package(
    name: "KrasipKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KrasipCore", targets: ["KrasipCore"]),
        .library(name: "KrasipStorage", targets: ["KrasipStorage"]),
        .library(name: "KrasipSystem", targets: ["KrasipSystem"])
    ],
    targets: [
        .target(
            name: "KrasipCore",
            resources: [.process("Resources")]
        ),
        .target(
            name: "KrasipStorage",
            dependencies: ["KrasipCore"]
        ),
        .target(
            name: "KrasipSystem",
            dependencies: ["KrasipCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KrasipCoreTests",
            dependencies: ["KrasipCore"]
        ),
        .testTarget(
            name: "KrasipStorageTests",
            dependencies: ["KrasipStorage"]
        ),
        .testTarget(
            name: "KrasipSystemTests",
            dependencies: ["KrasipSystem"]
        )
    ],
    swiftLanguageModes: [.v6]
)
