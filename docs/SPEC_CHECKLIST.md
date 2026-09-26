# Spec checklist

How each requirement in [`KRASIP_MVP_SPEC.md`](KRASIP_MVP_SPEC.md) is covered.

Legend: **Test** = checked by an automated test · **Built** = implemented, check by hand · **You** = needs your hands (microphone, other apps) · **Note** = a choice worth knowing about.

## v1 scope

| Requirement | Status | Where |
| --- | --- | --- |
| macOS 14+ only | Built | Deployment target 14.0 (`Config/Base.xcconfig`). Newer APIs sit behind `#available`. |
| Global push-to-talk hotkey | Built · You | `HotkeyCenter` (Carbon hot keys: press + release, no permission needed). ⌥ Space by default, changeable in Settings → General. |
| Microphone capture, recording state, stop/cancel | Test · You | `MicrophoneRecorder`; flow cancel paths in `DictationFlowTests`. |
| Thai-English speech recognition | Test · You | Apple on-device (live test `OnDeviceRecognitionTests`), Apple online, OpenAI-compatible cloud. |
| Conservative cleanup | Test | `TextPolicyTests`, `AcceptanceTests`. |
| Personal glossary (aliases → preferred output) | Test | `GlossaryMatcherTests`, `GlossaryRepositoryTests`, Settings → Glossary. |
| Insert at cursor; clipboard paste fallback | Built · You | `TextInserter`; fallback message tested in the flow. |
| Local transcript history and correction action | Test | `HistoryStoreTests`, History window. |
| Excluded items (iOS, accounts, sync, meetings, LLM rewriting, training) | Built | None of these exist. |

## Product rules

| Rule | Status | Where |
| --- | --- | --- |
| 1. Preserve meaning over polish | Test | The policy only normalizes spacing, applies your rules, converts spoken clock times, and applies your punctuation choice. |
| 2. Preserve Latin-script terms unless you ask for Thai | Test | English words are protected spans (`englishIsNeverTransliteratedOrChangedWithoutARule`). Only your own glossary rules change them. |
| 3. Never send text to an LLM to sound better | Built | No rewriting step exists. The cloud adapter sends audio and spelling hints only (`OpenAIRequestTests`). |
| 4. Show the raw transcript when confidence is low | Test | Review card shows "Heard: …" (`lowConfidenceShowsRawTranscriptForReview`). Threshold in Settings → General. |
| 5. Audio only when enabled; text history local | Test | "Keep audio for retry" is off by default; history is SQLite on this Mac (`historyCanBeTurnedOff`). |

## User flow

| Step | Status | Where |
| --- | --- | --- |
| Hold ⌥ Space → overlay "Recording" | Built · You | `ListeningCard` ("● Listening…", level meter, timer, "esc Cancel"). |
| Release → raw transcript → policy → final text | Test | `holdSpeakReleaseInsertsFinalTextAndRecordsHistory`. |
| Overlay shows final text, then inserts | Built · You | `ResultCard` / `ReviewCard`. |
| History stores raw, final, and edits | Test | `HistoryStoreTests.correctionUpdatesFinalTextAndKeepsBefore`. |
| Failed insertion → clipboard + "Copied — paste with Command+V" | Test · You | Exact text in `AppString.Overlay.copiedFallback`; `insertionFailureStillKeepsTheText`. |

## Acceptance tests

All five rows of the spec table are automated in `Tests/KrasipCoreTests/AcceptanceTests.swift`, plus a 20-run stability check and a "sounds similar is not replaced" case.

| Raw transcript | Expected | Status |
| --- | --- | --- |
| วันนี้จะต้องกลับบ้านไปทำ side project | วันนี้จะต้องกลับบ้านไปทำ side-project | Test |
| เดี๋ยว push code ขึ้น GitHub | unchanged | Test |
| นัดกับพี่แบงก์ตอน ten AM | นัดกับพี่แบงก์ตอน 10 AM | Test |
| ส่ง pull request ให้ทีม | unchanged | Test |
| ทำไซต์โปรเจกต์ | ทำ side-project only with the alias saved | Test (both with and without the entry) |

"A glossary match needs an exact normalized alias or a high-confidence phonetic match confirmed by the user": exact matching in `GlossaryMatcher`; sound-alike matches (`SoundAlikeMatcher`) are only ever suggestions and are applied only after you tap **Use** (`SoundAlikeTests`).

## Architecture

| Module | Spec interface | Status |
| --- | --- | --- |
| Dictation | `start()`, `stop()`, `cancel()`, stream of `DictationState` | Built (`DictationRecording` protocol, `MicrophoneRecorder`) |
| Transcription | `transcribe(audio, languages) -> Transcript` with raw text, language spans, confidence | Built · Test (`Transcriber`, three adapters; spans come from script when the provider has none) |
| Text policy | `finalize(rawText, glossary, style) -> FinalText` with Thai spacing, punctuation, glossary, protected spans, change list | Test |
| Glossary | `resolve(text) -> [Replacement]`, `learn(raw, corrected) -> Suggestion`; JSON shape; modes locked/suggest/disabled | Test (`GlossaryJSONTests`, `LearnerTests`) |
| Insertion | `insert(text) -> InsertionResult`; Accessibility; never password fields; clipboard fallback | Built · You |
| History | `record(raw, final, destinationApp)`, `recent()`, `applyCorrection(id, finalText)`; SQLite; audio opt-in | Test (`specRecordSignatureWorks` and others) |

## Data model

| Spec | Code |
| --- | --- |
| GlossaryEntry(id, aliases, preferredOutput, mode, createdAt, updatedAt) | `GlossaryEntry` |
| Dictation(id, startedAt, rawText, finalText, destinationBundleID, confidence) | `DictationRecord` (adds policy text, latency, insertion result, changes, audio path) |
| Correction(id, dictationID, beforeText, afterText, acceptedSuggestion) | `Correction` |
| AppStyle(bundleID, punctuationMode, autoInsert) | `AppStyle` (Settings → General → Per-app rules) |

## Implementation stack

| Spec | Status |
| --- | --- |
| Swift 6, SwiftUI, macOS 14+ | Built (Swift 6 language mode, strict concurrency, no warnings) |
| AVFoundation for microphone audio | Built |
| Accessibility APIs for focused-field insertion | Built |
| SQLite via SwiftData or GRDB | **Note:** SQLite through the built-in `SQLite3` library instead — same storage, no third-party dependency, easy to test in memory. |
| ASR adapter chosen after Thai-English benchmark | Built · You (Benchmark window; see results below) |
| Recorded-audio requests first, streaming later | Built (no streaming yet, as the spec asks) |

## Build sequence

| Milestone | Status |
| --- | --- |
| 0 — app, mic permission, record `.m4a`, fake transcript | Built (`FixtureTranscriber` is the fake transcript; kept audio and benchmark clips are `.m4a`) |
| 1 — one ASR adapter, Thai + English config, raw transcript shown unaltered, 50-sentence set | Built · You (record the 50 sentences in the Benchmark window) |
| 2 — local glossary, exact normalized matching, "Add preferred spelling" from a selected span, locked terms before formatting | Test · Built |
| 3 — hotkey, overlay, Accessibility insertion + fallback, block secure fields | Built · Test (a debug simulation drives the real overlay end to end: sizing, position, auto-dismiss, hands-free, Esc) · **You: try Notes, Slack, a browser field, and an editor** ([manual plan](MANUAL_TEST_PLAN.md)) |
| 4 — edit in overlay/history, repeated-correction offer, change explanations and undo | Test · Built |

## Thai quality plan

| Metric | Where it is measured |
| --- | --- |
| Term preservation rate | Benchmark window (`BenchmarkScore.preservedTerms`) |
| Unwanted transliteration rate | Benchmark window (`BenchmarkScore.transliteratedTerms`) |
| Correction rate | History → stats bar (edited words ÷ dictated words) |
| Latency (release → inserted) | History → stats bar (median) and Benchmark |
| Insertion success rate | History → stats bar |

The shipped set has 50 sentences across all six categories. The Benchmark window can **Add Sentence…** and **Import Sentences…**, so you can grow it toward the spec's 200-utterance plan (and record some in noisy places, as the plan asks).

### First benchmark run (synthetic voice)

Run tonight with `KRASIP_LIVE_ASR=1 swift test --filter BenchmarkLiveTests` — Apple's on-device Thai engine, sentences spoken by the macOS Thai voice "Kanya":

| Metric | Result |
| --- | --- |
| Plain Thai sentences | near-perfect (only spacing differs) |
| Term preservation | 14% |
| Unwanted transliteration | 91% of English terms came back Thai-spelled |
| Mean character error rate | 39% |
| Median latency | 0.15 s per clip |

The robot voice reads English with a heavy Thai accent, so this is a worst case, not your real accuracy. It does confirm the spec's biggest risk ("ASR changes English to Thai phonetics"), and why the glossary, sound-alike suggestions, and the benchmark matter. Record your own voice to decide between the Apple and OpenAI engines.

## First UI and Settings

| Requirement | Status |
| --- | --- |
| Overlay: "● Listening…", text, "Esc Cancel" | Built |
| Settings has four tabs: General, Languages, Glossary, Privacy | Built |

## Definition of v1 done

| Item | Status |
| --- | --- |
| A non-technical Thai user can install, grant permissions, and dictate with one hotkey | Built · You. The whole interface is translated into Thai, and Settings → Languages can show Krasip in Thai even when macOS is in English. The setup guide covers permissions and engine choice. **Note:** a signed, notarized download needs your Developer ID certificate; for now, run from Xcode. |
| The four acceptance tests pass consistently | Test |
| A correction can be promoted into a locked glossary term | Test · Built (overlay "Add to Glossary", History "Make Rule…") |
| The app never changes a protected term without a saved rule | Test. **Note:** spoken-time conversion (`ten AM` → `10 AM`) is required by the acceptance table; it is a setting you can turn off. |
| Failure to insert never loses the final text | Test (clipboard fallback, overlay, and History; cancelled reviews are saved too) |
