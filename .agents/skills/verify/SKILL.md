---
name: verify
description: Run the full Krasip verification loop - package tests, app build, and the overlay simulation - and report only what failed. Use after changing code, before saying work is done, or when the user asks to verify, check, or test the project.
---

Run these in order. Stop at the first failure, report it, and do not continue.

## 1. Package tests, about one second

```bash
cd Packages/KrasipKit && swift test 2>&1 | grep -E "Test run with|Expectation failed|error:" | tail -8
```

Expect three lines reading "Test run with N tests ... passed", one per target. Any "Expectation failed" line names the suite and the assertion; quote the shortest decisive line rather than dumping output.

## 2. App build

```bash
xcodebuild -project Krasip.xcodeproj -scheme Krasip -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|warning:|BUILD" | grep -v "Metadata extraction" | head -10
```

Expect `** BUILD SUCCEEDED **` and nothing else. The project builds with zero warnings; a new warning is a regression worth reporting.

## 3. Overlay simulation, only when the flow, overlay, or insertion changed

```bash
APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/Krasip-*/Build/Products/Debug/Krasip.app | head -1)
rm -rf /tmp/krasip-verify && "$APP/Contents/MacOS/Krasip" --simulate-dictation /tmp/krasip-verify >/dev/null 2>&1
cat /tmp/krasip-verify/simulation.log
```

Use `ls -t`, never `ls | head -1`, which sorts alphabetically and will hand you a stale build.

Check the log for: a review card in phase 5 at roughly 440 wide, three insertions, and `insertionRate=1.0`. The harness uses fixed sleeps, so one odd run on a loaded machine is not proof of a bug. Re-run before reporting one.

## 4. Thai still renders, only when strings or AppString changed

```bash
APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/Krasip-*/Build/Products/Debug/Krasip.app | head -1)
plutil -p "$APP/Contents/Resources/th.lproj/Localizable.strings" | wc -l
```

A reworded English string orphans its Thai translation silently. If `AppString.swift` changed, confirm each new literal has a catalog key, since the build succeeds either way.

## Reporting

Say plainly what passed and what failed. If a step was skipped because it did not apply, say so. Never claim the app works end to end on the strength of these alone; real microphone input, Accessibility permission, and insertion into other apps are only covered by `docs/MANUAL_TEST_PLAN.md`.
