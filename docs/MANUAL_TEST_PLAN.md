# Manual test plan

About 15 minutes. These are the checks that need a real microphone, real permissions, and other apps — the parts automated tests cannot reach. Tick each box.

## 0. Before you start

- [ ] Build and run the **Krasip** scheme in Xcode (⌘R).
- [ ] The setup guide opens. Allow the Microphone. Allow Accessibility (System Settings → Privacy & Security → Accessibility → turn on Krasip). The guide updates by itself.
- [ ] Choose **Apple — on this Mac** and press **Download** for the Thai model (macOS 26), or allow Speech Recognition for **Apple — online**.
- [ ] A waveform icon is in the menu bar. Its menu says "Ready — hold ⌥Space to dictate".

## 1. The primary success case

- [ ] In the setup guide's practice box, hold ⌥ Space and say **"วันนี้จะต้องกลับบ้านไปทำ side project"**. Release.
- [ ] The overlay shows "● Listening…" while you hold, then "Transcribing…", then the text.
- [ ] The text in the box ends with **side-project** (from the seeded glossary entry).

If the engine hears "side project" as something else (for example สายเจ็ด), open History, select the dictation, fix the text, and save. Do the same fix a second time on another dictation — Krasip should offer to add a glossary rule.

## 2. Insertion in real apps (spec milestone 3)

For each app: click into a text field, hold ⌥ Space, say "เดี๋ยว push code ขึ้น GitHub", release.

| App | Expected | Pass |
| --- | --- | --- |
| Notes | Typed directly at the cursor | [ ] |
| Slack (or Discord) | Pasted into the message box; your clipboard is unchanged afterwards | [ ] |
| Safari or Chrome text field (e.g. a search box) | Pasted | [ ] |
| Code editor (Xcode or VS Code) | Inserted at the cursor | [ ] |
| Terminal | Pasted at the prompt | [ ] |

- [ ] After each one, press ⌘Z in that app — the dictated text is undone.
- [ ] Copy something first (e.g. a word), dictate into Slack, then paste with ⌘V elsewhere: your original clipboard is back.

## 3. Safety and fallbacks

- [ ] Click into a **password field** (e.g. a website login) and hold ⌥ Space: the overlay says "Password field", and nothing is recorded or typed.
- [ ] Click on the Desktop (no text field) and dictate: the overlay says **"Copied — paste with Command+V"**, and ⌘V in a text field pastes the text.
- [ ] Turn off Krasip in the Accessibility list and dictate: the text is copied, with a "Turn On Accessibility…" button. Turn it back on.
- [ ] Hold ⌥ Space and press **Esc** while speaking: the overlay disappears; nothing is typed.
- [ ] Hold ⌥ Space in silence for two seconds: "Didn't catch that".

## 4. Hands-free

- [ ] Quick-tap ⌥ Space: the overlay says "Hands-free · press ⌥Space to finish". Speak a longer sentence, then tap ⌥ Space again. The text is inserted.
- [ ] Menu bar → Start Hands-Free Dictation works the same way.

## 5. Review, suggestions, and undo

- [ ] Settings → General → "When the text is ready" → **Let me check it first**. Dictate the primary sentence: the review card appears with the change "side project → side-project · glossary".
- [ ] Click **Undo** next to the change: the text goes back to "side project". Press **Return** to insert.
- [ ] Click **Edit**, change a word, press **⌘Return**: the edited text is inserted into the app you started in.
- [ ] Settings → Glossary → add `กิตฮับ` → `GitHub` with **Ask me first**. Dictate "ขึ้น กิตฮับ" (or type it in Try it): a 💡 suggestion appears; **Use** applies it.
- [ ] Set "Let me check it first" back to **Insert it right away**.

## 6. Glossary

- [ ] Settings → Glossary → **Try it** box: type `ทำไซด์โปรเจ็กต์ต่อ` → it says "Would ask (sounds alike): ไซด์โปรเจ็กต์ → side-project".
- [ ] Export the glossary to JSON, delete an entry, import the file back: the entry returns.
- [ ] **Starter Terms…** adds common terms (choose "Ask me first").
- [ ] History → select a dictation → select a word in "What the speech engine heard" → **Add Preferred Spelling…** → save. "Also fix this dictation" updates the final text.

## 7. Per-app rules

- [ ] Settings → General → Per-app rules → Add App → Slack → punctuation **Drop the final period**. Dictate a sentence that ends with a period into Slack: no final period.
- [ ] Set another app to not "Insert right away": dictation there always shows the review card.

## 8. Privacy

- [ ] Settings → Privacy → turn on **Keep audio for retry**. Dictate once. History shows the waveform badge; **Play** and **Transcribe Again** work.
- [ ] **Delete Saved Audio** empties the audio (the size goes to zero).
- [ ] **Delete All History…** clears History but keeps the glossary.

## 9. Benchmark

- [ ] Menu bar → Benchmark…. Select A01, press **Record** (⌘R), read the sentence, press **Stop**. The next unrecorded sentence is selected.
- [ ] Record a handful more, tick the engines to compare, and press **Run Benchmark**. The summary shows term preservation and transliteration per engine.
- [ ] **Export CSV…** saves a spreadsheet of every result.
- [ ] **Add Sentence…** adds one of your own sentences (it shows a "Mine" badge, and right-click deletes it).

## 10. Microphone choice

- [ ] Settings → General → Microphone → pick a specific input (e.g. AirPods). Dictate: Krasip listens with that one. Unplug it and dictate again — Krasip falls back to the default instead of failing.

## 11. Thai interface

- [ ] Settings → Languages → **Show Krasip in** → ไทย → **Restart Now**. Krasip quits and comes back a second later, in Thai.
- [ ] Dictate once: the overlay, History, and the menu bar are all Thai.
- [ ] Set it back to **Same as macOS** (or English) and restart again.

## 12. Other engines (optional)

- [ ] Settings → Languages → **OpenAI — cloud** → paste an API key → **Test Connection** shows "Connected". Dictate the primary sentence again and compare.
- [ ] Local Whisper server: set the endpoint to your server (for example `http://localhost:8080/v1`) and model name; no key is needed.
