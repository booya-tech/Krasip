# Krasip Thai MVP

## Purpose

Build a macOS app that lets a Thai speaker hold a hotkey, speak naturally, and insert clean Thai-English text into the focused app.

Primary success case:

```text
Speech: วันนี้จะต้องกลับบ้านไปทำ side project
Output: วันนี้จะต้องกลับบ้านไปทำ side-project
```

The app must preserve the user's preferred spelling. It must not automatically translate English technical terms into Thai transliterations.

## v1 scope

Included:

- macOS 14+ only
- Global push-to-talk hotkey
- Microphone capture, recording state, stop/cancel
- Thai-English speech recognition
- Conservative cleanup
- Personal glossary with spoken aliases and preferred output
- Insert result at focused cursor; clipboard paste fallback
- Local transcript history and correction action

Excluded:

- iOS, Android, Windows
- Accounts, sync, payments, teams
- Meeting transcription
- Fully automatic grammar rewriting
- Training a speech model

## Product rules

1. Preserve meaning over polish.
2. Preserve Latin-script terms unless the user explicitly requests Thai output.
3. Never send text to an LLM merely to make it sound better in v1.
4. Show the raw transcript before insertion when confidence is low.
5. Save audio only when the user enables it. Text history is local by default.

## User flow

```text
User holds Option+Space
  -> small overlay: Recording
  -> releases key
  -> ASR produces raw transcript
  -> Thai text policy applies glossary + safe formatting
  -> overlay shows final text
  -> app inserts final text at cursor
  -> history stores raw, final, and edits
```

If insertion fails, copy final text to the clipboard and show “Copied — paste with Command+V”.

## Acceptance tests

| Input speech / raw transcript | Expected final text |
| --- | --- |
| วันนี้จะต้องกลับบ้านไปทำ side project | วันนี้จะต้องกลับบ้านไปทำ side-project |
| เดี๋ยว push code ขึ้น GitHub | เดี๋ยว push code ขึ้น GitHub |
| นัดกับพี่แบงก์ตอน ten AM | นัดกับพี่แบงก์ตอน 10 AM |
| ส่ง pull request ให้ทีม | ส่ง pull request ให้ทีม |
| ทำไซต์โปรเจกต์ | ทำ side-project — only if that exact alias exists in glossary |

Do not replace a phrase simply because it sounds similar. A glossary match needs an exact normalized alias or a high-confidence phonetic match confirmed by the user.

## Architecture

The app is a pipeline. Keep each source of platform or vendor change behind a seam.

```text
Hotkey -> Dictation module -> Transcription module -> Text policy module
       -> Insertion module -> History module
```

### Dictation module

**Interface:** `start()`, `stop()`, `cancel()`, and a stream of `DictationState`.

It owns microphone permission, audio buffering, recording timer, and UI state. Callers do not manage audio chunks.

### Transcription module

**Interface:** `transcribe(audio, languages: [.thai, .english]) -> Transcript`.

`Transcript` includes `rawText`, language spans when available, and confidence. Start with one adapter for a chosen ASR provider. Keep the interface so an on-device or cloud adapter can later replace it.

### Text policy module

**Interface:** `finalize(rawText, glossary, style) -> FinalText`.

This is the product's deep module. Its implementation handles Thai spacing, punctuation, glossary lookup, protected spans, and an explainable change list.

Rules:

- Normalize Unicode and repeated whitespace.
- Keep Thai characters exactly as transcribed unless a deterministic spacing rule applies.
- Mark existing Latin tokens, URLs, code fragments, numbers, and glossary outputs as protected.
- Replace a recognized alias only with its saved preferred output.
- Do not translate, summarize, rewrite tone, or invent words.
- Return every change, e.g. `side project -> side-project (glossary)`.

### Glossary module

**Interface:** `resolve(text) -> [Replacement]` and `learn(raw, corrected) -> Suggestion`.

Each entry:

```json
{
  "id": "uuid",
  "aliases": ["side project", "ไซต์โปรเจกต์", "ไซด์โปรเจกต์"],
  "preferredOutput": "side-project",
  "mode": "locked",
  "createdAt": "ISO-8601"
}
```

Modes: `locked` always uses preferred output; `suggest` asks before replacement; `disabled` retains history but makes no replacement.

### Insertion module

**Interface:** `insert(text) -> InsertionResult`.

Use macOS Accessibility permissions to target the focused editable field. Never inject into password fields. Use clipboard fallback if the focused app blocks insertion.

### History module

**Interface:** `record(raw, final, destinationApp)`, `recent()`, `applyCorrection(id, finalText)`.

Store locally in SQLite. Audio is excluded unless the user turns on “Keep audio for retry”.

## Data model

```text
GlossaryEntry(id, aliases, preferredOutput, mode, createdAt, updatedAt)
Dictation(id, startedAt, rawText, finalText, destinationBundleID, confidence)
Correction(id, dictationID, beforeText, afterText, acceptedSuggestion)
AppStyle(bundleID, punctuationMode, autoInsert)
```

## Implementation stack

- Swift 6, SwiftUI, macOS 14+
- AVFoundation for microphone audio
- Accessibility APIs for focused-field insertion
- SQLite via SwiftData or GRDB for local data
- An ASR adapter selected after Thai-English benchmark testing

Start with a simple recorded-audio transcription request. Add streaming partial transcripts only after the end-to-end flow is accurate.

## Build sequence

### Milestone 0 — learn + spike

- Create a SwiftUI macOS app with one Record button.
- Request microphone permission.
- Record a `.m4a` file locally.
- Display a fake transcript.

Done when: you understand app lifecycle, state, permissions, and can record/stop reliably.

### Milestone 1 — transcription

- Implement `TranscriptionModule` with one ASR adapter.
- Add Thai + English language configuration.
- Display raw transcript; do not alter it.
- Build a 50-sentence Thai-English test set.

Done when: all 50 samples are recorded and results can be compared.

### Milestone 2 — glossary

- Store glossary entries locally.
- Implement exact normalized alias matching.
- Build “Add preferred spelling” from a selected transcript span.
- Apply locked terms before any formatting.

Done when: the primary success case always outputs `side-project` after one glossary entry.

### Milestone 3 — universal use

- Implement global push-to-talk hotkey.
- Add floating recording/result overlay.
- Implement Accessibility insertion and clipboard fallback.
- Block password and secure fields.

Done when: dictation inserts in Notes, Slack, a browser text field, and an editor.

### Milestone 4 — correction learning

- Let user edit final text in the overlay/history.
- Detect a repeated correction and offer to create a glossary entry.
- Add change explanations and undo.

Done when: a correction can become a vocabulary rule without developer work.

## Thai-specific quality plan

Create a private benchmark of at least 200 utterances, balanced across:

- plain Thai
- Thai + English work terms
- product and person names
- numbers, dates, times, currency
- URLs, email addresses, code symbols
- quiet/noisy audio and different accents

Track:

- **Term preservation rate:** preferred terms output exactly.
- **Unwanted transliteration rate:** English terms rendered in Thai unexpectedly.
- **Correction rate:** user edits / dictated words.
- **Latency:** hotkey release to inserted text.
- **Insertion success rate:** successful focused-field insertion / attempts.

Do not optimize a model using only word error rate. A single changed `GitHub`, name, URL, or code token can make an otherwise good transcript unusable.

## First UI

```text
┌────────────────────────────────────┐
│  ● Listening…                      │
│  วันนี้จะต้องกลับบ้านไปทำ          │
│  side-project                      │
│                         Esc Cancel │
└────────────────────────────────────┘
```

Settings only needs four tabs: General, Languages, Glossary, Privacy.

## Risks and choices

| Risk | v1 choice |
| --- | --- |
| ASR changes English to Thai phonetics | glossary + protected output; test providers on benchmark |
| LLM damages Thai/English mix | no generative rewrite in v1 |
| Accessibility insertion blocked | clipboard fallback |
| Sensitive text/audio | local history; audio opt-in; never record password fields |
| Model/provider lock-in | one small transcription interface |

## Definition of v1 done

- A non-technical Thai user can install, grant permissions, and dictate with one hotkey.
- The four acceptance tests pass consistently.
- A correction can be promoted into a locked glossary term.
- The app never changes a protected term without a saved rule.
- Failure to insert never loses the final text.
