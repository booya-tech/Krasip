# Handoff — the morning after

Krasip is built, from an empty folder to a running macOS app, against every criterion in [`KRASIP_MVP_SPEC.md`](KRASIP_MVP_SPEC.md). This page says what is finished, what was checked by machine, and the short list that needs your hands.

## Start here (5 minutes)

1. Open `Krasip.xcodeproj` in Xcode, pick the **Krasip** scheme and **My Mac**, press **⌘R**.
   (Or double-click `build/Krasip.app`, which is already built and signed with your Apple Development certificate.)
2. The setup guide opens. Allow **Microphone** and **Accessibility**, then pick a speech engine. On macOS 26 choose **Apple — on this Mac** and download the Thai model once.
3. Click into Notes, hold **⌥ Space**, say *"วันนี้จะต้องกลับบ้านไปทำ side project"*, let go. The text appears at your cursor, with **side-project** spelled your way.
4. Want the app itself in Thai? Settings → Languages → **Show Krasip in** → ไทย → **Restart Now**.

One thing to know before you press ⌘R: the earlier prototype, from before the rename, is still running on this Mac (process 13752, built into a `WispFlow_Clone` derived-data folder). Two copies fight over ⌥ Space, so quit that one from its menu bar icon first.

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

- **160 automated tests** pass (⌘U, or `swift test` in `Packages/KrasipKit`), including all five rows of the spec's acceptance table and a 20-run stability check. Each test is explained in plain English in [`../TESTS_EXPLAINED.md`](../TESTS_EXPLAINED.md).
- **Live Thai speech recognition** on this Mac's on-device model, driven by generated speech (`KRASIP_LIVE_ASR=1 swift test`).
- **A 50-sentence benchmark** run end to end. Plain Thai came back near-perfect; English terms spoken by a robot Thai voice came back Thai-spelled 91% of the time. That is a worst case, not your accuracy — but it is exactly the risk the spec warned about, and the reason the glossary exists. Numbers are in [`SPEC_CHECKLIST.md`](SPEC_CHECKLIST.md#first-benchmark-run-synthetic-voice).
- **A full overlay simulation** with a fake microphone (`--simulate-dictation`): panel size and position in every phase, auto-dismiss, hands-free tapping, Esc, review-then-insert, and the resulting history and stats. Run in both English and Thai.
- **Every screen rendered to PNG** in both languages (`--render-previews`), which is where the screenshots in the README come from.
- **Debug and Release both build with zero warnings** and are signed.

## What needs your hands

A real microphone, real permissions, and other apps. About 15 minutes, in [`MANUAL_TEST_PLAN.md`](MANUAL_TEST_PLAN.md):

1. Dictating with your own voice.
2. Insertion into Notes, Slack, a browser field, a code editor, and Terminal — the one part no test can fake.
3. The password-field refusal and the "Copied — paste with Command+V" fallback.
4. The Thai interface end to end.
5. Recording the benchmark sentences in your own voice, then choosing between the Apple and OpenAI engines with real numbers.

## Honest limits

- The recognizer, not Krasip, decides how English words come out. Expect to teach it 10–20 terms in the first week; the History → "Make Rule…" path exists for exactly that.
- No streaming partial transcripts. The spec asked for recorded-audio requests first.
- Signed for development only. Sharing it with someone else needs a Developer ID certificate and notarization.
- The benchmark ships 56 sentences; the spec's quality plan asks for 200+ of your own. The Benchmark window can add and import more.

## Where things are

`README.md` has the map of the code, the pipeline, and troubleshooting. [`DESIGN_NOTES.md`](DESIGN_NOTES.md) explains why each part is shaped the way it is, including the trade-offs worth arguing with.

Nothing is committed — the working tree is yours to stage.
