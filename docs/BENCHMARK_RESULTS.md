# Benchmark results, real voice

What Apple's on-device recognizer actually does with the owner's own speech, measured on 6 October 2026. This replaces the synthetic-voice run in [`SPEC_CHECKLIST.md`](SPEC_CHECKLIST.md#first-benchmark-run-synthetic-voice), which used the macOS Thai voice "Kanya" and was a worst case rather than a real one.

## Setup

- Engine: **Apple, on this Mac** (on-device Thai, macOS 26)
- 55 of the 56 bundled sentences, read aloud by the owner at normal speed. `C01` is not yet recorded.
- The benchmark set's own glossary applies, which holds `side-project` and the lowercase `report` rule.
- Recordings and scores live in `~/Library/Application Support/Krasip/Benchmark/`.

## Headline

| Metric | Result |
| --- | --- |
| Key terms kept | **31 of 83, 37%** |
| Sentences matching the expected text exactly | 19 of 55, 35% |
| Median character error rate | 0.19 |
| Median latency | **0.19 s** per clip, max 0.44 s |

The 37% is an average across very different cases. Read the per-category table instead.

| Category | Terms kept | Median CER |
| --- | --- | --- |
| Plain Thai | no key terms | **0.00** |
| Acceptance | 5/8, 62% | 0.00 |
| Numbers, dates, times | 12/17, 71% | 0.00 |
| Product and person names | 8/19, 42% | 0.23 |
| Thai + English work terms | 6/29, 21% | 0.33 |
| URLs, emails, code | **0/10, 0%** | **0.67** |

## Three findings

### 1. Pure Thai is flawless

All eight plain Thai sentences came back at a character error rate of 0.00. Not merely good. The handful that are not marked as exact matches differ only in spacing, which the text policy then fixes.

Nothing needs improving here, and any future engine has to match this rather than beat it.

### 2. Thai spoken times work, English ones do not

The six Thai time sentences all converted correctly, including the two where the recognizer wrote the number as digits by itself:

```
ประชุมทีม 10 โมงเช้านะ      ->  ประชุมทีม 10:00 นะ
เจอกันบ่ายสองครึ่งที่ออฟฟิศ  ->  เจอกัน 14:30 ที่ออฟฟิศ
เลิกงาน 6 โมงเย็น           ->  เลิกงาน 18:00
```

The three English time sentences all failed:

```
nine thirty AM  ->  นาย Duty AM
five PM         ->  ไฟล์พีเอ็ม
seven o'clock   ->  เซเว่นโอ co
```

Practical consequence: **say times in Thai.** This is worth telling users, not just recording here.

### 3. URLs, emails, and code do not survive at all

Zero of ten key terms, with a median character error rate of 0.67. The audio is not being turned into anything close to the original.

```
hello@example.com        ->  HELLO side simple.com
config.json แล้ว commit   ->  Conflits djay สุดเหล่า Comin
https://krasip.app/docs  ->  HDTV เอส Colon Flash กระซิบ Flash Dock
npm install              ->  NPR
```

No glossary rule can repair this, because there is nothing recognisable to map from. This is the strongest argument for testing a local Whisper model, which handles code-like strings far better.

## What a glossary recovers

Most work-term failures are the recognizer writing the Thai phonetic spelling of an English word. Those are exactly what the glossary exists for.

Simulated by replaying the recorded transcripts through the text policy with the entries below, rather than estimated: **31/83 becomes 48/83, 37% to 58%.**

```
Thai spellings of English words
  รีวิว -> review          เซิร์ฟเวอร์ -> server      ฟังก์ชัน -> function
  โค้ด -> code             รีสตาร์ท -> restart        สตริง -> string
  ฟีเจอร์ -> feature       ดีไซน์ -> design           ลิงก์ -> link
  ล็อกอิน -> login         โปรดักชั่น -> production   แพลนนิ่ง -> planning
  เจนเนอรอล -> general     ยูนิต -> unit              สายโปรเจกต์ -> side-project

Capitalisation, alias and output are the same lowercase word
  marketing   deadline   meeting   channel   test   sprint   request

Thai names
  พี่แบงค์ -> พี่แบงก์      พี่ใหม่ -> พี่มายด์
```

## What a glossary cannot recover

About 35 term failures remain. Most are unrecoverable because the recognizer heard something unrelated: `Zoom call` became `ศุกร์เขา`, `Claude` became `ซอส`, `merge PR` became `10,000 ผู้ร`.

Two more look fixable and must not be added:

```
bug      heard as พัก      พัก is an ordinary Thai word meaning rest
invoice  heard as voice    voice is an ordinary English word
```

A glossary rule replaces every occurrence, so either entry would corrupt normal sentences. This is the real limit of the glossary: **it can only fix a mishearing that is not itself a word you would otherwise use.**

## Open questions

- **`W01` did not improve** in the simulation even though both `รีวิว` and `โค้ด` are in the entry list. They sit directly beside each other in an unbroken Thai run, `ช่วยรีวิวโค้ดใน`. Two adjacent aliases may not both match. Worth investigating in `GlossaryMatcher`.
- **`C01` is unrecorded**, and it belongs to the category that performs worst. Record it before drawing firm conclusions about URLs and code.
- These numbers are a snapshot. Once the glossary entries above are saved, re-run and expect roughly 58%.

## Reproducing this

1. Menu bar, Benchmark. Select a sentence, press ⌘R, read it, press Stop.
2. Tick the engines to compare and press Run Benchmark. Scores are written to `results.json`, keyed by engine, so earlier runs are kept for comparison.
3. Export CSV for one row per sentence, with the raw transcript, the final text, and the missing and transliterated terms.

Recordings are reusable. Comparing a new engine never needs reading the sentences again, which is what makes the recorded set worth more than any single result in this document.
