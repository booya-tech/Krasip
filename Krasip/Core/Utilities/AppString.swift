// AppString.swift
// Krasip
// Every user-facing string, grouped by screen. Keep copy short, plain, and friendly.

import Foundation
import KrasipCore

enum AppString {
    enum Common {
        static let cancel = String(localized: "Cancel")
        static let save = String(localized: "Save")
        static let back = String(localized: "Back")
        static let continueLabel = String(localized: "Continue")

        static func storageUnavailable(_ reason: String) -> String {
            String(localized: "Krasip could not open its local database, so history is kept only until you quit. (\(reason))")
        }
    }

    enum Menu {
        static let iconLabel = "Krasip"
        static let finishSetup = String(localized: "Finish Setup…")
        static let startHandsFree = String(localized: "Start Hands-Free Dictation")
        static let finishDictation = String(localized: "Finish Dictation")
        static let copyLast = String(localized: "Copy Last Dictation")
        static let history = String(localized: "History…")
        static let glossary = String(localized: "Glossary…")
        static let benchmark = String(localized: "Benchmark…")
        static let settings = String(localized: "Settings…")
        static let setupGuide = String(localized: "Setup Guide…")
        static let quit = String(localized: "Quit Krasip")
        static let statusListening = String(localized: "Listening…")
        static let statusWorking = String(localized: "Working…")
        static let statusReview = String(localized: "Waiting for your review")
        static let statusNeedsSetup = String(localized: "Setup needed before you can dictate")

        static func statusReady(_ shortcut: String) -> String {
            String(localized: "Ready — hold \(shortcut) to dictate")
        }

        static func shortcutProblem(_ problem: String) -> String {
            String(localized: "Shortcut problem: \(problem)")
        }
    }

    enum Overlay {
        static let listening = String(localized: "Listening…")
        static let transcribing = String(localized: "Transcribing…")
        static let cancel = String(localized: "Cancel")
        static let cancelHelp = String(localized: "Discard this text (it stays in History).")
        static let copy = String(localized: "Copy")
        static let edit = String(localized: "Edit")
        static let revertEdits = String(localized: "Undo Edits")
        static let insert = String(localized: "Insert")
        static let heard = String(localized: "Heard")
        static let reviewTitle = String(localized: "Check before inserting")
        static let suggestionBadge = String(localized: "Suggestion")
        static let reviewModeBadge = String(localized: "Review on")
        static let useSuggestion = String(localized: "Use")
        static let soundsLike = String(localized: "sounds like your glossary")
        static let copied = String(localized: "Copied")
        // The spec's exact fallback message.
        static let copiedFallback = String(localized: "Copied — paste with Command+V")
        static let cancelled = String(localized: "Discarded")
        static let secureFieldDetail = String(localized: "This is a password field, so Krasip did not type into it.")
        static let accessibilityDetail = String(localized: "Turn on Accessibility so Krasip can type for you.")
        static let noFieldDetail = String(localized: "No text field was selected.")
        static let appRejectedDetail = String(localized: "This app did not accept typed text.")
        static let unconfirmedDetail = String(localized: "If nothing appeared, press Command+V.")
        static let turnOnAccessibility = String(localized: "Turn On Accessibility…")

        static func inserting(_ appName: String?) -> String {
            appName.map { String(localized: "Inserting into \($0)…") } ?? String(localized: "Inserting…")
        }

        static func into(_ appName: String) -> String {
            String(localized: "into \(appName)")
        }

        static func releaseHint(_ shortcut: String) -> String {
            String(localized: "Release \(shortcut) to finish")
        }

        static func handsFreeHint(_ shortcut: String) -> String {
            String(localized: "Hands-free · press \(shortcut) to finish")
        }

        static func inserted(_ appName: String?) -> String {
            appName.map { String(localized: "Inserted into \($0)") } ?? String(localized: "Inserted")
        }

        static func pastedUnconfirmed(_ appName: String?) -> String {
            appName.map { String(localized: "Pasted into \($0) — also on the clipboard") } ?? String(localized: "Pasted — also on the clipboard")
        }

        static func lowConfidence(_ confidence: Double) -> String {
            String(localized: "Unsure · \(confidence.formatted(.percent.precision(.fractionLength(0))))")
        }

        static func moreChanges(_ count: Int) -> String {
            count == 1 ? String(localized: "1 more change") : String(localized: "\(String(count)) more changes")
        }
    }

    enum Notice {
        static let noSpeech = String(localized: "Didn't catch that")
        static let secureField = String(localized: "Password field")
        static let secureFieldDetail = String(localized: "Krasip never listens or types in password fields.")
        static let microphoneOff = String(localized: "Microphone is off for Krasip")
        static let microphoneProblem = String(localized: "Microphone problem")
        static let apiKey = String(localized: "Check your API key")
        static let speechOff = String(localized: "Speech Recognition is off for Krasip")
        static let transcriptionFailed = String(localized: "Couldn't turn speech into text")
        static let somethingWrong = String(localized: "Something went wrong")
        static let openMicrophoneSettings = String(localized: "Open Microphone Settings")
        static let openLanguageSettings = String(localized: "Open Language Settings")
        static let allowSpeech = String(localized: "Allow Speech Recognition")

        static func noSpeechDetail(_ shortcut: String) -> String {
            String(localized: "Hold \(shortcut), speak, then let go.")
        }

        static func holdLonger(_ shortcut: String) -> String {
            String(localized: "Hold \(shortcut) while you speak")
        }

        static func holdLongerDetail(_ shortcut: String) -> String {
            String(localized: "Or turn on hands-free taps in Settings → General.")
        }
    }

    enum Changes {
        static let undo = String(localized: "Undo")
        static let undoHelp = String(localized: "Put back what was said for this change.")
        static let removed = String(localized: "(removed)")
        static let undoSpacingHelp = String(localized: "Remove the spaces Krasip added between Thai and English.")

        static func spacingSummary(_ count: Int) -> String {
            count == 1 ? String(localized: "Added a space between Thai and English") : String(localized: "Added \(String(count)) spaces between Thai and English")
        }

        static func label(for kind: TextChange.Kind) -> String {
            switch kind {
            case .normalization: String(localized: "cleanup")
            case .glossary: String(localized: "glossary")
            case .spokenTime: String(localized: "spoken time")
            case .spacing: String(localized: "spacing")
            case .punctuation: String(localized: "punctuation")
            }
        }
    }

    enum Learning {
        static let addRule = String(localized: "Add to Glossary")
        static let notNow = String(localized: "Not Now")
        static let never = String(localized: "Don't Ask Again")
        static let makeRule = String(localized: "Make Rule…")
        static let bannerTitle = String(localized: "You keep making these fixes")
        static let becameRule = String(localized: "Became a rule")

        static func offerTitle(_ times: Int) -> String {
            String(localized: "You fixed this \(String(times)) times. Always write it this way?")
        }

        static func times(_ count: Int) -> String {
            "×\(count)"
        }
    }

    enum Settings {
        static let windowTitle = String(localized: "Krasip Settings")
        static let general = String(localized: "General")
        static let languages = String(localized: "Languages")
        static let glossary = String(localized: "Glossary")
        static let privacy = String(localized: "Privacy")
    }

    enum General {
        static let shortcutSection = String(localized: "Dictation shortcut")
        static let shortcut = String(localized: "Hold to talk")
        static let pressShortcut = String(localized: "Press keys…")
        static let resetShortcut = String(localized: "Use ⌥Space")
        static let shortcutNeedsModifier = String(localized: "Add ⌘, ⌥, or ⌃ to the shortcut.")
        static let handsFree = String(localized: "Quick tap for hands-free dictation")
        static let microphoneSection = String(localized: "Microphone")
        static let microphone = String(localized: "Listen with")
        static let systemDefaultMicrophone = String(localized: "System default")
        static let disconnectedMicrophone = String(localized: "Saved microphone (not connected — using the default)")
        static let afterSpeakingSection = String(localized: "After you speak")
        static let whenReady = String(localized: "When the text is ready")
        static let insertRightAway = String(localized: "Insert it right away")
        static let alwaysReview = String(localized: "Let me check it first")
        static let lowConfidence = String(localized: "Show what was heard when confidence is below")
        static let lowConfidenceHelp = String(localized: "Unsure results wait for you to check before Krasip types them.")
        static let insertionMethod = String(localized: "How to insert text")
        static let insertionAutomatic = String(localized: "Automatic (recommended)")
        static let insertionPaste = String(localized: "Always paste")
        static let appRulesSection = String(localized: "Per-app rules")
        static let appRulesHelp = String(localized: "For example: no final period in Slack, or always review before inserting into Mail.")
        static let noAppRules = String(localized: "No app rules yet.")
        static let addApp = String(localized: "Add App")
        static let punctuation = String(localized: "Punctuation")
        static let punctuationDefault = String(localized: "Default punctuation")
        static let autoInsert = String(localized: "Insert right away")
        static let removeRule = String(localized: "Remove this rule")
        static let feedbackSection = String(localized: "Sounds and startup")
        static let playSounds = String(localized: "Play sounds when listening starts and stops")
        static let launchAtLogin = String(localized: "Open Krasip when you log in")
        static let permissionsSection = String(localized: "Permissions")

        static func handsFreeHelp(_ shortcut: String) -> String {
            String(localized: "Tap \(shortcut) quickly and Krasip keeps listening. Tap again to finish.")
        }
    }

    enum Permissions {
        static let microphone = String(localized: "Microphone")
        static let microphoneDetail = String(localized: "Krasip listens only while you hold the shortcut.")
        static let accessibility = String(localized: "Accessibility")
        static let accessibilityDetail = String(localized: "Lets Krasip type the text where your cursor is. It never types into password fields.")
        static let speech = String(localized: "Speech Recognition")
        static let speechDetail = String(localized: "Needed for Apple's online speech recognition.")
        static let allow = String(localized: "Allow…")
        static let allowed = String(localized: "Allowed")
        static let openSettings = String(localized: "Open Settings…")
    }

    enum Languages {
        static let languagesSection = String(localized: "Languages you speak")
        static let languagesHelp = String(localized: "Krasip listens for Thai first and keeps English words in English.")
        static let engineSection = String(localized: "Speech engine")
        static let engine = String(localized: "Engine")
        static let formattingSection = String(localized: "Formatting")
        static let formattingHelp = String(localized: "These rules never translate or reword. Every change is listed so you can undo it.")
        static let spacing = String(localized: "Add a space between Thai and English")
        static let spacingExample = String(localized: "ไปทำside-project → ไปทำ side-project")
        static let spokenTimes = String(localized: "Write spoken times as numbers")
        static let spokenTimesExample = String(localized: "ten AM → 10 AM")
        static let punctuation = String(localized: "Punctuation")
        static let downloadModel = String(localized: "Download")
        static let modelChecking = String(localized: "Checking…")
        static let modelUnsupported = String(localized: "Not available on this Mac. Choose another engine.")
        static let modelNotInstalled = String(localized: "Download it once (about a minute). After that, no internet is needed.")
        static let modelInstalled = String(localized: "Ready. Your voice never leaves this Mac.")
        static let apiKey = String(localized: "API key")
        static let apiKeyPlaceholder = String(localized: "sk-…")
        static let saveKey = String(localized: "Save")
        static let model = String(localized: "Model")
        static let endpoint = String(localized: "Endpoint")
        static let languageHint = String(localized: "Tell the service you mainly speak Thai")
        static let languageHintHelp = String(localized: "Turn off if English comes out translated into Thai.")
        static let testConnection = String(localized: "Test Connection")
        static let connectionOK = String(localized: "Connected")
        static let openAIPrivacy = String(localized: "Your recording is sent to this service to be transcribed. Your key is stored in the macOS Keychain.")
        static let localServerPrivacy = String(localized: "This endpoint is on your Mac (for example a local Whisper server), so no key is needed and audio stays here.")

        static let interfaceSection = String(localized: "Krasip's own language")
        static let interfaceLanguage = String(localized: "Show Krasip in")
        static let interfaceHelp = String(localized: "This only changes Krasip's windows. Restart Krasip to see the change.")
        static let restartNow = String(localized: "Restart Now")

        static func interfaceName(_ language: InterfaceLanguage) -> String {
            switch language {
            case .system: String(localized: "Same as macOS")
            case .english: String(localized: "English")
            case .thai: String(localized: "Thai (ไทย)")
            }
        }

        static func name(_ language: Language) -> String {
            switch language {
            case .thai: String(localized: "Thai (ไทย)")
            case .english: String(localized: "English")
            }
        }

        static func engineName(_ engine: SpeechEngine) -> String {
            switch engine {
            case .appleOnDevice: String(localized: "Apple — on this Mac")
            case .appleOnline: String(localized: "Apple — online")
            case .openAI: String(localized: "OpenAI — cloud")
            }
        }

        static func engineSummary(_ engine: SpeechEngine) -> String {
            switch engine {
            case .appleOnDevice: String(localized: "Private and free. Works offline after a one-time download.")
            case .appleOnline: String(localized: "Free. Your recording is sent to Apple.")
            case .openAI: String(localized: "Best with mixed Thai and English. Needs your own API key.")
            }
        }

        static func modelTitle(_ language: Language) -> String {
            String(localized: "\(name(language)) speech model")
        }

        static func modelDownloading(_ fraction: Double) -> String {
            String(localized: "Downloading… \(fraction.formatted(.percent.precision(.fractionLength(0))))")
        }

        static func punctuationName(_ mode: PunctuationMode) -> String {
            switch mode {
            case .keep: String(localized: "Keep as heard")
            case .noTrailingPeriod: String(localized: "Drop the final period")
            case .none: String(localized: "Remove punctuation")
            }
        }
    }

    enum Glossary {
        static let intro = String(localized: "Teach Krasip your spelling. An alias is what the speech engine writes; the preferred spelling is what you want. Krasip only replaces an exact alias, and only with your saved spelling.")
        static let search = String(localized: "Search")
        static let starterTerms = String(localized: "Starter Terms…")
        static let importButton = String(localized: "Import…")
        static let exportButton = String(localized: "Export…")
        static let preferredColumn = String(localized: "Preferred spelling")
        static let aliasesColumn = String(localized: "Aliases")
        static let modeColumn = String(localized: "Mode")
        static let add = String(localized: "Add a spelling")
        static let edit = String(localized: "Edit…")
        static let delete = String(localized: "Delete")
        static let addTitle = String(localized: "Add preferred spelling")
        static let editTitle = String(localized: "Edit preferred spelling")
        static let preferredField = String(localized: "Preferred spelling")
        static let aliasesField = String(localized: "Aliases (one per line)")
        static let aliasesHelp = String(localized: "What the speech engine might write, e.g. side project, ไซต์โปรเจกต์")
        static let aliasField = String(localized: "Alias (what was heard)")
        static let modeField = String(localized: "When found")
        static let preview = String(localized: "Preview")
        static let tryIt = String(localized: "Try it")
        static let tryItPlaceholder = String(localized: "Type what the speech engine might write…")
        static let needsOutput = String(localized: "Add the spelling you want.")
        static let needsAlias = String(localized: "Add at least one alias.")
        static let starterTitle = String(localized: "Starter terms")
        static let starterIntro = String(localized: "Common English work terms and the Thai spellings speech engines often write instead. Choose “Ask me first” if you are not sure.")
        static let addStarterTerms = String(localized: "Add Terms")
        static let addPreferredTitle = String(localized: "Add preferred spelling")
        static let addPreferredIntro = String(localized: "From now on, when the speech engine writes the alias, Krasip writes your spelling.")
        static let fixThisDictation = String(localized: "Also fix this dictation")
        static let saveRule = String(localized: "Save Rule")

        static func modeName(_ mode: GlossaryEntry.Mode) -> String {
            switch mode {
            case .locked: String(localized: "Replace automatically")
            case .suggest: String(localized: "Ask me first")
            case .disabled: String(localized: "Off")
            }
        }

        static func modeHelp(_ mode: GlossaryEntry.Mode) -> String {
            switch mode {
            case .locked: String(localized: "Always write the preferred spelling.")
            case .suggest: String(localized: "Show the change and wait for you to accept it.")
            case .disabled: String(localized: "Keep the entry, but never replace anything.")
            }
        }

        static func riskyAliases(_ aliases: [String]) -> String {
            String(localized: "Very short Thai aliases can match inside other words: \(aliases.joined(separator: ", "))")
        }

        static let soundAlikes = String(localized: "Suggest spellings that sound like an alias")
        static let soundAlikesHelp = String(localized: "For example ไซด์โปรเจ็กต์ sounds like ไซต์โปรเจกต์. Krasip asks first, and remembers the spelling when you say yes.")

        static func wouldAsk(_ matched: String, _ output: String) -> String {
            String(localized: "Would ask: \(matched) → \(output)")
        }

        static func wouldAskSoundAlike(_ matched: String, _ output: String) -> String {
            String(localized: "Would ask (sounds alike): \(matched) → \(output)")
        }

        static func loadFailed(_ reason: String) -> String {
            String(localized: "Could not load your glossary: \(reason)")
        }

        static func saveFailed(_ reason: String) -> String {
            String(localized: "Could not save your glossary: \(reason)")
        }

        static func importSummary(added: Int, updated: Int) -> String {
            String(localized: "Imported: \(String(added)) new, \(String(updated)) updated.")
        }

        static func importFailed(_ reason: String) -> String {
            String(localized: "Import failed: \(reason)")
        }

        static func exported(_ count: Int) -> String {
            String(localized: "Exported \(String(count)) entries.")
        }
    }

    enum Privacy {
        static let historySection = String(localized: "Text history")
        static let saveHistory = String(localized: "Save dictation history on this Mac")
        static let saveHistoryHelp = String(localized: "Needed to fix past dictations and learn your spellings. Never uploaded.")
        static let keepFor = String(localized: "Keep history for")
        static let savedDictations = String(localized: "Saved dictations")
        static let deleteAllHistory = String(localized: "Delete All History…")
        static let deleteAllTitle = String(localized: "Delete all history?")
        static let deleteAllConfirm = String(localized: "Delete All")
        static let deleteAllMessage = String(localized: "Every saved dictation, correction, and kept recording will be removed. Your glossary stays.")
        static let audioSection = String(localized: "Audio")
        static let keepAudio = String(localized: "Keep audio for retry")
        static let keepAudioHelp = String(localized: "Off by default. When on, recordings are saved on this Mac so you can transcribe them again from History.")
        static let savedAudio = String(localized: "Saved audio")
        static let deleteAudio = String(localized: "Delete Saved Audio")
        static let whereSection = String(localized: "Where your data goes")
        static let noRewriting = String(localized: "Your text is never sent to an AI to be rewritten. Only your own glossary rules change what you said.")
        static let noPasswords = String(localized: "Krasip never listens or types in password fields.")
        static let localStorage = String(localized: "History, glossary, and settings are stored only on this Mac.")
        static let showData = String(localized: "Show Krasip Data in Finder")

        static func retentionName(_ retention: HistoryRetention) -> String {
            switch retention {
            case .forever: String(localized: "Forever")
            case .quarter: String(localized: "90 days")
            case .month: String(localized: "30 days")
            case .week: String(localized: "7 days")
            case .day: String(localized: "1 day")
            }
        }

        static func engineStatement(_ engine: SpeechEngine, localServer: Bool) -> String {
            switch engine {
            case .appleOnDevice: String(localized: "Your voice is turned into text on this Mac. Nothing is uploaded.")
            case .appleOnline: String(localized: "Your recording is sent to Apple to be turned into text.")
            case .openAI where localServer: String(localized: "Your recording is sent to the speech server running on this Mac.")
            case .openAI: String(localized: "Your recording is sent to your cloud speech service to be turned into text.")
            }
        }
    }

    enum History {
        static let windowTitle = String(localized: "Krasip History")
        static let search = String(localized: "Search dictations")
        static let emptyTitle = String(localized: "No dictations yet")
        static let noResults = String(localized: "No matches")
        static let selectTitle = String(localized: "Choose a dictation")
        static let selectMessage = String(localized: "See what was heard, fix the text, and teach Krasip your spelling.")
        static let copy = String(localized: "Copy")
        static let delete = String(localized: "Delete")
        static let finalText = String(localized: "Final text")
        static let saveCorrection = String(localized: "Save Correction")
        static let revert = String(localized: "Revert")
        static let restorePolicyText = String(localized: "Show Original Result")
        static let correctionHelp = String(localized: "Fix mistakes here. When you fix the same thing twice, Krasip offers to remember it.")
        static let rawTranscript = String(localized: "What the speech engine heard")
        static let addPreferredSpelling = String(localized: "Add Preferred Spelling…")
        static let addPreferredSpellingHelp = String(localized: "Select a word above first.")
        static let rawHelp = String(localized: "Select a word or phrase, then choose Add Preferred Spelling.")
        static let changes = String(localized: "Changes Krasip made")
        static let corrections = String(localized: "Your corrections")
        static let audio = String(localized: "Kept audio")
        static let play = String(localized: "Play")
        static let retry = String(localized: "Transcribe Again")
        static let retryResult = String(localized: "New result")
        static let useRetry = String(localized: "Use This Text")
        static let audioMissing = String(localized: "The recording for this dictation is no longer saved.")
        static let confidenceHelp = String(localized: "How sure the speech engine was.")
        static let latencyHelp = String(localized: "From letting go of the shortcut to the text appearing.")
        static let badgeCopied = String(localized: "Copied instead of inserted")
        static let badgeFallback = String(localized: "Could not insert — copied to the clipboard")
        static let badgeCancelled = String(localized: "Discarded")
        static let badgeLowConfidence = String(localized: "The speech engine was unsure")
        static let badgeCorrected = String(localized: "You corrected this")
        static let badgeAudio = String(localized: "Audio kept for retry")

        static func emptyMessage(_ shortcut: String) -> String {
            String(localized: "Hold \(shortcut) in any app and speak. Your dictations appear here.")
        }

        static func engine(_ providerID: String) -> String {
            SpeechEngine(transcriberID: providerID).map(Languages.engineName) ?? providerID
        }

        static func insertionName(_ result: InsertionResult) -> String {
            switch result {
            case .inserted(.accessibility): String(localized: "Typed directly")
            case .inserted(.paste): String(localized: "Pasted")
            case .inserted(.pasteUnconfirmed): String(localized: "Pasted (unconfirmed)")
            case .copiedToClipboard(.userChoseCopy): String(localized: "Copied by you")
            case .copiedToClipboard(.secureField): String(localized: "Password field — copied")
            case .copiedToClipboard: String(localized: "Copied — not inserted")
            case .cancelled: String(localized: "Discarded")
            }
        }

        static func loadFailed(_ reason: String) -> String {
            String(localized: "Could not load history: \(reason)")
        }

        static func saveFailed(_ reason: String) -> String {
            String(localized: "Could not save history: \(reason)")
        }
    }

    enum Stats {
        static let dictations = String(localized: "Dictations")
        static let dictationsHelp = String(localized: "Dictations saved on this Mac.")
        static let insertion = String(localized: "Inserted")
        static let insertionHelp = String(localized: "Insertion success rate: text typed into the app ÷ attempts.")
        static let corrections = String(localized: "Corrected")
        static let correctionsHelp = String(localized: "Correction rate: words you edited ÷ words dictated.")
        static let latency = String(localized: "Latency")
        static let latencyHelp = String(localized: "Median time from letting go of the shortcut to inserted text.")
    }

    enum Onboarding {
        static let windowTitle = String(localized: "Welcome to Krasip")
        static let finish = String(localized: "Start Using Krasip")
        static let welcomeTitle = String(localized: "Talk. Krasip types.")
        static let welcomeMessage = String(localized: "Hold the shortcut, speak Thai and English the way you normally do, and let go. Your words appear where your cursor is.")
        static let welcomePoint1 = String(localized: "Works in any app: Notes, Slack, your browser, your code editor.")
        static let welcomePoint2 = String(localized: "English words stay in English — no unwanted Thai spelling.")
        static let welcomePoint3 = String(localized: "Teach it your spelling once, like “side-project”.")
        static let microphoneTitle = String(localized: "Allow the microphone")
        static let microphoneMessage = String(localized: "Krasip listens only while you hold the shortcut. A red dot shows whenever it is listening.")
        static let accessibilityTitle = String(localized: "Let Krasip type for you")
        static let accessibilityMessage = String(localized: "macOS asks you to allow this once, so Krasip can put text where your cursor is. Without it, Krasip copies the text and you paste it.")
        static let accessibilityStepsTitle = String(localized: "How to allow it")
        static let accessibilitySteps = String(localized: "1. Click “Open Settings…” above.\n2. In Privacy & Security → Accessibility, turn on Krasip.\n3. Come back here. This page updates by itself.")
        static let accessibilityDone = String(localized: "All set. Krasip can type into your apps.")
        static let engineTitle = String(localized: "Choose how speech becomes text")
        static let engineMessage = String(localized: "You can change this anytime in Settings → Languages, and compare engines in the Benchmark window.")
        static let practiceTitle = String(localized: "Try it")
        static let practiceSay = String(localized: "Say this:")
        static let changeShortcut = String(localized: "Change Shortcut…")
        static let practiceNeedsPermissions = String(localized: "Go back and allow the microphone and Accessibility first.")
        static let practiceSuccess = String(localized: "It worked — “side project” became “side-project” from your glossary.")
        static let doneTitle = String(localized: "You're ready")
        static let donePoint1 = String(localized: "Krasip lives in the menu bar at the top of your screen.")
        static let donePoint2 = String(localized: "History keeps every dictation, so nothing is lost.")
        static let donePoint3 = String(localized: "Fix a word twice and Krasip offers to remember it.")

        static func practiceMessage(_ shortcut: String) -> String {
            String(localized: "Click in the box below. Hold \(shortcut), say the sentence, then let go.")
        }

        static func doneMessage(_ shortcut: String) -> String {
            String(localized: "Hold \(shortcut) in any app to dictate. Quick-tap it to keep listening hands-free.")
        }
    }

    enum Benchmark {
        static let windowTitle = String(localized: "Krasip Benchmark")
        static let category = String(localized: "Category")
        static let allCategories = String(localized: "All categories")
        static let summaryTitle = String(localized: "Thai-English benchmark")
        static let summaryIntro = String(localized: "Record yourself reading each sentence, then run the engines. Term preservation matters more than raw accuracy: one wrong GitHub, name, or URL can ruin a sentence.")
        static let engineColumn = String(localized: "Engine")
        static let termsColumn = String(localized: "Terms kept")
        static let transliterationColumn = String(localized: "Thai-spelled English")
        static let cerColumn = String(localized: "Char. errors")
        static let exactColumn = String(localized: "Exact")
        static let latencyColumn = String(localized: "Latency")
        static let countColumn = String(localized: "Clips")
        static let notRun = String(localized: "Not run yet")
        static let engines = String(localized: "Engines")
        static let useMyGlossary = String(localized: "Include my glossary")
        static let run = String(localized: "Run Benchmark")
        static let stop = String(localized: "Stop")
        static let synthesize = String(localized: "Fill Missing with System Voice")
        static let synthesizeHelp = String(localized: "Creates robot-voice recordings for a quick smoke test. Real recordings of your voice are what count.")
        static let exportCSV = String(localized: "Export CSV…")
        static let showFolder = String(localized: "Show Recordings")
        static let nothingToRun = String(localized: "Record at least one sentence and choose an engine.")
        static let finished = String(localized: "Benchmark finished.")
        static let cancelled = String(localized: "Benchmark stopped.")
        static let say = String(localized: "Say this")
        static let record = String(localized: "Record")
        static let stopRecording = String(localized: "Stop")
        static let play = String(localized: "Play")
        static let deleteRecording = String(localized: "Delete")
        static let raw = String(localized: "Heard")
        static let final = String(localized: "Final")
        static let exactMatch = String(localized: "Exact match")

        static let addSentence = String(localized: "Add Sentence…")
        static let importSentences = String(localized: "Import Sentences…")
        static let exportSentences = String(localized: "Export Sentences…")
        static let deleteSentence = String(localized: "Delete Sentence")
        static let mine = String(localized: "Mine")
        static let addTitle = String(localized: "Add a benchmark sentence")
        static let addIntro = String(localized: "Grow your own set toward the spec's 200 sentences: plain Thai, work terms, names, numbers, URLs and code — and record some in noisy places.")
        static let scriptField = String(localized: "What you will say")
        static let expectedField = String(localized: "Expected final text")
        static let expectedHelp = String(localized: "Leave empty to use the same text. Write numbers and times the way Krasip should output them.")
        static let keyTermsField = String(localized: "Key terms (comma separated)")
        static let keyTermsHelp = String(localized: "Words that must come out exactly, e.g. GitHub, พี่แบงก์, 10 AM.")
        static let noteField = String(localized: "Note (optional)")
        static let add = String(localized: "Add")

        static func categoryName(_ category: BenchmarkCategory) -> String {
            category.title
        }

        static func imported(_ count: Int) -> String {
            count == 1 ? String(localized: "Added 1 sentence.") : String(localized: "Added \(String(count)) sentences.")
        }

        static func importFailed(_ reason: String) -> String {
            String(localized: "Import failed: \(reason)")
        }

        static func recordedCount(_ recorded: Int, _ total: Int) -> String {
            String(localized: "\(String(recorded)) of \(String(total)) recorded")
        }

        static func running(_ engine: String, _ item: String) -> String {
            String(localized: "\(engine): \(item)…")
        }

        static func itemFailed(_ item: String, _ reason: String) -> String {
            String(localized: "\(item) failed: \(reason)")
        }

        static func syntheticWarning(_ count: Int) -> String {
            String(localized: "\(String(count)) clips use the system voice. Replace them with your own voice for real results.")
        }

        static func expected(_ text: String) -> String {
            String(localized: "Expected: \(text)")
        }

        static func cer(_ value: Double) -> String {
            String(localized: "Char. errors \(value.formatted(.percent.precision(.fractionLength(0))))")
        }

        static func missing(_ terms: [String]) -> String {
            String(localized: "Missing: \(terms.joined(separator: ", "))")
        }

        static func transliterated(_ terms: [String]) -> String {
            String(localized: "Written in Thai instead of English: \(terms.joined(separator: ", "))")
        }
    }
}
