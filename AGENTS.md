# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

Krasip is a macOS push-to-talk dictation app for Thai mixed with English. Hold ⌥ Space, speak, release, and cleaned-up text is inserted where the cursor is.

## Setup

`Config/Local.xcconfig` holds your Apple team ID and is gitignored. Without it the app will not sign:

```
DEVELOPMENT_TEAM = YOURTEAMID
```

`Config/Base.xcconfig` ends with `#include? "Local.xcconfig"`, so the local file overrides the empty default.

## Commands

```bash
# tests, about one second, 164 of them
cd Packages/KrasipKit && swift test
swift test --filter TextPolicyTests          # one suite

# live speech tests, needs macOS 26 and the Thai model, skipped otherwise
KRASIP_LIVE_ASR=1 swift test

# app
xcodebuild -project Krasip.xcodeproj -scheme Krasip -configuration Debug -destination 'platform=macOS' build
./scripts/build-release.sh                   # signed app into ./build

# ⌘U in Xcode runs all three package test targets through Krasip.xctestplan
```

Two debug-only entry points, both `#if DEBUG`, in `Krasip/Core/Utilities/`:

```bash
APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/Krasip-*/Build/Products/Debug/Krasip.app | head -1)

# render every screen to PNG with throwaway sample data
"$APP/Contents/MacOS/Krasip" --render-previews /tmp/shots

# run real dictations with a fake microphone, then write simulation.log plus PNGs
"$APP/Contents/MacOS/Krasip" --simulate-dictation /tmp/sim

# add -AppleLanguages '(th)' to either to see the Thai interface
```

The simulation is how the overlay gets verified without a microphone. It checks panel size and position per phase, auto-dismiss, hands-free tapping, Esc, and the resulting history.

## Architecture

```
Hotkey -> Dictation -> Transcription -> Text policy (+ Glossary) -> Insertion -> History
```

A Swift package with three modules, plus a thin SwiftUI app:

| Module | Depends on | Holds |
| --- | --- | --- |
| `KrasipCore` | Foundation only | Text policy, glossary, learning, the flow, benchmark metrics |
| `KrasipStorage` | Core, SQLite3 | The only place that knows SQL |
| `KrasipSystem` | Core, macOS frameworks | Microphone, speech engines, Accessibility, hot keys, Keychain |
| `Krasip` (app) | all three | SwiftUI views and the wiring in `AppController` |

`KrasipCore` has no AppKit and no microphone, which is why its 119 tests run in 0.1 seconds. Keep it that way. Anything touching a macOS framework belongs in `KrasipSystem`.

`DictationFlow` is the only type that knows the order of the steps. It takes every dependency as a closure, so tests swap the microphone, recognizer, inserter, clock, and `sleep`. Add a new step there, not in the views.

### Decisions worth knowing before changing things

- **The text policy works on `[TextSegment]`, not on one `String`.** Each piece remembers where it came from and whether it is protected. "Never change a protected term" is enforced structurally, not by hoping regexes do not overlap. Every change is logged and can be undone.
- **No LLM rewriting anywhere.** The transcript is never sent somewhere to be improved. The cloud adapter sends audio plus glossary spelling hints only. This is a product rule, not an implementation detail.
- **Glossary matching is exact on a normalized form.** Sound-alike matches are only ever suggestions, applied after the user taps Use.
- **Carbon hot keys**, because `RegisterEventHotKey` is the only API that reports key-up without extra permissions and swallows the keystroke.
- **Insertion is Accessibility first, paste second**, with the clipboard restored afterwards, and secure fields refused outright. See the ladder in `TextInserter.swift`.
- **SQLite directly through `SQLite3`**, not SwiftData or GRDB. No third-party dependencies anywhere in this project.

`docs/DESIGN_NOTES.md` has the longer reasoning and the trade-offs.

## Project layout

```
Krasip/                    the app
  App/                     entry point, AppDelegate, AppController (composition root)
  Core/                    settings, observable models, services, design system, AppString
  Features/                Overlay, MenuBar, Settings, History, Onboarding, Benchmark
Packages/KrasipKit/        the three modules and all tests
Config/                    Base.xcconfig, entitlements, extra Info.plist keys
docs/                      spec, checklist, design notes, manual test plan, benchmark results
```

**The Xcode project uses synchronized folders.** Add a file on disk and it joins the target automatically. Do not hand-edit `project.pbxproj` to register files.

## Text and localisation

**Every user-facing string lives in `Krasip/Core/Utilities/AppString.swift`.** Views never contain English sentences. Each string goes through `String(localized:)` into `Krasip/Resources/Localizable.xcstrings`, which ships English and Thai.

The English sentence **is** the lookup key. Reword a string and its Thai translation is orphaned. The build still succeeds and the UI falls back to English silently, so nothing warns you. When you change wording, update the key and its Thai value in the same pass, then confirm with `--render-previews -AppleLanguages '(th)'`.

Error types in the package carry their own catalogs and use `String(localized:..., bundle: .module)`.

## Testing

Swift Testing, not XCTest. `@Test` and `#expect`.

- `KrasipCoreTests` (117) is the one that matters. Pure logic, no mocks of the OS.
- `AcceptanceTests.swift` holds the spec's acceptance table. Treat failures there as blocking.
- `BenchmarkTests.swift` checks the bundled sentence set stays consistent with the policy.
- Live speech tests are gated behind `KRASIP_LIVE_ASR=1` and skipped by default.

Every test is explained in plain English in `TESTS_EXPLAINED.md`. Update it when you add a suite.

**For a refactor, tests passing is weak evidence.** The suite covers the cases somebody thought of. When the claim is "behaviour is unchanged", generate a corpus, run it through the old and new code, and diff the output. That technique caught a real behaviour change that 160 passing tests missed.

What automated tests cannot reach: real microphone input, Accessibility permission, and insertion into other apps. That is `docs/MANUAL_TEST_PLAN.md`, about 15 minutes by hand.

## Gotchas

- **Two running copies fight over ⌥ Space.** Quit any older build before running a new one. Check with `ps aux | grep -i krasip`.
- **`ls ~/Library/Developer/Xcode/DerivedData/Krasip-*/...` sorts alphabetically, not by time.** Use `ls -t`, or you will inspect a stale build and report a false result.
- **`grep` on this machine is `ugrep` and skips gitignored files.** Use `git grep` when the question is "is this in the repo".
- **Changing the bundle ID resets the Accessibility permission, the app settings, and the Keychain entry.** User data survives, because it lives in `~/Library/Application Support/Krasip/` under a literal folder name.
- The app is a menu bar accessory, `LSUIElement`, so there is no Dock icon until a window opens.
- No App Sandbox, deliberately. Typing into other apps needs the Accessibility API, which the sandbox blocks.

## Speech engines

Three adapters behind one `Transcriber` protocol: Apple on-device (current default), Apple online, and any OpenAI-compatible `/audio/transcriptions` endpoint. A `localhost` endpoint is treated as a local server and needs no API key.

Measured accuracy on real speech is in `docs/BENCHMARK_RESULTS.md`. Short version: plain Thai is flawless, English work terms need the glossary, and URLs and code do not survive at all. Do not add a fourth engine type before the numbers justify it.
