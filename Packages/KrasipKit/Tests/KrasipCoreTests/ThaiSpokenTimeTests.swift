// ThaiSpokenTimeTests.swift
// KrasipKit
// Checks that Thai spoken clock times become digits, and that look-alike phrases are left alone.

import Testing
@testable import KrasipCore

struct ThaiSpokenTimeTests {
    private let policy = TextPolicy()
    private let on = TextStyle(convertThaiTimes: true)

    @Test(arguments: [
        ("นัดเที่ยงคืน", "นัด 00:00"),
        ("ตื่นตีหนึ่ง", "ตื่น 01:00"),
        ("ตื่นตีสอง", "ตื่น 02:00"),
        ("ตื่นตีสองครึ่ง", "ตื่น 02:30"),
        ("ตื่นตีสาม", "ตื่น 03:00"),
        ("ตื่นตีสี่", "ตื่น 04:00"),
        ("ตื่นตีห้า", "ตื่น 05:00"),
        ("ตื่นตี 5", "ตื่น 05:00"),
        ("นัดหกโมงเช้า", "นัด 06:00"),
        ("นัดเจ็ดโมงเช้า", "นัด 07:00"),
        ("นัดเจ็ดโมง", "นัด 07:00"),
        ("นัดแปดโมงเช้า", "นัด 08:00"),
        ("นัดเก้าโมงเช้า", "นัด 09:00"),
        ("นัดสิบโมง", "นัด 10:00"),
        ("พรุ่งนี้สิบโมงเช้า", "พรุ่งนี้ 10:00"),
        ("สิบโมงเช้านะ", "10:00 นะ"),
        ("พรุ่งนี้สิบโมงครึ่ง", "พรุ่งนี้ 10:30"),
        ("นัดสิบเอ็ดโมงเช้า", "นัด 11:00"),
        ("นัดเที่ยง", "นัด 12:00"),
        ("นัดบ่ายโมง", "นัด 13:00"),
        ("นัดบ่ายโมงครึ่ง", "นัด 13:30"),
        ("นัดบ่าย 2", "นัด 14:00"),
        ("นัดบ่าย2", "นัด 14:00"),
        ("นัดบ่ายสอง", "นัด 14:00"),
        ("นัดบ่ายสองโมง", "นัด 14:00"),
        ("นัดบ่ายสองครึ่ง", "นัด 14:30"),
        ("นัดบ่ายสาม", "นัด 15:00"),
        ("นัดบ่ายสามโมง", "นัด 15:00"),
        ("นัดบ่ายสี่", "นัด 16:00"),
        ("เจอกันสี่โมงเย็น", "เจอกัน 16:00"),
        ("เลิกงานห้าโมง", "เลิกงาน 17:00"),
        ("เลิกงานห้าโมงเย็น", "เลิกงาน 17:00"),
        ("กลับบ้านหกโมงเย็น", "กลับบ้าน 18:00"),
        ("กินข้าวหนึ่งทุ่ม", "กินข้าว 19:00"),
        ("นัด 1 ทุ่ม", "นัด 19:00"),
        ("นัดสองทุ่มครึ่ง", "นัด 20:30"),
        ("นัดสองทุ่ม", "นัด 20:00"),
        ("นัดสามทุ่ม", "นัด 21:00"),
        ("นอนสี่ทุ่ม", "นอน 22:00"),
        ("นอนห้าทุ่ม", "นอน 23:00")
    ])
    func convertsThaiClockTimes(raw: String, expected: String) {
        #expect(policy.finalize(raw, glossary: Glossary(), style: on).text == expected)
    }

    @Test(arguments: [
        ("เดี๋ยวเจอกันตอนสิบเอ็ดโมงสิบห้า หน้าตึกนะ", "เดี๋ยวเจอกันตอน 11:15 หน้าตึกนะ"),
        ("นัดสิบโมงยี่สิบ", "นัด 10:20"),
        ("นัดเก้าโมงสี่สิบห้า", "นัด 09:45"),
        ("นัด 11 โมง 15", "นัด 11:15"),
        ("นัดสิบโมงสิบห้านาที", "นัด 10:15"),
        ("นัดสิบโมงห้านาที", "นัด 10:05"),
        ("นัดสิบโมงเช้าสิบห้า", "นัด 10:15"),
        ("นัดบ่ายสองโมงสี่สิบ", "นัด 14:40"),
        ("นัดสองทุ่มสิบห้า", "นัด 20:15"),
        ("เที่ยวบินออกตอน 6 โมง 45 ตอนเช้า", "เที่ยวบินออกตอน 06:45"),
        ("นัดหกโมงตอนเช้า", "นัด 06:00"),
        ("เจอกันห้าโมงสิบห้าตอนเย็น", "เจอกัน 17:15"),
        ("เจอกันหกโมงตอนเย็น", "เจอกัน 18:00")
    ])
    func convertsMinutesAndTrailingPeriod(raw: String, expected: String) {
        #expect(policy.finalize(raw, glossary: Glossary(), style: on).text == expected)
    }

    @Test(arguments: [
        ("นัดสิบโมงสิบคน", "นัด 10:00 สิบคน"),
        ("นัดสิบโมงห้าคน", "นัด 10:00 ห้าคน"),
        ("นัดสิบโมงสิบห้าคน", "นัด 10:00 สิบห้าคน"),
        ("นัดสิบโมง 20 บาท", "นัด 10:00 20 บาท")
    ])
    func doesNotReadACountAsMinutes(raw: String, expected: String) {
        #expect(policy.finalize(raw, glossary: Glossary(), style: on).text == expected)
    }

    // Some speech models put a space between Thai words, also inside a spoken time.
    @Test(arguments: [
        ("เริ่มงาน 8 โมง เช้า เลิก 5 โมง เย็น", "เริ่มงาน 08:00 เลิก 17:00"),
        ("เจอกัน บ่าย สอง ครึ่ง ที่ ออฟฟิศ", "เจอกัน 14:30 ที่ ออฟฟิศ"),
        ("นัดสิบโมง ครึ่ง", "นัด 10:30"),
        ("นัดสอง ทุ่ม ครึ่ง", "นัด 20:30"),
        ("นัดบ่าย โมง", "นัด 13:00"),
        ("นัดเที่ยง คืน", "นัด 00:00"),
        ("ออกตอน 6 โมง 45 ตอน เช้า", "ออกตอน 06:45")
    ])
    func convertsTimesWrittenWithSpaces(raw: String, expected: String) {
        #expect(policy.finalize(raw, glossary: Glossary(), style: on).text == expected)
    }

    @Test(arguments: [
        ("เลิกห้าโมง เย็นนี้ไปกินข้าว", "เลิก 17:00 เย็นนี้ไปกินข้าว"),
        ("นัดสิบโมง เช้าวันจันทร์", "นัด 10:00 เช้าวันจันทร์"),
        ("นัดสิบโมง ครึ่งวันก็พอ", "นัด 10:00 ครึ่งวันก็พอ")
    ])
    func keepsAWordThatStartsTheNextPhrase(raw: String, expected: String) {
        #expect(policy.finalize(raw, glossary: Glossary(), style: on).text == expected)
    }

    // After "ตี" the hour is always the first number, one to five, so what follows is minutes.
    @Test(arguments: [
        ("พรุ่งนี้ต้องตื่นตีห้าสิบห้า", "พรุ่งนี้ต้องตื่น 05:15"),
        ("วันนี้จะนอนสักตีหนึ่งสี่สิบห้า", "วันนี้จะนอนสัก 01:45"),
        ("ตื่นตีสี่สิบห้า", "ตื่น 04:15"),
        ("ตื่นตีสามสิบ", "ตื่น 03:10"),
        ("ตื่นตีสามยี่สิบนาที", "ตื่น 03:20"),
        ("ตื่นตีห้าห้านาที", "ตื่น 05:05"),
        ("ตื่นตี 5 15", "ตื่น 05:15"),
        ("ตื่น ตี ห้า สิบห้า", "ตื่น 05:15"),
        ("ตีห้าสิบห้าตื่นมาออกกำลังกาย", "05:15 ตื่นมาออกกำลังกาย")
    ])
    func convertsMinutesAfterEarlyMorningHours(raw: String, expected: String) {
        #expect(policy.finalize(raw, glossary: Glossary(), style: on).text == expected)
    }

    @Test(arguments: [
        ("ตื่นตีห้าสิบคน", "ตื่น 05:00 สิบคน"),
        ("ตื่นตีสิบห้า", "ตื่นตีสิบห้า"),
        ("ตื่นตี 55", "ตื่นตี 55")
    ])
    func doesNotInventMinutesAfterEarlyMorningHours(raw: String, expected: String) {
        #expect(policy.finalize(raw, glossary: Glossary(), style: on).text == expected)
    }

    // "ทุ่มหนึ่ง" and "ทุ่มนึง" are the everyday way to say หนึ่งทุ่ม.
    @Test(arguments: [
        ("เจอกันทุ่มหนึ่ง", "เจอกัน 19:00"),
        ("เจอกันทุ่มนึง", "เจอกัน 19:00"),
        ("เจอกันทุ่มครึ่ง", "เจอกัน 19:30"),
        ("เจอกัน ทุ่ม หนึ่ง นะ", "เจอกัน 19:00 นะ"),
        ("นัดสามทุ่มครึ่ง", "นัด 21:30")
    ])
    func convertsSevenInTheEveningSaidWithoutANumberFirst(raw: String, expected: String) {
        #expect(policy.finalize(raw, glossary: Glossary(), style: on).text == expected)
    }

    @Test(arguments: [
        "เขาทุ่มหนึ่งล้านบาท",
        "ทุ่มหนึ่งร้อยเปอร์เซ็นต์",
        "นัดหกทุ่มครึ่ง",
        "ทุ่มครึ่งหนึ่งของเงินเก็บ"
    ])
    func leavesThrowingAndSpendingAlone(raw: String) {
        #expect(policy.finalize(raw, glossary: Glossary(), style: on).text == raw)
    }

    // "หกโมง" and "สี่โมง" alone are unclear, so they convert only when เช้า or เย็น sits just before.
    @Test(arguments: [
        ("ตอนเช้าหกโมงสิบห้า", "ตอนเช้า 06:15"),
        ("พรุ่งนี้เช้าตื่น 6 โมง 15", "พรุ่งนี้เช้าตื่น 06:15"),
        ("เมื่อเช้าหกโมงผมตื่นแล้ว", "เมื่อเช้า 06:00 ผมตื่นแล้ว"),
        ("เย็นนี้เจอกันหกโมง", "เย็นนี้เจอกัน 18:00"),
        ("ตอนเย็นหกโมงครึ่ง", "ตอนเย็น 18:30"),
        ("เย็นนี้สี่โมงว่างไหม", "เย็นนี้ 16:00 ว่างไหม"),
        ("ตอน เช้า หก โมง สิบห้า", "ตอน เช้า 06:15")
    ])
    func usesAPeriodWordJustBeforeAnUnclearHour(raw: String, expected: String) {
        #expect(policy.finalize(raw, glossary: Glossary(), style: on).text == expected)
    }

    @Test(arguments: [
        "ตื่น 6 โมง 15",
        "หลังจากนั้นหกโมงยี่สิบไปออกกำลังกาย",
        "เมื่อเช้าเหนื่อยมาก เดี๋ยวเจอกันหกโมง",
        "ดื่มน้ำเย็นหกโมง",
        "ตอนเช้าสี่โมง",
        "เช้ามา 20 คน หกโมง",
        "ตอนเช้าว่าง ช่วงบ่ายถึงหกโมงไม่ว่าง"
    ])
    func leavesAnUnclearHourAloneWithoutAClearPeriodWord(raw: String) {
        #expect(policy.finalize(raw, glossary: Glossary(), style: on).text == raw)
    }

    // Hours that were already clear keep their meaning whatever word comes before.
    @Test(arguments: [
        ("เจอกันตอนเย็น 5 โมง 45", "เจอกันตอนเย็น 17:45"),
        ("ตอนเช้าเจ็ดโมงครึ่ง", "ตอนเช้า 07:30"),
        ("เมื่อเช้าประชุมเสร็จ ห้าโมงเจอกัน", "เมื่อเช้าประชุมเสร็จ 17:00 เจอกัน")
    ])
    func keepsClearHoursAsTheyWere(raw: String, expected: String) {
        #expect(policy.finalize(raw, glossary: Glossary(), style: on).text == expected)
    }

    @Test(arguments: [
        "ตอนบ่ายว่างไหม",
        "กินข้าวเที่ยงกัน",
        "ทุ่มเทมาก",
        "รอสิบชั่วโมง",
        "มื้อกลางวัน",
        "มื้อเที่ยง",
        "ตอนกลางวันร้อนมาก",
        "เที่ยงธรรม",
        "ไม่เที่ยง",
        "ตื่นหกโมง",
        "นัดหกโมงครึ่ง",
        "ทุ่มเงิน",
        "รอสิบนาที",
        "เที่ยงแท้",
        "มีสองคน",
        "นัดห้าโมงเช้า",
        "ตื่นหกโมงสิบห้า"
    ])
    func leavesNonTimesAlone(raw: String) {
        #expect(policy.finalize(raw, glossary: Glossary(), style: on).text == raw)
    }

    @Test func isOffByDefault() {
        #expect(policy.finalize("นัดสิบโมงเช้า", glossary: Glossary()).text == "นัดสิบโมงเช้า")
    }

    @Test func timeSurvivesPunctuationRemoval() {
        let style = TextStyle(punctuation: .none, convertThaiTimes: true)
        #expect(policy.finalize("นัดสิบโมงเช้า", glossary: Glossary(), style: style).text == "นัด 10:00")
    }
}
