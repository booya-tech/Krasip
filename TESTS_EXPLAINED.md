# Tests explained

Every automated test, in plain English. Tests live in `Packages/KrasipKit/Tests` and use Swift Testing (`@Test`, `#expect`).

Run them with `swift test` inside `Packages/KrasipKit`, or ⌘U in Xcode.

---

## KrasipCoreTests — the logic (no microphone, no network)

### AcceptanceTests.swift — the spec's acceptance table

| Test | What it checks |
| --- | --- |
| `primarySuccessCase` | "…ไปทำ side project" becomes "…ไปทำ side-project", and the only change listed is `side project -> side-project (glossary)`. |
| `englishTermsStayUntouched` | "เดี๋ยว push code ขึ้น GitHub" comes out exactly the same, with no changes. |
| `spokenTimeBecomesDigits` | "…ตอน ten AM" becomes "…ตอน 10 AM", explained as a spoken-time change. |
| `pullRequestStaysUntouched` | "ส่ง pull request ให้ทีม" comes out exactly the same. |
| `thaiAliasUsesGlossaryWhenSaved` | With the side-project entry saved, "ทำไซต์โปรเจกต์" becomes "ทำ side-project". |
| `thaiAliasStaysWithoutGlossary` | Without that entry, "ทำไซต์โปรเจกต์" is left alone — no rule, no change. |
| `similarSoundingPhraseIsNotReplaced` | "ไซต์งาน" (a work site) is not replaced just because it starts like the alias. |
| `acceptanceCasesAreStableAcrossRuns` | Runs the key cases 20 times to prove the result never varies ("pass consistently"). |

### TextPolicyTests.swift — the cleanup rules

| Test | What it checks |
| --- | --- |
| `collapsesRepeatedWhitespaceAndTrims` | Tabs and double spaces become single spaces; the ends are trimmed; only "cleanup" changes are listed. |
| `removesZeroWidthCharacters` | Invisible zero-width characters are removed. |
| `composesUnicodeToNFC` | Decomposed accents are composed, so text looks and compares the same. |
| `keepsThaiCharactersExactly` | A plain Thai sentence is returned character for character. |
| `emptyTranscriptStaysEmpty` | Only spaces in → empty text out, no crash. |
| `insertsSpaceBetweenThaiAndEnglish` | "ส่งpull requestให้ทีม" gets a space on each side of the English. |
| `insertsSpaceBetweenThaiAndDigits` | "ตอน10 AM" becomes "ตอน 10 AM". |
| `spacingCanBeTurnedOff` | With the spacing setting off, nothing is inserted. |
| `existingSpaceIsNotDuplicated` | A space that is already there is not doubled. |
| `urlsAreNotBrokenBySpacingOrGlossary` | A URL next to Thai text is spaced from it but never changed inside, even when an alias ("github") appears in it. |
| `emailsAreProtected` | An alias inside an email address is not replaced. |
| `codeFragmentsAreProtectedFromPunctuationRemoval` | `config.json` and `fetchUser()` keep their dots and brackets when punctuation removal is on. |
| `numbersAreProtected` | "2,500" and "3.5%" keep their punctuation. |
| `englishIsNeverTransliteratedOrChangedWithoutARule` | With an empty glossary, every English word in a mixed sentence comes out unchanged. |
| `glossaryOutputIsNotReplacedAgain` | After "side project" becomes "side-project", a second rule for "project" cannot change it again. |
| `keepModeLeavesPunctuation` | The default punctuation mode leaves a final period alone. |
| `noTrailingPeriodModeDropsFinalPeriodOnly` | "Drop the final period" removes only the last period. |
| `noTrailingPeriodKeepsEllipsis` | "…" at the end is not treated as a period. |
| `noneModeRemovesSentencePunctuation` | "Remove punctuation" removes commas and exclamation marks. |
| `suggestModeDoesNotChangeTextButReportsSuggestion` | An "Ask me first" entry leaves the text unchanged but reports where the suggestion is. |
| `acceptingASuggestionAppliesIt` | Once accepted, that suggestion is applied. |
| `disabledEntryNeverReplaces` | An entry set to "Off" never replaces or suggests. |
| `undoingAGlossaryChangeRestoresTheTranscript` | Undoing a glossary change gives back what was heard. |
| `undoingSpokenTimeKeepsWords` | Undoing the time rule keeps "ten AM" as words. |
| `glossaryRangesPointAtOutputs` | The highlight ranges point exactly at "side-project" in the final text. |
| `finalizingTwiceChangesNothingMore` | Running the policy on its own output changes nothing more (seven sample sentences). |
| `everyChangeIsExplainedInSpecFormat` | A sentence with a glossary word, a time, and spacing lists all four changes in `before -> after (kind)` form. |

### SpokenTimeTests.swift — "ten AM" → "10 AM"

| Test | What it checks |
| --- | --- |
| `convertsClockTimes` | Nine spoken forms: AM/PM in any case, "a.m.", "o'clock", "nine thirty", "six oh five", "eleven forty-five", and no space after Thai. |
| `leavesOtherNumbersAlone` | "two meetings", "ten people", Thai "สิบโมง", "at nine", and "10 AM" are not touched. |
| `canBeTurnedOff` | With the setting off, "ten AM" stays as words. |

### GlossaryMatcherTests.swift — exact normalized alias matching

| Test | What it checks |
| --- | --- |
| `matchesLatinAliasIgnoringCase` | "side project" matches "Side Project". |
| `matchesLatinAliasAcrossRepeatedSpaces` | …and "side   project". |
| `doesNotMatchInsideLongerLatinWord` | "code" does not match inside "encode" or "codebase". |
| `doesNotMatchInsideHyphenatedWord` | "project" does not match inside "side-project" or "my_project". |
| `matchesThaiAliasInsideThaiRun` | A Thai alias is found inside Thai text with no spaces. |
| `thaiAliasIgnoresSpacesTheRecognizerInserted` | "ไซต์ โปรเจกต์" (with a stray space) still matches "ไซต์โปรเจกต์". |
| `decomposedSaraAmMatches` | ำ typed as two characters (ํ + า) still matches. |
| `neverSplitsAConsonantFromItsMarks` | Alias "ก" never matches the ก inside "กี่". |
| `respectsThaiLeadingVowels` | Alias "กม" does not match inside "เกม" (the เ belongs to ก). |
| `respectsThaiFollowingVowels` | Alias "ข" does not match inside "ขา". |
| `longestAliasWins` | "pull request" wins over a shorter "request" rule. |
| `lockedWinsOverSuggestAtSameLength` | When two rules match the same words, the locked one wins. |
| `disabledEntriesAreIgnored` | "Off" entries never match. |
| `findsEveryOccurrence` | Every occurrence in the text is found. |
| `fullWidthAndDashVariantsNormalize` | Full-width letters and unusual hyphens still match. |
| `cleansDuplicateAliases` | Blank and duplicate aliases are removed when saving. |
| `flagsVeryShortThaiAliases` | One- or two-character Thai aliases are flagged as risky. |
| `vocabularyHintsIncludeLatinSpellings` | The English spellings in the glossary are sent to speech engines as hints. |

### SoundAlikeTests.swift — "high-confidence phonetic match confirmed by the user"

| Test | What it checks |
| --- | --- |
| `variantSpellingsShareASoundKey` | Five pairs of Thai spellings of the same English word sound the same (e.g. ไซต์โปรเจกต์ / ไซด์โปรเจ็กต์, คอมมิต / คอมมิท). |
| `differentWordsHaveDifferentKeys` | Different words do not. |
| `soundAlikeIsSuggestedButTextIsUnchanged` | A sound-alike spelling becomes a suggestion; the text is not changed. |
| `acceptedSoundAlikeIsApplied` | After the user accepts it, it is replaced and explained as a glossary change. |
| `exactAliasWinsOverSoundAlike` | An exact alias is replaced directly, with no extra suggestion. |
| `unrelatedThaiIsLeftAlone` | Normal Thai sentences get no suggestions. |
| `shortAliasesNeverSoundAlike` | Short aliases (fewer than four sounds) are never used for sound-alikes. |
| `canBeTurnedOff` | The setting turns sound-alike suggestions off. |
| `disabledEntriesDoNotSoundAlike` | "Off" entries do not produce sound-alikes. |
| `silentLettersAreKeptWithTheWord` | The silent ต์ at the end is part of the suggestion, so no stray mark is left behind. |
| `acceptingASoundAlikeTeachesTheAlias` | In the full flow, tapping **Use** applies it and saves the new spelling as an alias. |

### LearnerTests.swift — learning from corrections

| Test | What it checks |
| --- | --- |
| `learnsThaiTransliterationToEnglish` | Fixing "…ไปทำไซต์โปรเจกต์" to "…ไปทำ side-project" suggests the rule ไซต์โปรเจกต์ → side-project. |
| `learnsHyphenationOfLatinWords` | Fixing "side project" to "side-project" suggests that exact rule. |
| `growsSingleLetterFixToWholeWord` | A one-letter fix (ต → ด) is suggested for the whole word, not the letter. |
| `learnsCasing` | "github" → "GitHub" is learned. |
| `findsSeveralSmallChanges` | Two fixes in one sentence give two suggestions. |
| `suggestsAddingAliasToExistingEntry` | A new spelling of an existing word is offered as an extra alias, not a new entry. |
| `suggestsLockingAKnownSuggestEntry` | A fix that an "Ask me first" entry already covers offers to lock that entry. |
| `ignoresWholeSentenceRewrites` | Rewriting the whole sentence is not treated as vocabulary. |
| `ignoresPureInsertionsAndDeletions` | Adding or removing words teaches nothing. |
| `identicalTextTeachesNothing` | No change, no suggestion. |
| `suggestionKeyIgnoresCaseOfAlias` | "Side Project" and "side project" count as the same repeated correction. |
| `knownRulesAreRecognized` | A rule that already exists is recognized, so it is not offered again. |
| `diffHunksAreWordAligned` | The diff grows changes to whole Thai words. |
| `countsChangedWords` | Word counts for the correction-rate metric are right. |

### DictationFlowTests.swift — the whole pipeline with fake parts

A fake microphone, a fixed transcript, and a fake inserter stand in for the real ones.

| Test | What it checks |
| --- | --- |
| `holdSpeakReleaseInsertsFinalTextAndRecordsHistory` | Hold, speak, release: the final text is inserted, and history stores raw text, final text, app, result, and latency. |
| `insertionFailureStillKeepsTheText` | If insertion fails, the text is on the clipboard, in history, and kept as the last text. |
| `lowConfidenceShowsRawTranscriptForReview` | Low confidence stops for review with the raw transcript; Return inserts. |
| `confirmingTwiceInsertsOnce` | Pressing Return and clicking Insert at the same time inserts only once. |
| `suggestionsWaitForTheUser` | An "Ask me first" suggestion waits; accepting it changes the text before inserting. |
| `editedReviewTextIsInsertedAndRecordedAsCorrection` | Text edited in the overlay is inserted and saved as a correction. |
| `undoingAChangeInReview` | Undo in the overlay restores what was heard. |
| `cancellingAReviewStillSavesItToHistory` | Esc on a review discards it, but it is still saved in history. |
| `secureFieldBlocksRecording` | In a password field, the microphone never starts. |
| `escapeWhileListeningCancelsWithoutTranscribing` | Esc while listening stops everything; nothing is inserted or saved. |
| `quickTapStartsHandsFreeAndSecondPressFinishes` | A quick tap starts hands-free mode; the next press finishes and inserts. |
| `quickTapWithoutHandsFreeAsksToHoldLonger` | With hands-free off, a quick tap asks you to hold longer. |
| `silenceIsNotSentToTheRecognizer` | A silent recording is not transcribed (engines invent text from silence). |
| `microphoneDeniedShowsNotice` | No microphone permission shows a clear notice. |
| `transcriptionErrorShowsNotice` | A bad API key shows a clear notice. |
| `perAppStyleCanForceReview` | An app set to "not right away" always gets the review card. |
| `perAppPunctuationIsApplied` | An app's punctuation choice is used. |
| `historyCanBeTurnedOff` | With history off, text is inserted but nothing is saved. |
| `repeatedCorrectionOfferIsShownAfterInsert` | A repeated correction produces an "Add to glossary?" offer that can be answered. |
| `finishedCardHidesAutomatically` | The result card hides on its own. |

### GlossaryJSONTests.swift — the spec's JSON shape

| Test | What it checks |
| --- | --- |
| `decodesTheSpecExample` | The exact JSON example from the spec loads. |
| `roundTripsEntries` | Export then import gives the same entries and modes. |
| `acceptsWrappedListAndFractionalDates` | `{"entries": [...]}` and dates with milliseconds also load; mode defaults to locked. |
| `rejectsGarbage` | Invalid JSON gives an error instead of an empty glossary. |

### BenchmarkTests.swift — the 50-sentence set and its metrics

| Test | What it checks |
| --- | --- |
| `bundledSetHasFiftyUniqueItems` | 50 sentences, unique ids, every category present. |
| `perfectTranscriptsOfTheScriptProduceTheExpectedText` | If a recognizer heard each sentence perfectly, the policy produces exactly the expected text — 50 real-world checks of the policy. |
| `expectedTextsAreStableUnderThePolicy` | The expected texts themselves are never changed by the policy. |
| `keyTermsAppearInExpectedText` | Every key term really appears in its expected sentence. |
| `scoresPerfectOutput` | A perfect answer scores 100%. |
| `detectsUnwantedTransliteration` | "กิตฮับ" instead of "GitHub" counts as a Thai-spelled English term. |
| `termMatchNeedsWholeWord` | "code" inside "encode" does not count as preserved. |
| `summaryAggregatesRates` | Summary rates are averaged correctly. |

---

## KrasipStorageTests — the SQLite database

### HistoryStoreTests.swift

| Test | What it checks |
| --- | --- |
| `recordsAndReadsBackEveryField` | Every field of a dictation survives saving and loading. |
| `specRecordSignatureWorks` | The spec's `record(raw, final, destinationApp)` works. |
| `recentIsNewestFirstAndSearchable` | History is newest first and can be searched. |
| `correctionUpdatesFinalTextAndKeepsBefore` | A correction updates the final text and keeps the before/after pair. |
| `repeatedCorrectionBecomesAnOffer` | The same fix in two dictations becomes an offer (not after one). |
| `knownRulesAreNotOfferedAgain` | Fixes already covered by a glossary rule are not offered. |
| `dismissedOffersStayDismissed` | "Don't Ask Again" is remembered. |
| `unchangedCorrectionIsANoOp` | Saving unchanged text records nothing. |
| `correctingUnknownDictationThrows` | Correcting a missing dictation gives a clear error. |
| `deletingRemovesCorrectionsAndReturnsAudio` | Deleting a dictation removes its corrections and returns its audio file for deletion. |
| `retentionDeletesOldDictations` | "Keep history for N days" removes older dictations. |
| `statsMatchQualityPlanDefinitions` | Insertion success rate, correction rate, and latency follow the quality plan's definitions. |

### GlossaryRepositoryTests.swift

| Test | What it checks |
| --- | --- |
| `savesAndLoadsEntries` | Entries save and load. |
| `upsertUpdatesInPlace` | Editing an entry updates it instead of adding a copy. |
| `deleteRemovesEntry` | Deleting works. |
| `importMergesSamePreferredOutput` | Importing merges aliases into an existing entry with the same spelling. |
| `seedsOnlyOnce` | The first-run example is added only to an empty glossary. |
| `appStylesRoundTrip` | Per-app rules save, load, and delete. |
| `dataSurvivesReopeningTheFile` | Data is still there after closing and reopening the database file. |

---

## KrasipSystemTests — macOS adapters

### AudioFileCodecTests.swift

| Test | What it checks |
| --- | --- |
| `wavHeaderIsCorrect` | The WAV sent to cloud engines has a correct header and 16 kHz sample rate. |
| `wavRoundTrips` | WAV written and read back keeps its length and loudness. |
| `m4aRoundTripsForKeptAudio` | Kept audio (`.m4a`) is smaller than WAV and reads back correctly. |
| `resamplesOtherRatesTo16k` | 48 kHz audio is converted to 16 kHz. |
| `voicedDurationSeparatesSpeechFromSilence` | Silence measures as zero voiced time; a tone measures as voiced. |

### AudioInputDevicesTests (in AudioFileCodecTests.swift)

| Test | What it checks |
| --- | --- |
| `listsDevicesWithNamesAndStableIDs` | The microphone list has a name and a unique, stable ID for every input device. |

### SampleSinkTests.swift

| Test | What it checks |
| --- | --- |
| `convertsStereo48kTo16kMono` | One second of 48 kHz stereo microphone audio becomes one second of 16 kHz mono, with a sensible level meter value. |
| `keepsRecordingAfterTheMicrophoneChanges` | When the input device changes format mid-recording (e.g. AirPods), recording continues and nothing is lost. |
| `ignoresBuffersInAnOldFormat` | A late buffer in the old format is dropped instead of corrupting the audio. |
| `silenceHasZeroLevel` | Silence shows an empty level meter. |

### OpenAIRequestTests.swift

| Test | What it checks |
| --- | --- |
| `buildsMultipartRequestForGPT4oTranscribe` | The request has the right URL, key header, model, language hint, confidence request, spelling hints, and file. |
| `whisperModelsUseVerboseJSONAndExamplePrompt` | Whisper models get segment timings and a mixed Thai-English example prompt. |
| `languageHintCanBeTurnedOff` | The language hint can be left out. |
| `customEndpointIsUsed` | Other OpenAI-compatible services (e.g. Groq) work. |
| `parsesJSONWithLogprobs` | Confidence is computed from token probabilities. |
| `parsesVerboseJSONSegments` | Confidence is computed from Whisper segments. |
| `plainJSONHasNoConfidence` | No probabilities → no confidence (never a made-up number). |
| `readsErrorMessages` | The service's error message is shown to the user. |
| `localServersNeedNoKey` | A local Whisper server (`http://localhost…`) needs no key. |
| `missingKeyFailsBeforeAnyNetworkCall` | Without a key, nothing is sent. |

### KeyComboTests.swift

| Test | What it checks |
| --- | --- |
| `defaultShortcutIsOptionSpace` | The default shortcut is ⌥Space and allowed. |
| `convertsAppKitModifiers` | Modifier keys convert correctly and display as ⇧⌘. |
| `plainLettersAreNotGlobalShortcuts` | A plain letter cannot become the global shortcut (it would block typing). F-keys can. |
| `combosSurviveCoding` | The shortcut saves and loads. |
| `pasteKeyIsFoundInCurrentLayout` | The "V" key for ⌘V is found in the current keyboard layout (matters with Thai input). |

### OnDeviceRecognitionTests.swift (only with `KRASIP_LIVE_ASR=1`)

| Test | What it checks |
| --- | --- |
| `recognizesPlainThaiOnDevice` | Apple's on-device engine turns synthetic Thai speech into Thai text with a confidence value. |
| `fullPipelineProducesFinalText` | Speech → recognizer → text policy works end to end. |

### BenchmarkLiveTests.swift (only with `KRASIP_LIVE_ASR=1`)

| Test | What it checks |
| --- | --- |
| `syntheticBenchmarkOnDevice` | Runs all 50 benchmark sentences (spoken by the macOS Thai voice) through Apple's on-device engine and writes a report. Set `KRASIP_BENCHMARK_REPORT=/path/report.txt` to choose where. |
