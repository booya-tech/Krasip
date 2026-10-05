# Design notes

Why the code looks the way it does. Short, plain, and honest about trade-offs.

## The shape of the app

The spec asks for a pipeline with seams:

```text
Hotkey → Dictation → Transcription → Text policy (+ Glossary) → Insertion → History
```

So the code is split into a Swift package with three modules and a thin app on top:

| Module | Depends on | Why it is separate |
| --- | --- | --- |
| `KrasipCore` | Foundation only | All the thinking: text policy, glossary, learning, the flow. No AppKit, no microphone, no network — which is why 113 tests run in 0.1 s. |
| `KrasipStorage` | Core + SQLite | One place that knows SQL. |
| `KrasipSystem` | Core + macOS frameworks | Everything that can break on a new macOS: microphone, speech engines, Accessibility, hot keys, Keychain. |
| `Krasip` (app) | all three | SwiftUI views and the wiring (`AppController`). |

`DictationFlow` is the only place that knows the order of the steps. It receives every dependency as a closure, so tests replace the microphone, the recognizer, the inserter, the clock, and even `sleep`. That is how paths like "insertion failed", "password field", and "the user pressed Esc while transcribing" are covered without a Mac in the loop.

## Choices worth knowing

**SQLite directly, not SwiftData or GRDB.** The spec allows either. A 200-line wrapper over the built-in `SQLite3` library gives exactly what the spec asks for — a local file, schema versions, and fast in-memory databases for tests — with no third-party dependency and no SwiftData surprises on macOS 14.

**Carbon hot keys for push-to-talk.** `RegisterEventHotKey` is the only API that reports **key up** as well as key down without asking for extra permissions, and it swallows the keystroke so ⌥ Space does not also type a space. Esc and Return are registered only while the overlay needs them, so other apps keep those keys the rest of the time.

**Insertion: Accessibility first, paste second.** Setting `AXSelectedText` types straight into native fields and keeps the user's clipboard untouched, but web pages and Electron apps often accept it and do nothing. So Krasip checks that the text actually landed (character count, then the inserted range) and falls back to a ⌘V paste with the clipboard restored afterwards. Apps that reject both get the spec's "Copied — paste with Command+V". The ⌘V key code is looked up in the current ASCII-capable layout, because a Thai keyboard layout moves "v".

**The text policy works on segments, not on one string.** Each rule splits the text into pieces that remember where they came from (transcript, glossary output, converted time, inserted space) and whether they are protected. That is how "never change a protected term" is enforced structurally rather than by hoping the regexes do not overlap, and how every change can be listed and undone.

**Matching Thai needs Thai rules.** Alias matching folds case, full-width letters, dash variants, and decomposed sara am, and ignores the stray spaces recognizers sprinkle into Thai. It refuses to match across a grapheme boundary, after a leading vowel (เ แ โ ใ ไ), or before a following vowel (ะ า ำ) — otherwise a two-letter alias would cut syllables in half.

**Sound-alike suggestions, never sound-alike replacements.** Recognizers spell the same English loanword several ways (ไซต์โปรเจกต์ / ไซด์โปรเจ็กต์). A rough "sound key" folds tone marks, silent letters, and consonants that sound the same, so those spellings compare equal. The spec allows this only as "a high-confidence phonetic match confirmed by the user", so a sound-alike is only ever a suggestion; accepting one saves that spelling as a real alias, and the next time it is an exact match.

**Spoken times are the one built-in rewrite.** The acceptance table requires `ten AM` → `10 AM`, so English clock times with an explicit AM/PM/o'clock marker become digits. Nothing else is converted — "two cats" and Thai number words are left alone — and the rule can be switched off.

**Silence is never sent to a recognizer.** Whisper-family models invent text from silence ("ขอบคุณครับ"), so a recording with less than ~0.15 s of voiced audio becomes "Didn't catch that".

**One place holds every word the user reads.** `AppString` is the only source of interface text, and each string goes through `String(localized:)` into `Localizable.xcstrings`. That is what made a full Thai interface a translation pass instead of a rewrite, and it keeps the views free of English sentences. The three error types in the package carry their own catalogs (`bundle: .module`), because an error message is text the user reads too.

**Thai interface, chosen inside the app.** macOS picks an app's language from the system language, but many Thai developers keep macOS in English. Settings → Languages has its own picker that writes `AppleLanguages` into Krasip's own preferences, with a Restart Now button. The restart launches a fresh copy one second after this one quits, so the two copies never fight over the ⌥ Space hot key.

**No LLM rewriting anywhere.** The cloud adapter sends audio plus a short spelling hint (your glossary terms). The transcript is never sent anywhere to be polished. That is product rule 3, and it is also why every change Krasip makes can be explained in one line.

## What the numbers said on the first night

The 50-sentence benchmark, spoken by the macOS Thai voice "Kanya" and recognized by Apple's on-device Thai model:

| Metric | Result |
| --- | --- |
| Plain Thai sentences | essentially perfect |
| Term preservation (English terms, names, numbers) | 14% |
| English terms that came back in Thai letters | 91% |
| Median latency per clip | 0.15 s |

A robot voice reading English with a Thai accent is the worst case, but the direction is the spec's warning made visible: **the recognizer is not the product; the glossary and the text policy are.** Record the benchmark in your own voice before choosing an engine.

## Known limits (today)

- Only Thai and English interface languages ship. Everything the user reads is in a String Catalog, so another language is a translation job, not a code change.
- No streaming partial transcripts: the spec asks for recorded-audio requests first.
- The app is signed for development. A download for other people needs a Developer ID certificate and notarization.
- Undo after an Accessibility insertion depends on the app: pasted text always undoes with ⌘Z, directly-set text usually does.
- The benchmark ships 56 sentences; the spec's quality plan asks for 200+ of your own (the Benchmark window can add and import more).
