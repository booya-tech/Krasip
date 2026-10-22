# Handoff

Krasip is a finished macOS app, built against every criterion in [`KRASIP_MVP_SPEC.md`](KRASIP_MVP_SPEC.md). This page is for someone opening the repo for the first time: how to run it, what to expect on the first try, what was checked by machine, and the short list that needs your hands.

## Run it (5 minutes)

1. Clone the repo and open `Krasip.xcodeproj` in Xcode. There is nothing to configure first.
2. Pick the **Krasip** scheme and **My Mac**, then press **⌘R**.
3. The setup guide opens. Allow **Microphone** and **Accessibility**. On macOS 26 pick **Apple — on this Mac** and download the Thai model once. On macOS 14 or 15 that engine does not exist and the app uses **Apple — online** instead.
4. Click into Notes, hold **⌥ Space**, say *"วันนี้จะต้องกลับบ้านไปทำ side project"*, let go. The text appears at your cursor, with **side-project** spelled that way by the text policy.
5. Want the app itself in Thai? Settings → Languages → **Show Krasip in** → ไทย → **Restart Now**.

Two gotchas. Only one copy of Krasip can own ⌥ Space, so quit an older build before running a new one (`ps aux | grep -i krasip`). And macOS asks for Accessibility again after every build unless you sign with your own certificate; `./scripts/setup-local.sh` sets that up once, see the README.

## What to expect from the recognizer

The first run uses Apple's on-device Thai model, which is the honest default and needs no setup. Measured on real speech in [`BENCHMARK_RESULTS.md`](BENCHMARK_RESULTS.md):

| What you dictate | How it goes |
| --- | --- |
| Plain Thai | Flawless. 0.00 character error rate on all eight test sentences. |
| Numbers, dates, Thai spoken times | Good, 71% of key terms kept. |
| Thai with English work terms | Weak, 21%. English words spoken with a Thai accent come back Thai-spelled. |
| URLs, emails, code | Does not survive at all, 0%. |

The glossary is the lever for the weak row. Teach it the ten or twenty terms you actually say, from Settings → Glossary or from History → "Add Preferred Spelling…".

There is also a stronger local setup, Thonburian Whisper plus a correction model trained here, which Krasip talks to as a local Whisper server. It lives in its own repo, [krasip-correction](https://github.com/booya-tech/krasip-correction), and takes one script plus about 4 GB of downloads. Do the steps above first and dictate with Apple's engine for a day, so you can tell the difference yourself.

## What is done

| Spec area | State |
| --- | --- |
| macOS 14+, Swift 6, SwiftUI, no third-party dependencies | Done |
| Global push-to-talk hotkey (⌥ Space, changeable), plus hands-free quick tap | Done |
| Microphone capture with level meter, cancel, device-change recovery | Done |
| Three speech engines behind one interface: Apple on-device, Apple online, any OpenAI-compatible endpoint (including a local Whisper server) | Done |
| Conservative text policy: Thai↔English spacing, punctuation choice, spoken clock times, nothing else | Done |
| Personal glossary: exact normalized matching, locked and ask-me-first modes, sound-alike suggestions, learning from your corrections | Done |
| Insertion at the cursor through Accessibility, ⌘V paste fallback, clipboard fallback, password fields refused | Done |
| Local SQLite history, corrections, per-app rules, quality stats | Done |
| Overlay, menu bar, Settings (4 tabs), History, Setup guide, Benchmark window | Done |
| Thai and English interface, switchable inside the app | Done |
| Never sends your text to an LLM to be rewritten | Done, by having no such step |

The full requirement-by-requirement table is in [`SPEC_CHECKLIST.md`](SPEC_CHECKLIST.md).

## What was verified without you

- **168 automated tests** pass (⌘U, or `swift test` in `Packages/KrasipKit`), including all five rows of the spec's acceptance table and a 20-run stability check. Each test is explained in plain English in [`../TESTS_EXPLAINED.md`](../TESTS_EXPLAINED.md).
- **Live Thai speech recognition** against the on-device model, driven by generated speech (`KRASIP_LIVE_ASR=1 swift test`, skipped unless you ask for it).
- **A real-voice benchmark** of 55 sentences, scored per category in [`BENCHMARK_RESULTS.md`](BENCHMARK_RESULTS.md).
- **A full overlay simulation** with a fake microphone (`--simulate-dictation`): panel size and position in every phase, auto-dismiss, hands-free tapping, Esc, review-then-insert, and the resulting history and stats. Run in both English and Thai.
- **Every screen rendered to PNG** in both languages (`--render-previews`), which is where the screenshots in the README come from.
- **Debug and Release both build with zero warnings.**

## What needs your hands

A real microphone, real permissions, and other apps. About 15 minutes, in [`MANUAL_TEST_PLAN.md`](MANUAL_TEST_PLAN.md):

1. Dictating with your own voice.
2. Insertion into Notes, Slack, a browser field, a code editor, and Terminal. The one part no test can fake.
3. The password-field refusal and the "Copied — paste with Command+V" fallback.
4. The Thai interface end to end.
5. Recording the benchmark sentences in your own voice, then choosing an engine with your own numbers.

## Honest limits

- The recognizer, not Krasip, decides how English words come out. Expect to teach it 10 to 20 terms in the first week; History → "Make Rule…" exists for exactly that.
- No streaming partial transcripts. The spec asked for recorded-audio requests first.
- Signed for development only. Sending a build to someone outside the team needs a Developer ID certificate and notarization.
- The benchmark ships 56 sentences; the spec's quality plan asks for 200 or more of your own. The Benchmark window can add and import more.

## Where things are

`README.md` has the map of the code, the pipeline, and troubleshooting. [`DESIGN_NOTES.md`](DESIGN_NOTES.md) explains why each part is shaped the way it is, including the trade-offs worth arguing with. `CLAUDE.md` and `AGENTS.md` are the same briefing for coding agents.
