// SpokenTimeTests.swift
// KrasipCoreTests
// Spoken English clock times become digits; other number words stay as spoken.

import Foundation
import Testing
@testable import KrasipCore

struct SpokenTimeTests {
    private let policy = TextPolicy()

    @Test(arguments: [
        ("ตอน ten AM", "ตอน 10 AM"),
        ("ตอน Ten am", "ตอน 10 am"),
        ("ตอน ten a.m.", "ตอน 10 a.m."),
        ("ประชุม nine thirty PM", "ประชุม 9:30 PM"),
        ("นัด twelve fifteen pm", "นัด 12:15 pm"),
        ("เจอกัน seven o'clock", "เจอกัน 7 o'clock"),
        ("ตื่น six oh five AM", "ตื่น 6:05 AM"),
        ("ส่งก่อน eleven forty-five PM", "ส่งก่อน 11:45 PM"),
        ("ตอนten AM", "ตอน 10 AM")
    ])
    func convertsClockTimes(raw: String, expected: String) {
        #expect(policy.finalize(raw, glossary: Glossary()).text == expected)
    }

    @Test(arguments: [
        "มี two meetings วันนี้",
        "ten people มาแล้ว",
        "ตอนสิบโมง",
        "at nine แล้วกัน",
        "10 AM อยู่แล้ว"
    ])
    func leavesOtherNumbersAlone(raw: String) {
        #expect(policy.finalize(raw, glossary: Glossary()).text == raw)
    }

    @Test func canBeTurnedOff() {
        let style = TextStyle(convertSpokenTimes: false)
        #expect(policy.finalize("ตอน ten AM", glossary: Glossary(), style: style).text == "ตอน ten AM")
    }
}
