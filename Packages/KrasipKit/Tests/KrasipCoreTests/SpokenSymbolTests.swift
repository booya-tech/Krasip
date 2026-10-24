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
        ("ใส่เครื่องหมายชาร์ปข้างหน้าเลข", "ใส่ # ข้างหน้าเลข"),
        ("ราคา 100 ดอลลาร์", "ราคา $100"),
        ("งบวงเล็บเปิดประมาณวงเล็บปิด 50,000", "งบ(ประมาณ) 50,000"),
        ("หัวข้อเครื่องหมาย colon ทดสอบระบบ", "หัวข้อ: ทดสอบระบบ"),
        ("ปิดบรรทัดด้วยเครื่องหมาย semicolon นะ", "ปิดบรรทัดด้วย; นะ"),
        ("ชื่อบริษัท Johnson เครื่องหมายแห่ง Johnson", "ชื่อบริษัท Johnson & Johnson"),
        ("ดูที่เครื่องหมายดอกจันท้ายประโยค", "ดูที่ * ท้ายประโยค"),
        ("hex เครื่องหมายเท่ากับ 10", "hex = 10"),
        ("push a hash sign before the number", "push a # before the number")
    ]

    /// A symbol that sits between two things needs one space on each side, and the edges of the
    /// text and a line break count as a separator already.
    static let standaloneEdges: [(String, String)] = [
        ("เครื่องหมายเท่ากับ 10", "= 10"),
        ("10 เครื่องหมายเท่ากับ", "10 ="),
        ("hex\nเครื่องหมายเท่ากับ 10", "hex\n= 10"),
        ("hex เครื่องหมายเท่ากับ\n10", "hex =\n10"),
        ("hexเครื่องหมายเท่ากับ 10", "hex = 10"),
        ("hex เครื่องหมายเท่ากับ10", "hex = 10"),
        ("a hash sign b", "a # b")
    ]

    /// The model splits a glued name into two words as often as not, and a count word in front
    /// of the name repeats the symbol.
    static let spacedNamesAndCounts: [(String, String)] = [
        ("hash tag", "#"),
        ("ใส่ hash tag krasip", "ใส่ #krasip"),
        ("ใส่ แฮช แท็ก krasip", "ใส่ #krasip"),
        ("double hash tag", "##"),
        ("double colon sign", "::"),
        ("triple hash tag", "###"),
        ("เครื่องหมายดับเบิลโคลอน", "::"),
        ("ดับเบิล แฮช แท็ก", "##")
    ]

    /// `hash` is an ordinary English word as well as the name of `#`. In each of these the
    /// developer means the word, so the rule stands down and the text is left as spoken.
    static let hashAsAnOrdinaryWord: [String] = [
        "ใช้ hash map เก็บค่า",
        "เขียน hash function ใหม่",
        "the hash table is full",
        "ใช้ hash join ให้เร็วขึ้น",
        "เก็บ hash key กับ hash value",
        "แก้ hash collision ด้วย bucket",
        "ใช้ Hashmap เก็บค่า"
    ]

    @Test(arguments: recordings)
    func writesTheSymbolTheUserSpoke(raw: String, expected: String) {
        #expect(written(raw) == expected)
    }

    @Test(arguments: standaloneEdges)
    func keepsOneSpaceOnEachSideOfAStandaloneSymbol(raw: String, expected: String) {
        let once = written(raw)
        #expect(once == expected)
        #expect(!once.contains("  "))
    }

    @Test
    func aStandaloneSymbolSwallowsNoSpace() {
        let spaced = result("hex เครื่องหมายเท่ากับ 10").changes.filter { $0.kind == .spokenSymbol }
        #expect(spaced.map(\.before) == ["เครื่องหมายเท่ากับ"])
        #expect(spaced.map(\.after) == ["="])

        let unspaced = result("ดูที่เครื่องหมายดอกจันท้ายประโยค").changes.filter { $0.kind == .spokenSymbol }
        #expect(unspaced.map(\.before) == ["เครื่องหมายดอกจัน"])
        #expect(unspaced.map(\.after) == [" * "])
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
        #expect(written("นี้ดูเครื่องหมายชาร์ปขึ้นเยอะ") == "นี้ดู # ขึ้นเยอะ")
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

    @Test(arguments: recordings + standaloneEdges + spacedNamesAndCounts)
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
        #expect(written("ดูที่เครื่องหมายดอกจันทน์ท้ายประโยค") == "ดูที่ * ท้ายประโยค")
        #expect(written("ใส่ hashtag กระซิบ") == "ใส่ #กระซิบ")
        #expect(written("ใส่ hash tag krasip") == "ใส่ #krasip")
    }

    @Test(arguments: spacedNamesAndCounts)
    func writesASpacedNameAndRepeatsForACountWord(raw: String, expected: String) {
        #expect(written(raw) == expected)
    }

    @Test
    func logsTheCountWordAsPartOfThePhrase() {
        let changes = result("double hash tag").changes.filter { $0.kind == .spokenSymbol }
        #expect(changes.map(\.before) == ["double hash tag"])
        #expect(changes.map(\.after) == ["##"])

        let thai = result("เครื่องหมายดับเบิลโคลอน").changes.filter { $0.kind == .spokenSymbol }
        #expect(thai.map(\.before) == ["เครื่องหมายดับเบิลโคลอน"])
        #expect(thai.map(\.after) == ["::"])
    }

    @Test(arguments: hashAsAnOrdinaryWord)
    func leavesAnOrdinaryHashPhraseAlone(raw: String) {
        #expect(written(raw) == raw)
        #expect(result(raw).changes.allSatisfy { $0.kind != .spokenSymbol })
    }

    @Test
    func onlyTheWordRightAfterTheNameCanBlockTheSymbol() {
        #expect(written("hash the map") == "#the map")
        #expect(written("HASH MAP") == "HASH MAP")
    }

    @Test
    func aNameAtTheEndOfTheTextStillBecomesTheSymbol() {
        #expect(written("ใส่ hash") == "ใส่ #")
        #expect(written("hash") == "#")
    }

    @Test
    func aCountWordWithNoSymbolNameIsLeftAlone() {
        #expect(written("double trouble") == "double trouble")
        #expect(result("double trouble").changes.allSatisfy { $0.kind != .spokenSymbol })
        #expect(written("ดับเบิลเบอร์เกอร์") == "ดับเบิลเบอร์เกอร์")
    }

    /// The glossary runs before this rule and its output is protected, so a saved spelling
    /// settles the phrase and the rule never sees it.
    @Test
    func aGlossaryEntryClaimsThePhraseBeforeTheRuleRuns() {
        let glossary = Glossary([GlossaryEntry(
            aliases: ["hash map", "hashmap", "แฮชแมป"],
            preferredOutput: "Hashmap",
            mode: .locked
        )])
        let final = policy.finalize("ใช้ hash map เก็บค่า", glossary: glossary)
        #expect(final.text == "ใช้ Hashmap เก็บค่า")
        #expect(final.changes.allSatisfy { $0.kind != .spokenSymbol })
    }

    @Test
    func withNoGlossaryEntryThePhraseStaysAsSpoken() {
        #expect(written("ใช้ hash map เก็บค่า") == "ใช้ hash map เก็บค่า")
    }
}
