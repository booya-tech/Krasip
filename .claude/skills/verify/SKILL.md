---
name: verify
description: Run the full Krasip verification loop - package tests, app build, and the overlay simulation - and report only what failed. Use after changing code, before saying work is done, or when the user asks to verify, check, or test the project.
---

Run these in order. Stop at the first failure, report it, and do not continue.

## 1. Package tests, about one second

```bash
(cd Packages/KrasipKit && swift test 2>&1 | grep -E "Test run with|Expectation failed|error:" | tail -8)
```

The subshell matters. A bare `cd` leaves the shell inside the package, and step 2 then fails with `'Krasip.xcodeproj' does not exist`.

Expect three lines reading "Test run with N tests ... passed", one per target. Any "Expectation failed" line names the suite and the assertion; quote the shortest decisive line rather than dumping output.

## 2. App build

```bash
xcodebuild -project Krasip.xcodeproj -scheme Krasip -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "error:|warning:|BUILD" | grep -v "Metadata extraction" | head -10
```

Expect `** BUILD SUCCEEDED **` and nothing else. The project builds with zero warnings; a new warning is a regression worth reporting.

## 3. Find the build you just made

Ask Xcode where it put the app. Do not go looking in `DerivedData` yourself.

```bash
APP_DIR=$(xcodebuild -project Krasip.xcodeproj -scheme Krasip -configuration Debug \
  -destination 'platform=macOS' -showBuildSettings 2>/dev/null \
  | sed -n 's/^ *BUILT_PRODUCTS_DIR = //p' | head -1)
APP="$APP_DIR/Krasip.app"
ls -l "$APP/Contents/MacOS/Krasip"
```

Check that timestamp is from the build you just ran. If it is older, something else is wrong and nothing below it means anything.

Neither `ls` nor `ls -t` over `DerivedData/Krasip-*` is safe. Xcode keeps several project folders, their own timestamps do not move when a build writes inside them, and the newest-looking one can hold an app weeks old. On 2026-11-03 that handed a two-day-old binary to a run that then reported a working feature as missing.

## 4. Overlay simulation, only when the flow, overlay, or insertion changed

```bash
rm -rf /tmp/krasip-verify && "$APP/Contents/MacOS/Krasip" --simulate-dictation /tmp/krasip-verify >/dev/null 2>&1
cat /tmp/krasip-verify/simulation.log
```

Check the log for: a review card in phase 5 at roughly 440 wide, three insertions, and `insertionRate=1.0`. The harness uses fixed sleeps, so one odd run on a loaded machine is not proof of a bug. Re-run before reporting one.

## 5. Thai still renders, only when strings or AppString changed

Uses `$APP` from step 3.

```bash
plutil -p "$APP/Contents/Resources/th.lproj/Localizable.strings" | wc -l
```

A reworded English string orphans its Thai translation silently. If `AppString.swift` changed, confirm each new literal has a catalog key, since the build succeeds either way. Grep the built catalog for a Thai value you added, rather than trusting the count:

```bash
plutil -p "$APP/Contents/Resources/th.lproj/Localizable.strings" | grep -c "<a Thai string you added>"
```

For a new screen, render it and look at it, in both languages:

```bash
"$APP/Contents/MacOS/Krasip" --render-previews /tmp/krasip-shots
"$APP/Contents/MacOS/Krasip" --render-previews /tmp/krasip-shots-th -AppleLanguages '(th)'
```

`PreviewRenderer.snapshot` writes nothing at all when it cannot measure a view, with no error. If an expected PNG is missing, pass that screen an explicit `size:` rather than `nil`.

## Reporting

Say plainly what passed and what failed. If a step was skipped because it did not apply, say so. Never claim the app works end to end on the strength of these alone; real microphone input, Accessibility permission, and insertion into other apps are only covered by `docs/MANUAL_TEST_PLAN.md`.
