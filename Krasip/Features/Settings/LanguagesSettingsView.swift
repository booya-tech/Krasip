// LanguagesSettingsView.swift
// Krasip
// Languages tab: which languages to recognize, which speech engine to use, and text formatting rules.

import SwiftUI
import KrasipCore

struct LanguagesSettingsView: View {
    @Environment(AppController.self) private var app
    @State private var chosenInterfaceLanguage = InterfaceLanguage.current

    var body: some View {
        @Bindable var settings = app.settings
        Form {
            Section {
                Picker(AppString.Languages.interfaceLanguage, selection: interfaceLanguage) {
                    ForEach(InterfaceLanguage.allCases) { language in
                        Text(AppString.Languages.interfaceName(language)).tag(language)
                    }
                }
                if interfaceLanguageChanged {
                    Button(AppString.Languages.restartNow) { InterfaceLanguage.restart() }
                }
            } header: {
                Text(AppString.Languages.interfaceSection)
            } footer: {
                Text(AppString.Languages.interfaceHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(Language.allCases) { language in
                    Toggle(AppString.Languages.name(language), isOn: languageBinding(language))
                        .disabled(settings.languages == [language])
                }
            } header: {
                Text(AppString.Languages.languagesSection)
            } footer: {
                Text(AppString.Languages.languagesHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(AppString.Languages.engineSection) {
                Picker(AppString.Languages.engine, selection: $settings.engine) {
                    ForEach(SpeechEngine.available) { engine in
                        VStack(alignment: .leading) {
                            Text(AppString.Languages.engineName(engine))
                            Text(AppString.Languages.engineSummary(engine))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(engine)
                    }
                }
                .pickerStyle(.radioGroup)

                switch settings.engine {
                case .appleOnDevice:
                    OnDeviceModelRow()
                case .appleOnline:
                    PermissionRow(
                        title: AppString.Permissions.speech,
                        detail: AppString.Permissions.speechDetail,
                        status: app.permissions.speechRecognition
                    ) {
                        Task { await app.permissions.requestSpeechRecognition() }
                    }
                case .openAI:
                    OpenAISettingsSection()
                }
            }

            Section {
                Toggle(isOn: $settings.spaceBetweenThaiAndLatin) {
                    Text(AppString.Languages.spacing)
                    Text(AppString.Languages.spacingExample)
                }
                Toggle(isOn: $settings.convertSpokenTimes) {
                    Text(AppString.Languages.spokenTimes)
                    Text(AppString.Languages.spokenTimesExample)
                }
                Toggle(isOn: $settings.convertThaiTimes) {
                    Text(AppString.Languages.thaiTimes)
                    Text(AppString.Languages.thaiTimesExample)
                }
                Picker(AppString.Languages.punctuation, selection: $settings.punctuation) {
                    ForEach(PunctuationMode.allCases) { mode in
                        Text(AppString.Languages.punctuationName(mode)).tag(mode)
                    }
                }
            } header: {
                Text(AppString.Languages.formattingSection)
            } footer: {
                Text(AppString.Languages.formattingHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task(id: settings.languages) {
            await app.speechModel.refresh(for: Language.primary(of: settings.languages))
        }
    }

    private var interfaceLanguage: Binding<InterfaceLanguage> {
        Binding {
            chosenInterfaceLanguage
        } set: { language in
            InterfaceLanguage.select(language)
            chosenInterfaceLanguage = language
        }
    }

    private var interfaceLanguageChanged: Bool {
        chosenInterfaceLanguage != InterfaceLanguage.atLaunch
    }

    private func languageBinding(_ language: Language) -> Binding<Bool> {
        Binding {
            app.settings.languages.contains(language)
        } set: { enabled in
            app.settings.setLanguage(language, enabled: enabled)
        }
    }
}
