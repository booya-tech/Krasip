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
| `undoingSpacingKeepsTheTextJoined` | Undoing the spacing rule leaves Thai and English joined, as heard. |
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
| `leavesOtherNumbersAlone` | "two meetings", "ten people", "at nine", and "10 AM" are not touched. |

### SpokenSymbolTests.swift: the spoken name of a symbol becomes the symbol

Every recorded input is verbatim raw output from the speech model on a real recording. The table decides which names count, so these tests only ever check the text that comes out and the change that was logged.

Most symbols sit flush against one word, `ว้าว เครื่องหมายตกใจ` to `ว้าว!`. The four that sit between two things, `=`, `&`, `*`, and `#` said as `เครื่องหมายชาร์ป`, stand on their own instead and get one space on each side, so `hex เครื่องหมายเท่ากับ 10` becomes `hex = 10` and not `hex= 10`. The hashtag `#`, the bare `แหซทัก`, is a different row and still binds to the word after it.

`hash` is the name of `#` and an ordinary English word at the same time, so that row carries a list of words that must not follow it. A developer saying `hash map`, `hash table`, or `hash function` gets the words back untouched, while `hash the map` still gets the symbol, because only the word immediately after the name is checked. The preferred spelling of those phrases is a glossary job instead: `Hashmap`, `hash table`, and `hash function` are offered in the starter terms, and the glossary runs first and protects what it writes, so the rule never sees a phrase the user has saved.

A count word in front of the name repeats the symbol, so `double hash tag` is `##` and `triple hash tag` is `###`. It sits between the `เครื่องหมาย` prefix and the name, which is how the phrase is said: `เครื่องหมายดับเบิลโคลอน`. Only `double`, `triple`, and their Thai spellings count. The Thai `สอง` is left out on purpose, because it is an everyday number word and no recording shows how the model writes it in front of a symbol name.

`@` needs more care, because a wrong `@` in a URL or a file name is worse than a missing one. Said by name, `เครื่องหมายแอท` and the English `at sign` work like any other marker name. The bare `แอท` only counts with a Latin word directly on each side, as in `support แอท krasip`, because inside a Thai run it could be the start of `แอทแลนติก`. The bare English `at` never counts, because it is an everyday word. The `@` then joins the two words into one address, `support@krasip`.

The model usually does not write the word at all. Measured on real recordings it kept "at" as a label, `support.at.grasip.app`, or wrote a dot, `admin.example.com`. The first is put back whenever `at` sits between two labels and an email-shaped domain follows. The second looks exactly like a website, so it is only put back when an email word such as `อีเมล`, `สำเนา`, `cc`, or `mail` comes just before it, and the token has exactly three parts. The first part must also be a name people use for a mailbox, such as `admin`, `info`, `support`, `sales`, or `hello`. A website's prefix like `docs`, `api`, `shop`, or `blog` never qualifies, because a website and an address are said differently but the model writes the same dot for both. `ส่งไปที่` is not enough, because it comes before a website just as often. Both repairs run before websites and code are protected, because that step would otherwise lock the dotted word as it stands.

An address can also be spoken in parts, as in `patompong.beam at sign gmail dot com`. The model then writes the `@` as a phrase: `at sign`, `add sign` (how it hears a spoken "at sign"), or the Thai `แอดไซน์`. When a domain follows that phrase, the whole address is joined into one: the spoken `dot` becomes `.`, and a name spelled letter by letter, `p-e-a-m`, becomes `peam`. A plain `at` only counts in front of a mail provider people use every day: `gmail.com`, `hotmail.com`, `outlook.com`, `yahoo.com`, or `icloud.com`. So `I work at google.com` stays as spoken. Every part must be joined to the next by a dot, so the word before the address never gets pulled in.

| Test | What it checks |
| --- | --- |
| `writesTheSymbolTheUserSpoke` | The eleven recorded sentences, with their spacing: `เครื่องหมายตกใจ` to `!`, `hashtag` to `#`, `100 ดอลลาร์` to `$100`, the two brackets, `colon`, `semicolon`, `แห่ง` to `&`, `ดอกจัน` to `*`, `เท่ากับ` to `=`, and `hash sign` in an all-English sentence. |
| `repairsTheBenchmarkSlips` | Three slips from the 31 October benchmark recordings. An underscore said in Thai, `API อันเดอร์สกอร์ key`, joins its two words into `API_key`; it needs a Latin word on each side, so a Thai sentence about the word itself is left alone. Said slowly on its own, Whisper writes `API, underscore, key` or `API เครื่องหมาย underscore key`, and both give `API_key`: the pause commas and the marker are part of the phrase. The English verb is left alone, because a word like `this`, `the`, or `and` after it blocks the rule: `I want to underscore this point`. `เครื่องหมายทั้งกับ`, the model's spelling of a spoken เท่ากับ, gives `=`, and only behind the marker, so an everyday `ทั้งกับ` is untouched. A port written with a scheme's slashes, `localhost://3000` or `127.0.0.1://8085`, loses the slashes; a real `http://` is followed by a host, never by a bare port number, so URLs are untouched. |
| `writesAnEmptyPairAsACall` | `fetchUser วงเล็บเปิดวงเล็บปิด` becomes `fetchUser()`, with or without a space between the two names, because an empty pair is a function call and sticks to the name before it. A word right after it is kept apart, so the Thai run `วงเล็บปิดก่อน` gives `fetchUser() ก่อน`, and a pair at the end of the text gets no trailing space. A pair with something inside, `fetchUser วงเล็บเปิด id วงเล็บปิด`, keeps its space: `fetchUser (id)`. |
| `keepsOneSpaceOnEachSideOfAStandaloneSymbol` | A standalone symbol at the very start or the very end of the text gets no space on the outside, a line break next to it counts as a separator already, text with a space on one side only ends with exactly one on each side, and no output ever holds two spaces in a row. |
| `aStandaloneSymbolSwallowsNoSpace` | The logged change for `hex เครื่องหมายเท่ากับ 10` is the phrase alone becoming `=`, leaving the spaces that were already there, and the one for `ดูที่เครื่องหมายดอกจันท้ายประโยค` carries the two new spaces with the symbol. |
| `logsEverySymbolAsAChange` | Each of those sentences logs a `spoken symbol` change whose before is a piece of the raw text and whose after is in the final text. |
| `logsTheSpokenPhraseAndTheSymbolItBecame` | The logged change for `ว้าว เครื่องหมายตกใจ` is the space plus the whole phrase turning into `!`, which is what the undo button reverses. |
| `logsBothBracketsOfOneSentence` | One sentence with two symbols logs two changes, in the order they were said. |
| `movesTheCurrencySymbolInFrontOfTheNumber` | `100 ดอลลาร์` is logged as one change covering the number too, because `$` moves in front of it. |
| `leavesTextWithoutASpokenSymbolAlone` | `sharp` without a marker, `ดอลล่า` with no number in front, the mangled `colon ใส่`, a URL and an email holding table names, and `android` and `hashed` all come through byte-identical with no change logged. |
| `bareNameNeedsNoMarkerButAMarkerNameDoes` | `hash` alone is enough and keeps its hashtag spacing; `sharp` needs `เครื่องหมาย` before it and then stands on its own. |
| `currencyNeedsDigitsInFront` | `20 dollars` becomes `$20`; the same word with no number stays a word. |
| `theEnglishSuffixIsIgnoredInAThaiSentence` | The `sign` suffix is only honoured when nothing in the text is Thai, because in a Thai sentence the model turns `colon sign` into `colon ใส่`. |
| `protectedSpansKeepTheirSymbolNames` | A URL, an email, and a backtick code fragment holding `hash`, `and`, or `colon` are untouched. |
| `aColonBetweenDigitsStaysATime` | The Thai time rule claims its colon first, so `บ่ายสองครึ่ง` is still `14:30` even next to a spoken colon. |
| `theUserCanUndoTheWholeRule` | Undoing the change turns the rule off and the raw text comes back. |
| `runningThePolicyAgainChangesNothingFurther` | Finalizing the output of all eleven sentences, all seven spacing cases, all eight spaced-name and count cases, and every `@` and spoken-address case below again changes nothing, so inserting a space or an `@` never pushes the text further. |
| `theSymbolIsProtectedFromLaterRules` | The new piece of text is marked protected, so spacing and punctuation leave the symbol alone. |
| `theLongerSpellingOfANameWins` | `ดอกจันทน์` is not read as `ดอกจัน` plus a leftover tail, `hashtag` wins over `hash`, and the spaced `hash tag` wins over `hash` so no `tag` is left stranded. |
| `writesASpacedNameAndRepeatsForACountWord` | `hash tag` and `แฮช แท็ก` said as two words give one `#`, and a count word in front repeats it: `double hash tag` to `##`, `triple hash tag` to `###`, `double colon sign` to `::`, `เครื่องหมายดับเบิลโคลอน` to `::`. |
| `logsTheCountWordAsPartOfThePhrase` | The count word is inside the logged change, so undo puts `double hash tag` back whole instead of leaving `double` behind. |
| `leavesAnOrdinaryHashPhraseAlone` | `hash map`, `hash function`, `hash table`, `hash join`, `hash key`, `hash value`, `hash collision`, and an already written `Hashmap` all come through byte-identical with no change logged. |
| `onlyTheWordRightAfterTheNameCanBlockTheSymbol` | `hash the map` still becomes `#the map`, because `map` is not the next word, and `HASH MAP` is blocked too, so the list ignores case. |
| `aNameAtTheEndOfTheTextStillBecomesTheSymbol` | `hash` with nothing after it is still `#`, so the missing next word is not treated as a blocked one. |
| `aCountWordWithNoSymbolNameIsLeftAlone` | `double trouble` and `ดับเบิลเบอร์เกอร์` are untouched, because a count word only counts in front of a name. |
| `aGlossaryEntryClaimsThePhraseBeforeTheRuleRuns` | With the starter `Hashmap` entry saved, `ใช้ hash map เก็บค่า` becomes `ใช้ Hashmap เก็บค่า` and no spoken-symbol change is logged at all. |
| `withNoGlossaryEntryThePhraseStaysAsSpoken` | With an empty glossary the same sentence stays `ใช้ hash map เก็บค่า`, so the rule protects itself and does not lean on the glossary. |
| `writesTheAtSignTheUserSpoke` | `support แอท krasip` becomes `support@krasip`, and still does when the next word is a web address like `krasip.app`. `เครื่องหมายแอท`, `at sign`, `add sign`, `เครื่องหมาย add`, and `แอดไซน์` alone become `@`, `support แอดไซน์ krasip` becomes `support@krasip`, and `type the at sign here` gets `@` as a word of its own, the same way `hash sign` does. |
| `logsTheSpokenAtWithTheSpacesItJoined` | The logged change for `support แอท krasip.app` is ` แอท ` with both spaces becoming `@`, so undo puts the spaces back too. |
| `leavesAnOrdinaryAtAlone` | `meet me at noon`, `look at this`, `แอทแลนติก`, `ที่ at`, `แอท` with Thai on either side, `2 แอท 3` between numbers, and the bare English `support at krasip` all come through byte-identical with no change logged. |
| `putsBackTheAtOfADottedEmail` | The recorded `support.at.grasip.app` becomes `support@grasip.app`, and `admin.example.com`, `info.example.com`, or `sales.example.com` becomes an address after each email word: `สำเนา`, `อีเมล`, `อีเมล์`, `เมล`, `Email`, `e-mail`, `cc`, and `bcc`. A full stop after the address stays a full stop. |
| `logsTheWholeAddressAsOneChange` | Each repair logs the whole address before and after, so the user sees which address was changed. |
| `theRepairedAddressIsProtectedAsAnEmail` | Once its `@` is back, the address is caught by the ordinary email protection, so no later rule touches it. |
| `leavesDottedTextThatIsNotAnEmailAlone` | Forty-four everyday dotted lines come through byte-identical with no change logged: file names, versions, `3.14`, `e.g.`, `Node.js`, websites with and without `www`, `https://`, a path, or a port, an `at` label at the start or the end or between numbers, `Array.prototype.at.call`, a three-part file name after `สำเนา`, `mail.google.com` after `อีเมล`, an address after `ส่งไปที่` with no email word, a website prefix after an email word (`docs`, `api`, `blog`, `shop`, `at`), a person's name after `cc`, an email word too far back or on the line above, `เมล็ด` which only starts like `เมล`, and an address that already has its `@`. |
| `theUserCanUndoTheEmailRepair` | Undoing the repair turns the rule off and the dotted token comes back as the model wrote it. |
| `assemblesAnEmailAddressSpokenInParts` | Four real recordings come out as one address: `patompong.beam at sign gmail.com`, `patombong.beam แอดไซน์ gmail.com`, the spelled `p-a-t-o-m-p-o-n-g .p-e-a-m แอดไซน์ gmail.com`, and `p-o-o-y-a dot p-a-n-n-a-c-h-a-i แอดไซน์ gmail dot com`. So do a recorded plain `at` before `gmail.com`, `add sign`, `at-sign`, `แอทไซน์` before a `.co.th` domain, a full stop after the address, and a plain `at` before `outlook.com` in an English sentence. |
| `leavesNearMissesOfASpokenEmailAlone` | `add sign up`, `add sign-in`, `add sign out`, `I work at google.com`, `meet at gmail` with no domain ending, `e-mail` which is not spelled out, and an address that already has its `@` all come through byte-identical with no change logged. |
| `logsTheSpokenAddressAsOneChangeTheUserCanUndo` | The whole spoken address is logged as one change, and undoing it brings back the words exactly as the model wrote them. |

### ThaiSpokenTimeTests.swift: Thai times as people type them

Follows `docs/THAI_TIME_RULES.md`. There is no setting, so every test runs the standard style.

| Test | What it checks |
| --- | --- |
| `keepsWholeHoursAsSpokenWithDigits` | A whole hour keeps its words with the number as a digit: `หกโมงเย็น` to `6 โมงเย็น`, `บ่ายสอง` to `บ่าย 2`, `ตีห้า` to `ตี 5`. `เที่ยง`, `บ่ายโมง`, `ทุ่มนึง`, and `เที่ยงคืน` stay as they are, and a space the speech model put inside the time is removed. |
| `writesAClockForAClearHourWithMinutes` | An hour with minutes becomes the 24-hour clock with a leading zero: `บ่ายสองครึ่ง` to `14:30`, `ห้าโมงครึ่ง` to `17:30`, `ตีสองครึ่ง` to `02:30`, and the old way of counting, `สี่โมงเช้าครึ่ง` to `10:30`. |
| `writesAClockForAnHourSaidTheTwentyFourHourWay` | `สิบสี่โมง`, `14 โมง`, and `สิบแปดนาฬิกา` always become a clock, also without minutes. |
| `leavesAnUnclearHourSpokenWithoutAPeriodWord` | `หกโมงครึ่ง` can be morning or evening, so it becomes `6 โมงครึ่ง`, never a guessed clock. `เย็น` meaning cold, or a period word too far back, does not decide it. |
| `usesAPeriodWordJustBeforeTheHour` | `เช้า` or `เย็น` just before the hour decides it: `ตอนเช้าหกโมงครึ่ง` to `ตอนเช้า 06:30`, `เย็นนี้เจอกันหกโมงครึ่ง` to `18:30`. A whole hour still stays spoken. |
| `keepsClearHoursAsTheyWere` | A clear hour keeps its meaning whatever word comes before: `เจ็ดโมงครึ่ง` after `ตอนเช้า` is still 07:30. |
| `doesNotReadOtherWordsAsMinutes` | A count (`สิบคน`, `20 บาท`), a word that starts the next phrase (`เย็นนี้`, `ครึ่งวัน`), and `อีกสิบนาที` before the hour are not minutes. |
| `leavesNonTimesAlone` | Spending (`ทุ่มหนึ่งล้านบาท`), effort (`ทุ่มเท`), lengths of time (`สองชั่วโมงครึ่ง`), meals (`มื้อเที่ยง`), and `ซื้อนาฬิกา` are not touched. |
| `timeSurvivesPunctuationRemoval` | A clock time keeps its colon when punctuation is removed. |

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

### BenchmarkTests.swift — the bundled sentence set and its metrics

| Test | What it checks |
| --- | --- |
| `bundledSetHasUniqueItemsInEveryCategory` | 56 sentences, unique ids, every category present. |
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
| `localServersUseVerboseJSONWhateverTheModelName` | A local server gets asked for segment scores even when its model name has no "whisper" in it, so unsure results can be caught. |
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
