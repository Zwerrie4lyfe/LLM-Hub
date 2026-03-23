import SwiftUI

// MARK: - Writing Aid Mode
enum WritingMode: String, CaseIterable, Identifiable {
    case grammar, paraphrase, tone, email, sms
    var id: String { rawValue }

    func localizedKey() -> String {
        switch self {
        case .grammar:    return "writing_aid_mode_grammar"
        case .paraphrase: return "writing_aid_mode_paraphrase"
        case .tone:       return "writing_aid_mode_tone"
        case .email:      return "writing_aid_mode_email"
        case .sms:        return "writing_aid_mode_sms"
        }
    }
}

enum WritingTone: String, CaseIterable, Identifiable {
    case friendly, professional, concise
    var id: String { rawValue }

    func localizedKey() -> String {
        switch self {
        case .friendly:     return "writing_aid_tone_friendly"
        case .professional: return "writing_aid_tone_professional"
        case .concise:      return "writing_aid_tone_concise"
        }
    }
}

// MARK: - WritingAidScreen
struct WritingAidScreen: View {
    @EnvironmentObject var settings: AppSettings

    var onNavigateBack: () -> Void
    var onNavigateToModels: () -> Void

    @StateObject private var backend = LLMBackend.shared
    @State private var inputText: String = ""
    @State private var resultText: String = ""
    @State private var selectedMode: WritingMode = .grammar
    @State private var selectedTone: WritingTone = .friendly
    @State private var isProcessing: Bool = false
    @State private var processingTask: Task<Void, Never>?

    private var modelLoaded: Bool { backend.isLoaded }
    private var inputHintKey: String { modelLoaded ? "writing_aid_input_hint" : "writing_aid_input_hint_no_model" }

    private func buildPrompt() -> String {
        let prefix: String
        switch selectedMode {
        case .grammar:
            prefix = "You are a professional writing assistant. Fix the grammar, spelling, and punctuation in the following text. Return only the corrected text without explanation:\n\n"
        case .paraphrase:
            prefix = "You are a professional writing assistant. Rewrite the following text in a fresh, clear way while preserving the original meaning. Return only the rewritten text:\n\n"
        case .tone:
            switch selectedTone {
            case .friendly:
                prefix = "Rewrite the following text in a friendly, warm tone. Return only the rewritten text:\n\n"
            case .professional:
                prefix = "Rewrite the following text in a professional, formal tone. Return only the rewritten text:\n\n"
            case .concise:
                prefix = "Rewrite the following text as concisely as possible, removing all unnecessary words. Return only the rewritten text:\n\n"
            }
        case .email:
            prefix = "You are a professional email writer. Write a professional email reply to the following message. Return only the email text:\n\n"
        case .sms:
            prefix = "Write a brief, friendly SMS reply to the following message. Keep it short and casual. Return only the reply:\n\n"
        }
        return prefix + inputText
    }

    private func process() {
        guard modelLoaded, !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        resultText = ""
        isProcessing = true
        processingTask = Task {
            do {
                let prompt = buildPrompt()
                try await LLMBackend.shared.generate(prompt: prompt) { partial, _, _ in
                    Task { @MainActor in
                        resultText = partial
                    }
                }
            } catch {
                await MainActor.run { resultText = error.localizedDescription }
            }
            await MainActor.run { isProcessing = false }
        }
    }

    private func cancel() {
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false
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
                Text(settings.localized("writing_aid_title"))
                    .font(.headline)
                Spacer()
                Button { inputText = ""; resultText = "" } label: {
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
                    // Mode picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(settings.localized("writing_aid_select_mode"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(WritingMode.allCases) { mode in
                                    Button {
                                        selectedMode = mode
                                    } label: {
                                        Text(settings.localized(mode.localizedKey()))
                                            .font(.subheadline)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(selectedMode == mode ? Color.accentColor : Color(.secondarySystemBackground))
                                            .foregroundColor(selectedMode == mode ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        if selectedMode == .tone {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(WritingTone.allCases) { tone in
                                        Button {
                                            selectedTone = tone
                                        } label: {
                                            Text(settings.localized(tone.localizedKey()))
                                                .font(.subheadline)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 7)
                                                .background(selectedTone == tone ? Color.purple : Color(.secondarySystemBackground))
                                                .foregroundColor(selectedTone == tone ? .white : .primary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Input area
                    VStack(alignment: .leading, spacing: 6) {
                        Text(settings.localized("writing_aid_input_label"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                            if inputText.isEmpty {
                                Text(settings.localized(inputHintKey))
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

                    // Process / Cancel button
                    if !modelLoaded {
                        Button { onNavigateToModels() } label: {
                            Label(settings.localized("writing_aid_no_model"), systemImage: "arrow.down.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else if isProcessing {
                        Button { cancel() } label: {
                            HStack {
                                ProgressView()
                                    .tint(.white)
                                Text(settings.localized("feature_processing"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button { process() } label: {
                            Text(settings.localized("writing_aid_process"))
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.accentColor.opacity(0.4) : Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // Result area
                    if !resultText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(settings.localized("writing_aid_result"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = resultText
                                } label: {
                                    Label(settings.localized("feature_copy_result"), systemImage: "doc.on.doc")
                                        .font(.caption)
                                }
                            }

                            Text(resultText)
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
    }
}
