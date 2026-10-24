// SpokenSymbolTests.swift
// KrasipKit
// Checks the spoken-symbol rule against raw Thonburian output: the symbol appears, nothing else moves.

import Testing
@testable import KrasipCore

struct SpokenSymbolTests {
    private let policy = TextPolicy()

    private func written(_ raw: String, decisions: PolicyDecisions = PolicyDecisions()) -> String {
        policy.finalize(raw, glossary: Glossary(), decisions: decisions).text
    }

    private func result(_ raw: String) -> FinalText {
        policy.finalize(raw, glossary: Glossary())
    }

    /// Verbatim raw output from the speech model on real recordings, and the text the user wants.
    static let recordings: [(String, String)] = [
        ("ว้าว เครื่องหมายตกใจ", "ว้าว!"),
        ("ใส่ hashtag กระซิบด้วย", "ใส่ #กระซิบด้วย"),
        ("ใส่เครื่องหมายชาร์ปข้างหน้าเลข", "ใส่#ข้างหน้าเลข"),
        ("ราคา 100 ดอลลาร์", "ราคา $100"),
        ("งบวงเล็บเปิดประมาณวงเล็บปิด 50,000", "งบ(ประมาณ) 50,000"),
        ("หัวข้อเครื่องหมาย colon ทดสอบระบบ", "หัวข้อ: ทดสอบระบบ"),
        ("ปิดบรรทัดด้วยเครื่องหมาย semicolon นะ", "ปิดบรรทัดด้วย; นะ"),
        ("ชื่อบริษัท Johnson เครื่องหมายแห่ง Johnson", "ชื่อบริษัท Johnson& Johnson"),
        ("ดูที่เครื่องหมายดอกจันท้ายประโยค", "ดูที่*ท้ายประโยค"),
        ("hex เครื่องหมายเท่ากับ 10", "hex= 10"),
        ("push a hash sign before the number", "push a #before the number")
    ]

    @Test(arguments: recordings)
    func writesTheSymbolTheUserSpoke(raw: String, expected: String) {
        #expect(written(raw) == expected)
    }

    @Test(arguments: recordings)
    func logsEverySymbolAsAChange(raw: String, expected: String) {
        let changes = result(raw).changes.filter { $0.kind == .spokenSymbol }
        #expect(!changes.isEmpty)
        for change in changes {
            #expect(raw.contains(change.before))
            #expect(expected.contains(change.after))
        }
    }

    @Test
    func logsTheSpokenPhraseAndTheSymbolItBecame() {
        let changes = result("ว้าว เครื่องหมายตกใจ").changes.filter { $0.kind == .spokenSymbol }
        #expect(changes.map(\.before) == [" เครื่องหมายตกใจ"])
        #expect(changes.map(\.after) == ["!"])
    }

    @Test
    func logsBothBracketsOfOneSentence() {
        let changes = result("งบวงเล็บเปิดประมาณวงเล็บปิด 50,000").changes.filter { $0.kind == .spokenSymbol }
        #expect(changes.map(\.before) == ["วงเล็บเปิด", "วงเล็บปิด"])
        #expect(changes.map(\.after) == ["(", ")"])
    }

    @Test
    func movesTheCurrencySymbolInFrontOfTheNumber() {
        let changes = result("ราคา 100 ดอลลาร์").changes.filter { $0.kind == .spokenSymbol }
        #expect(changes.map(\.before) == ["100 ดอลลาร์"])
        #expect(changes.map(\.after) == ["$100"])
    }

    /// Each of these came back from a real recording and must survive untouched.
    @Test(arguments: [
        "นี้ดู sharp ขึ้นเยอะ",
        "ราคาเป็นดอลล่ารึบาท",
        "ใส่ colon ใส่หลังคำว่า node",
        "เปิด https://example.com/hash-and-colon แล้วเมลไป hash@dollar.com",
        "ใช้ android แล้ว hashed password"
    ])
    func leavesTextWithoutASpokenSymbolAlone(raw: String) {
        #expect(written(raw) == raw)
        #expect(result(raw).changes.allSatisfy { $0.kind != .spokenSymbol })
    }

    @Test
    func bareNameNeedsNoMarkerButAMarkerNameDoes() {
        #expect(written("ใส่ hash กระซิบ") == "ใส่ #กระซิบ")
        #expect(written("นี้ดู sharp ขึ้นเยอะ") == "นี้ดู sharp ขึ้นเยอะ")
        #expect(written("นี้ดูเครื่องหมายชาร์ปขึ้นเยอะ") == "นี้ดู#ขึ้นเยอะ")
    }

    @Test
    func currencyNeedsDigitsInFront() {
        #expect(written("ราคา 20 dollars") == "ราคา $20")
        #expect(written("ราคาเป็นดอลลาร์หรือบาท") == "ราคาเป็นดอลลาร์หรือบาท")
    }

    @Test
    func theEnglishSuffixIsIgnoredInAThaiSentence() {
        #expect(!written("ใส่ colon ใส่หลังคำว่า node").contains(":"))
        #expect(written("add a colon sign here") == "add a: here")
    }

    @Test
    func protectedSpansKeepTheirSymbolNames() {
        let url = "เปิด https://example.com/hash-and-colon แล้วเมลไป hash@dollar.com"
        #expect(written(url) == url)
        #expect(written("รัน `hash and colon` ก่อน") == "รัน `hash and colon` ก่อน")
    }

    @Test
    func aColonBetweenDigitsStaysATime() {
        #expect(written("นัดบ่ายสองครึ่ง") == "นัด 14:30")
        #expect(written("นัดบ่ายสองครึ่งหัวข้อเครื่องหมาย colon ทดสอบ") == "นัด 14:30 หัวข้อ: ทดสอบ")
    }

    @Test
    func theUserCanUndoTheWholeRule() {
        let raw = "ว้าว เครื่องหมายตกใจ"
        let first = result(raw)
        guard let change = first.changes.first(where: { $0.kind == .spokenSymbol }) else {
            #expect(Bool(false), "no spoken-symbol change to undo")
            return
        }
        var decisions = PolicyDecisions()
        decisions.undo(change)
        #expect(written(raw, decisions: decisions) == raw)
    }

    @Test(arguments: recordings)
    func runningThePolicyAgainChangesNothingFurther(raw: String, expected: String) {
        let once = written(raw)
        #expect(once == expected)
        #expect(written(once) == once)
    }

    @Test
    func theSymbolIsProtectedFromLaterRules() {
        let segments = result("ใส่ hashtag krasip").segments
        #expect(segments.contains { $0.text == "#" && $0.protection == .spokenSymbol })
        #expect(written("ใส่ hashtag krasip") == "ใส่ #krasip")
    }

    @Test
    func theLongerSpellingOfANameWins() {
        #expect(written("ดูที่เครื่องหมายดอกจันทน์ท้ายประโยค") == "ดูที่*ท้ายประโยค")
        #expect(written("ใส่ hashtag กระซิบ") == "ใส่ #กระซิบ")
    }
}
