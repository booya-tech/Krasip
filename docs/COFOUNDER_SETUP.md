# Setting up Krasip

Hold **⌥ Space**, speak Thai and English the way you normally do, let go, and clean text appears
where your cursor is. This is the whole setup, start to finish. Budget about 30 minutes, most of it
waiting on a 1.7 GB download.

You end up with two things running:

1. **Krasip**, a menu bar app. No Dock icon.
2. **A speech stack on your own Mac**, started from a Terminal window you leave open. Nothing you
   say is sent anywhere.

---

## Before you start

| What | Why |
| --- | --- |
| Apple Silicon Mac | The correction model runs on MLX, which has no Intel version. |
| macOS 14 or newer | macOS 26 also unlocks Apple's on-device Thai engine as a fallback. |
| 16 GB memory or more | The two models need about 5 GB while running. |
| About 4 GB free disk | Mostly the speech model. |
| Access to `booya-tech/krasip-correction` | It is private, and the setup script downloads the models through your GitHub account. Ask Boo. The app repo is public, so it needs no invite. |

Install the command line pieces, if you do not have them:

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install gh
gh auth login
```

You need `gh auth login` to finish, because `krasip-correction` is private and the setup script
downloads the models through your GitHub account.

---

## Step 1. The app

1. Open the latest release: https://github.com/booya-tech/Krasip/releases
2. Download `Krasip-1.0.0.zip` and double-click it.
3. Drag **Krasip** into your **Applications** folder.
4. Open it. It is signed and notarized by Apple, so it opens normally. No right-click trick.

Krasip appears in the menu bar as a waveform icon, and a setup guide opens.

Grant the two permissions it asks for:

- **Microphone.** Krasip listens only while you hold the shortcut.
- **Accessibility.** This is how text gets typed into other apps. macOS will not let anything type
  for you without it.

If you miss the prompt, both live in **System Settings**, under **Privacy & Security**.

---

## Step 2. The speech stack

```bash
git clone https://github.com/booya-tech/krasip-correction.git
cd krasip-correction
./scripts/setup.sh
```

The script checks your Mac first and stops with a clear message if something is missing. Then it
installs `whisper.cpp`, downloads the speech model (1.7 GB) and the correction model (28 MB),
creates a Python environment, and builds the text-policy binary.

It checks the SHA-256 of both downloads. A download that stops halfway leaves a file that looks
finished, so if a checksum does not match, the script stops rather than letting you run a broken
model. Run it again and it picks up where it left off.

Then start it:

```bash
./scripts/start.sh
```

Leave that Terminal window open. It prints the model it loaded:

```
speech model: ggml-thonburian-large-v3-q8_0.bin (port 8081). Loading the correction model, about 20 seconds...
relay ready on http://127.0.0.1:8085/v1  (speech: ..., model: run9s1)
```

**Check that it says `run9s1`.** Starting from the wrong folder once ran an old model for days
before anyone noticed.

Stop it with **Ctrl+C**, which stops both halves.

---

## Step 3. Point Krasip at it

In Krasip, open **Settings** from the menu bar icon, then **Languages**.

| Field | Value |
| --- | --- |
| Engine | OpenAI |
| Endpoint | `http://127.0.0.1:8085/v1` |
| Model | `thonburian-8bit` |
| API key | leave empty |

Krasip treats a `127.0.0.1` endpoint as a local server, so it does not ask for a key and no audio
leaves your Mac.

---

## Step 4. Try it

Open Notes. Click into the note so the cursor is blinking. Hold **⌥ Space**, say something in
Thai, and let go.

| Action | How |
| --- | --- |
| Dictate | Hold ⌥ Space, speak, let go |
| Long dictation, hands free | Quick-tap ⌥ Space, speak, tap ⌥ Space again |
| Cancel | Esc while it is listening |
| Check the text before it goes in | Settings, General, "Let me check it first" |
| See past dictations | Menu bar, History… |

---

## Telling us when it gets something wrong

This is the point of you testing it, so please do it often. Even one-line reports help.

1. Menu bar, **History…**
2. Click the dictation that came out wrong.
3. Click **Report a Miss…** in the toolbar.
4. Type what it **should** have said, pick what went wrong, and click **Open the Report**.

Your browser opens a GitHub issue already filled in with what the engine returned, what the text
rules made of it, the app you were in, and the numbers. Read it and click **Submit**.

The one field Krasip cannot fill is **what you actually said out loud**, so type that yourself.

Pick **Not sure** freely. Sorting misses into categories is not your job.

If the problem is not about the words at all, for example the text landed in the wrong window or
the shortcut did not fire, pick **Something else**. That files a bug against the app instead, in a
different list.

**One thing to know:** those issues will contain your real dictated speech. Both kinds are filed on
`krasip-correction`, which is private, so only the two of you can read them. Nothing you say lands
in the public app repo. Say so now if that is not comfortable.

---

## When something goes wrong

**Nothing happens when I press ⌥ Space.**
Two copies of Krasip fight over the shortcut. Check with `ps aux | grep -i krasip` and quit the
older one. Also confirm Accessibility is still granted in System Settings.

**"Could not reach the speech engine."**
The Terminal window running `./scripts/start.sh` has closed or crashed. Start it again. It takes
about 20 seconds to load the correction model before it answers anything.

**It types Thai letters for English work words.**
That is the glossary's job. Open **Settings, Glossary** and add the word, or fix the text in
History and let Krasip offer to remember it after the second time.

**It got a URL or a block of code wrong.**
Known and expected. URLs and code do not survive dictation today. Do not file those unless the
failure looks new.

**The setup script stops on a checksum.**
The download was cut short. Delete the file it names and run `./scripts/setup.sh` again.

**macOS asks for Accessibility again after an update.**
Expected when the app's signature changes. Grant it once more.

---

## Rolling back the correction model

If run9s1 turns out worse than run8 in real use, change two lines in `scripts/setup.sh`:

```
ADAPTER=run8
ADAPTER_SHA=d67d995d65fd878172e93283eafaca78c9afbd53ed29a928777da5672db12b2d
```

Then run `./scripts/setup.sh` again. Both models stay on the release, so nothing needs re-uploading.
