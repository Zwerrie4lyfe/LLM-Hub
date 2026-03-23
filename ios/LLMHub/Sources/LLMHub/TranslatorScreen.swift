import SwiftUI

// MARK: - Language model for Translator
private struct TranslationLanguage: Identifiable, Hashable {
    let id: String
    let name: String
}

private let kTranslationLanguages: [TranslationLanguage] = [
    TranslationLanguage(id: "auto", name: "Auto Detect"),
    TranslationLanguage(id: "en",   name: "English"),
    TranslationLanguage(id: "es",   name: "Spanish"),
    TranslationLanguage(id: "fr",   name: "French"),
    TranslationLanguage(id: "de",   name: "German"),
    TranslationLanguage(id: "it",   name: "Italian"),
    TranslationLanguage(id: "pt",   name: "Portuguese"),
    TranslationLanguage(id: "ru",   name: "Russian"),
    TranslationLanguage(id: "zh-CN", name: "Chinese (Simplified)"),
    TranslationLanguage(id: "zh-TW", name: "Chinese (Traditional)"),
    TranslationLanguage(id: "ja",   name: "Japanese"),
    TranslationLanguage(id: "ko",   name: "Korean"),
    TranslationLanguage(id: "ar",   name: "Arabic"),
    TranslationLanguage(id: "hi",   name: "Hindi"),
    TranslationLanguage(id: "tr",   name: "Turkish"),
    TranslationLanguage(id: "nl",   name: "Dutch"),
    TranslationLanguage(id: "pl",   name: "Polish"),
    TranslationLanguage(id: "uk",   name: "Ukrainian"),
    TranslationLanguage(id: "sv",   name: "Swedish"),
    TranslationLanguage(id: "no",   name: "Norwegian"),
    TranslationLanguage(id: "da",   name: "Danish"),
    TranslationLanguage(id: "fi",   name: "Finnish"),
    TranslationLanguage(id: "id",   name: "Indonesian"),
    TranslationLanguage(id: "ms",   name: "Malay"),
    TranslationLanguage(id: "th",   name: "Thai"),
    TranslationLanguage(id: "vi",   name: "Vietnamese"),
    TranslationLanguage(id: "fa",   name: "Persian"),
    TranslationLanguage(id: "he",   name: "Hebrew"),
    TranslationLanguage(id: "el",   name: "Greek"),
    TranslationLanguage(id: "hu",   name: "Hungarian"),
    TranslationLanguage(id: "cs",   name: "Czech"),
    TranslationLanguage(id: "ro",   name: "Romanian"),
    TranslationLanguage(id: "bg",   name: "Bulgarian"),
    TranslationLanguage(id: "hr",   name: "Croatian"),
    TranslationLanguage(id: "sr",   name: "Serbian"),
    TranslationLanguage(id: "sk",   name: "Slovak"),
    TranslationLanguage(id: "sl",   name: "Slovenian"),
    TranslationLanguage(id: "et",   name: "Estonian"),
    TranslationLanguage(id: "lv",   name: "Latvian"),
    TranslationLanguage(id: "lt",   name: "Lithuanian"),
]

// MARK: - TranslatorScreen
struct TranslatorScreen: View {
    @EnvironmentObject var settings: AppSettings

    var onNavigateBack: () -> Void
    var onNavigateToModels: () -> Void

    @StateObject private var backend = LLMBackend.shared
    @State private var inputText: String = ""
    @State private var translationResult: String = ""
    @State private var selectedSource: TranslationLanguage = kTranslationLanguages[0]
    @State private var selectedTarget: TranslationLanguage = kTranslationLanguages[1]
    @State private var isTranslating: Bool = false
    @State private var translationTask: Task<Void, Never>?
    @State private var showSourcePicker = false
    @State private var showTargetPicker = false

    private var modelLoaded: Bool { backend.isLoaded }

    private func buildPrompt() -> String {
        let fromPart = selectedSource.id == "auto" ? "" : "from \(selectedSource.name) "
        return "Translate the following text \(fromPart)to \(selectedTarget.name). Return only the translated text without any explanation or notes:\n\n\(inputText)"
    }

    private func translate() {
        guard modelLoaded, !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        translationResult = ""
        isTranslating = true
        translationTask = Task {
            do {
                let prompt = buildPrompt()
                try await LLMBackend.shared.generate(prompt: prompt) { partial, _, _ in
                    Task { @MainActor in translationResult = partial }
                }
            } catch {
                await MainActor.run { translationResult = error.localizedDescription }
            }
            await MainActor.run { isTranslating = false }
        }
    }

    private func cancel() {
        translationTask?.cancel()
        translationTask = nil
        isTranslating = false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Button { onNavigateBack() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(settings.localized("back"))
                    }
                }
                Spacer()
                Text(settings.localized("translator_title"))
                    .font(.headline)
                Spacer()
                Button { inputText = ""; translationResult = "" } label: {
                    Text(settings.localized("feature_clear"))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Language pickers row
                    HStack(spacing: 12) {
                        // Source
                        VStack(alignment: .leading, spacing: 4) {
                            Text(settings.localized("translator_source_lang"))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            Button {
                                showSourcePicker = true
                            } label: {
                                HStack {
                                    Text(selectedSource.id == "auto" ? settings.localized("translator_auto_detect") : selectedSource.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .padding(10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)

                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                            .padding(.top, 18)

                        // Target
                        VStack(alignment: .leading, spacing: 4) {
                            Text(settings.localized("translator_target_lang"))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            Button {
                                showTargetPicker = true
                            } label: {
                                HStack {
                                    Text(selectedTarget.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .padding(10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Input area
                    VStack(alignment: .leading, spacing: 6) {
                        Text(settings.localized("translator_input_label"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                            if inputText.isEmpty {
                                Text(settings.localized("translator_input_hint"))
                                    .foregroundColor(.secondary)
                                    .padding(12)
                            }
                            TextEditor(text: $inputText)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color.clear)
                        }
                        .frame(minHeight: 130)
                    }

                    // Translate / Cancel button
                    if !modelLoaded {
                        Button { onNavigateToModels() } label: {
                            Label(settings.localized("translator_requires_gemma3n"), systemImage: "arrow.down.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else if isTranslating {
                        Button { cancel() } label: {
                            HStack {
                                ProgressView().tint(.white)
                                Text(settings.localized("translating_tap_to_cancel"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button { translate() } label: {
                            Text(settings.localized("translator_translate"))
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.accentColor.opacity(0.4) : Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // Result
                    if !translationResult.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(settings.localized("translator_result"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = translationResult
                                } label: {
                                    Label(settings.localized("feature_copy_result"), systemImage: "doc.on.doc")
                                        .font(.caption)
                                }
                            }

                            Text(translationResult)
                                .font(.body)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSourcePicker) {
            LanguagePickerSheet(
                title: settings.localized("translator_source_lang"),
                languages: kTranslationLanguages,
                includeAuto: true,
                autoLabel: settings.localized("translator_auto_detect"),
                selected: $selectedSource
            )
        }
        .sheet(isPresented: $showTargetPicker) {
            LanguagePickerSheet(
                title: settings.localized("translator_target_lang"),
                languages: kTranslationLanguages.filter { $0.id != "auto" },
                includeAuto: false,
                autoLabel: "",
                selected: $selectedTarget
            )
        }
    }
}

// MARK: - Language Picker Sheet
private struct LanguagePickerSheet: View {
    let title: String
    let languages: [TranslationLanguage]
    let includeAuto: Bool
    let autoLabel: String
    @Binding var selected: TranslationLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(languages) { lang in
                Button {
                    selected = lang
                    dismiss()
                } label: {
                    HStack {
                        Text(lang.id == "auto" ? autoLabel : lang.name)
                            .foregroundColor(.primary)
                        Spacer()
                        if selected.id == lang.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppSettings.shared.localized("done")) { dismiss() }
                }
            }
        }
    }
}
