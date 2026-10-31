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

    /// An empty pair is a function call, so it sticks to the name before it and keeps a word after
    /// it apart. Whisper writes the two names with or without a space between them, and runs the
    /// Thai word after them straight on.
    static let emptyBrackets: [(String, String)] = [
        ("เรียก function fetchUser วงเล็บเปิดวงเล็บปิดก่อน render", "เรียก function fetchUser() ก่อน render"),
        ("เรียก fetchUser วงเล็บเปิดวงเล็บปิด render", "เรียก fetchUser() render"),
        ("เรียก fetchUser วงเล็บเปิดวงเล็บปิด", "เรียก fetchUser()"),
        ("เรียก function fetchUser วงเล็บเปิดวงเล็บปิด ก่อน render", "เรียก function fetchUser() ก่อน render"),
        ("เรียก function fetchUser วงเล็บเปิด วงเล็บปิด ก่อน render", "เรียก function fetchUser() ก่อน render"),
        ("เรียก fetchUserวงเล็บซ้ายวงเล็บขวา", "เรียก fetchUser()"),
        ("เรียก function fetchUser วงเล็บเปิด id วงเล็บปิด ก่อน render", "เรียก function fetchUser (id) ก่อน render")
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

    /// `@` said by name. The bare Thai name only counts with a Latin token on each side, and the
    /// symbol then joins the two into one address.
    static let atSignNames: [(String, String)] = [
        ("support แอท krasip", "support@krasip"),
        ("support แอท krasip.app", "support@krasip.app"),
        ("user1 แอท gmail.com", "user1@gmail.com"),
        ("เครื่องหมายแอท", "@"),
        ("support เครื่องหมายแอท krasip.app", "support@krasip.app"),
        ("at sign", "@"),
        ("type the at sign here", "type the @ here"),
        ("add sign", "@"),
        ("แอดไซน์", "@"),
        ("เครื่องหมาย add", "@"),
        ("support แอดไซน์ krasip", "support@krasip")
    ]

    /// An address spoken in parts. The first four are verbatim raw output from real recordings of
    /// "patompong.beam@gmail.com" and another address, in a normal voice and a whisper.
    static let spokenEmails: [(String, String)] = [
        (
            "ช่วยร่างอีเมลนี้ให้หน่อย ปลายทางอีเมลคือ patompong.beam at sign gmail.com แล้วก็ส่งอีเมลนี้ไปตอน 6 โมงเช้าของวันพรุ่งนี้ให้หน่อยนะ",
            "ช่วยร่างอีเมลนี้ให้หน่อย ปลายทางอีเมลคือ patompong.beam@gmail.com แล้วก็ส่งอีเมลนี้ไปตอน 6 โมงเช้าของวันพรุ่งนี้ให้หน่อยนะ"
        ),
        (
            "ปลายทางอีเมลคือ patombong.beam แอดไซน์ gmail.com แล้วก็ช่วยส่ง",
            "ปลายทางอีเมลคือ patombong.beam@gmail.com แล้วก็ช่วยส่ง"
        ),
        ("p-a-t-o-m-p-o-n-g .p-e-a-m แอดไซน์ gmail.com", "patompong.peam@gmail.com"),
        ("p-o-o-y-a dot p-a-n-n-a-c-h-a-i แอดไซน์ gmail dot com", "pooya.pannachai@gmail.com"),
        ("ช่วยส่งข้อมูลนี้ไปให้ emailartridge at gmail.com", "ช่วยส่งข้อมูลนี้ไปให้ emailartridge@gmail.com"),
        ("beam add sign gmail.com", "beam@gmail.com"),
        ("beam at-sign krasip.app", "beam@krasip.app"),
        ("ส่งไปที่ beam แอทไซน์ krasip.co.th ด้วย", "ส่งไปที่ beam@krasip.co.th ด้วย"),
        ("ส่งไปที่ beam at sign gmail.com.", "ส่งไปที่ beam@gmail.com."),
        ("mail beam at outlook.com then call", "mail beam@outlook.com then call"),
        ("ส่งไปที่ beam.p at sign gmail.com", "ส่งไปที่ beam.p@gmail.com")
    ]

    static let everyConversion: [(String, String)] = [
        recordings, standaloneEdges, emptyBrackets, spacedNamesAndCounts, atSignNames, dottedEmails, spokenEmails
    ].flatMap { $0 }

    /// Near misses of a spoken address, which must come back unchanged.
    static let notASpokenEmail: [String] = [
        "add sign up here",
        "click add sign-in button",
        "add sign out to the menu",
        "I work at google.com",
        "meet at gmail",
        "ส่ง e-mail ให้หน่อย",
        "patompong.beamassign@gmail.com"
    ]

    /// The model writes the `@` of a spoken address as a dot, or keeps the word "at" as a label.
    /// The first comes from a real recording, the rest vary its cue word.
    static let dottedEmails: [(String, String)] = [
        ("ส่งไปที่ support.at.grasip.app ได้เลยครับ", "ส่งไปที่ support@grasip.app ได้เลยครับ"),
        ("ส่งสำเนาไปที่ admin.example.com ด้วย", "ส่งสำเนาไปที่ admin@example.com ด้วย"),
        ("ส่งอีเมลไปที่ admin.example.com", "ส่งอีเมลไปที่ admin@example.com"),
        ("cc admin.example.com", "cc admin@example.com"),
        ("ส่งอีเมล์ไปที่ admin.example.com", "ส่งอีเมล์ไปที่ admin@example.com"),
        ("ส่งเมลหา admin.example.com ด้วย", "ส่งเมลหา admin@example.com ด้วย"),
        ("ส่ง Email ไปที่ admin.example.com", "ส่ง Email ไปที่ admin@example.com"),
        ("ส่ง e-mail ถึง admin.example.com", "ส่ง e-mail ถึง admin@example.com"),
        ("ใส่ bcc admin.example.com ด้วย", "ใส่ bcc admin@example.com ด้วย"),
        ("ส่งอีเมลไปที่ admin.example.com.", "ส่งอีเมลไปที่ admin@example.com."),
        ("ส่งอีเมลไปที่ info.example.com", "ส่งอีเมลไปที่ info@example.com"),
        ("ส่งสำเนาไปที่ support.example.co", "ส่งสำเนาไปที่ support@example.co"),
        ("cc sales.example.com", "cc sales@example.com")
    ]

    /// "at" is an everyday English word and แอท is the start of longer Thai words, so none of
    /// these is an `@`.
    static let atAsAnOrdinaryWord: [String] = [
        "meet me at noon",
        "look at this",
        "แอทแลนติก",
        "ที่ at",
        "ไปแอทมา",
        "support แอทมา",
        "ไปแอท krasip",
        "ราคา 2 แอท 3 บาท",
        "ส่งไปที่ support at krasip"
    ]

    /// Dotted text from everyday dictation. A wrong `@` here is worse than a missing one, so every
    /// line must come back byte-identical.
    static let ordinaryDottedText: [String] = [
        "file.txt",
        "github.com",
        "www.example.com",
        "v1.2.3",
        "3.14",
        "e.g.",
        "Node.js",
        "ดูที่ api.github.com/users",
        "เปิด https://admin.example.com",
        "ไฟล์ report.final.pdf ส่งแล้ว",
        "ส่ง docs.example.com ให้หน่อย",
        "ส่งอีเมลไปที่ docs.example.com",
        "ส่งอีเมลไปที่ api.example.dev",
        "ส่งอีเมลไปที่ blog.example.com",
        "ส่งสำเนาไปที่ shop.example.com",
        "ส่งอีเมลไปที่ at.example.com",
        "กินเมลอนที่ shop.example.com",
        "cc john.example.com",
        "example.at",
        "at.example.com",
        "v1.at.2",
        "Array.prototype.at.call",
        "ดูที่ www.foo.at.example.com",
        "https://foo.at.example.com/x",
        "ส่งไปที่ admin.example.com",
        "ส่งมาที่ admin.example.com",
        "เข้าไปที่ admin.example.com",
        "ส่งสำเนาไปที่ support.app.grasip.app",
        "ส่งอีเมล https://admin.example.com",
        "ส่งอีเมลไปที่ admin.example.com/login",
        "ส่งอีเมลไปที่ file.txt",
        "ส่งอีเมลไปที่ v1.2.3",
        "ส่งอีเมลไปที่ www.example.com",
        "ส่งอีเมลไปที่ mail.google.com",
        "ส่งสำเนา report.final.pdf ให้หน่อย",
        "อีเมล obj.method.call()",
        "เมลไป `admin.example.com`",
        "ขอ cc admin.example.com:8080",
        "account admin.example.com",
        "gmail admin.example.com",
        "ซื้อเมล็ดกาแฟจาก shop.example.com",
        "ส่งอีเมลมา\nadmin.example.com",
        "ส่งอีเมลมาด้วยนะครับพี่ เดี๋ยวผมเช็คให้อีกที admin.example.com",
        "อีเมลอยู่ที่ john@example.com"
    ]

    @Test(arguments: recordings)
    func writesTheSymbolTheUserSpoke(raw: String, expected: String) {
        #expect(written(raw) == expected)
    }

    @Test(arguments: emptyBrackets)
    func writesAnEmptyPairAsACall(raw: String, expected: String) {
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

    @Test(arguments: everyConversion)
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

    @Test(arguments: atSignNames)
    func writesTheAtSignTheUserSpoke(raw: String, expected: String) {
        #expect(written(raw) == expected)
    }

    @Test
    func logsTheSpokenAtWithTheSpacesItJoined() {
        let changes = result("support แอท krasip.app").changes.filter { $0.kind == .spokenSymbol }
        #expect(changes.map(\.before) == [" แอท "])
        #expect(changes.map(\.after) == ["@"])
    }

    @Test(arguments: atAsAnOrdinaryWord)
    func leavesAnOrdinaryAtAlone(raw: String) {
        #expect(written(raw) == raw)
        #expect(result(raw).changes.allSatisfy { $0.kind != .spokenSymbol })
    }

    @Test(arguments: dottedEmails)
    func putsBackTheAtOfADottedEmail(raw: String, expected: String) {
        #expect(written(raw) == expected)
    }

    @Test
    func logsTheWholeAddressAsOneChange() {
        let label = result("ส่งไปที่ support.at.grasip.app ได้เลยครับ").changes.filter { $0.kind == .spokenSymbol }
        #expect(label.map(\.before) == ["support.at.grasip.app"])
        #expect(label.map(\.after) == ["support@grasip.app"])

        let dot = result("ส่งสำเนาไปที่ admin.example.com ด้วย").changes.filter { $0.kind == .spokenSymbol }
        #expect(dot.map(\.before) == ["admin.example.com"])
        #expect(dot.map(\.after) == ["admin@example.com"])
    }

    @Test
    func theRepairedAddressIsProtectedAsAnEmail() {
        let segments = result("ส่งสำเนาไปที่ admin.example.com ด้วย").segments
        #expect(segments.contains { $0.text == "admin@example.com" && $0.protection == .email })
    }

    @Test(arguments: ordinaryDottedText)
    func leavesDottedTextThatIsNotAnEmailAlone(raw: String) {
        #expect(written(raw) == raw)
        #expect(result(raw).changes.allSatisfy { $0.kind != .spokenSymbol })
    }

    @Test
    func theUserCanUndoTheEmailRepair() {
        let raw = "ส่งสำเนาไปที่ admin.example.com ด้วย"
        guard let change = result(raw).changes.first(where: { $0.kind == .spokenSymbol }) else {
            #expect(Bool(false), "no spoken-symbol change to undo")
            return
        }
        var decisions = PolicyDecisions()
        decisions.undo(change)
        #expect(written(raw, decisions: decisions) == raw)
    }

    @Test(arguments: spokenEmails)
    func assemblesAnEmailAddressSpokenInParts(raw: String, expected: String) {
        #expect(written(raw) == expected)
    }

    @Test(arguments: notASpokenEmail)
    func leavesNearMissesOfASpokenEmailAlone(raw: String) {
        #expect(written(raw) == raw)
        #expect(result(raw).changes.allSatisfy { $0.kind != .spokenSymbol })
    }

    @Test
    func logsTheSpokenAddressAsOneChangeTheUserCanUndo() {
        let raw = "ส่งไปที่ patompong.beam at sign gmail.com ด้วย"
        let changes = result(raw).changes.filter { $0.kind == .spokenSymbol }
        #expect(changes.map(\.before) == ["patompong.beam at sign gmail.com"])
        #expect(changes.map(\.after) == ["patompong.beam@gmail.com"])
        guard let change = changes.first else { return }
        var decisions = PolicyDecisions()
        decisions.undo(change)
        #expect(written(raw, decisions: decisions) == raw)
    }
}
