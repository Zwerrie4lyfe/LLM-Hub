import SwiftUI

// MARK: - ImageGeneratorScreen
struct ImageGeneratorScreen: View {
    @EnvironmentObject var settings: AppSettings

    var onNavigateBack: () -> Void
    var onNavigateToModels: () -> Void

    @StateObject private var backend = LLMBackend.shared
    @State private var promptText: String = ""
    @State private var expandedPrompt: String = ""
    @State private var isGenerating: Bool = false
    @State private var generationTask: Task<Void, Never>?

    private var modelLoaded: Bool { backend.isLoaded }

    private let expansionSystemPrompt =
        "You are an expert AI image prompt engineer. Take the following image description and expand it into a " +
        "highly detailed, artistic image generation prompt suitable for Stable Diffusion. Include style, lighting, " +
        "composition, colors, mood, and technical details. Return only the enhanced prompt:\n\n"

    private func expandPrompt() {
        guard modelLoaded, !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        expandedPrompt = ""
        isGenerating = true
        generationTask = Task {
            do {
                let prompt = expansionSystemPrompt + promptText
                try await LLMBackend.shared.generate(prompt: prompt) { partial, _, _ in
                    Task { @MainActor in expandedPrompt = partial }
                }
            } catch {
                await MainActor.run { expandedPrompt = error.localizedDescription }
            }
            await MainActor.run { isGenerating = false }
        }
    }

    private func cancel() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
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
                Text(settings.localized("image_generator_title"))
                    .font(.headline)
                Spacer()
                Button { promptText = ""; expandedPrompt = "" } label: {
                    Text(settings.localized("feature_clear"))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero info card
                    ZStack {
                        LinearGradient(
                            colors: [Color(hex: "6a11cb"), Color(hex: "2575fc")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        VStack(spacing: 12) {
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.9))

                            Text(settings.localized("image_generator_title"))
                                .font(.title2.bold())
                                .foregroundColor(.white)

                            Text(settings.localized("image_generator_subtitle"))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                    }

                    // Info box about Android SD
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                        Text(settings.localized("image_generator_info"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Prompt input
                    VStack(alignment: .leading, spacing: 6) {
                        Text(settings.localized("image_generator_prompt_label"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                            if promptText.isEmpty {
                                Text(settings.localized("image_generator_prompt_hint"))
                                    .foregroundColor(.secondary)
                                    .padding(12)
                            }
                            TextEditor(text: $promptText)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color.clear)
                        }
                        .frame(minHeight: 110)
                    }

                    // Generate / Cancel button
                    if !modelLoaded {
                        Button { onNavigateToModels() } label: {
                            Label(settings.localized("writing_aid_no_model"), systemImage: "arrow.down.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else if isGenerating {
                        Button { cancel() } label: {
                            HStack {
                                ProgressView().tint(.white)
                                Text(settings.localized("image_generator_generating"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button { expandPrompt() } label: {
                            Label(settings.localized("image_generator_generate"), systemImage: "wand.and.stars")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Color.purple.opacity(0.4)
                                        : Color.purple
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // Expanded prompt result
                    if !expandedPrompt.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(settings.localized("image_generator_prompt_label") + " (Expanded)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = expandedPrompt
                                } label: {
                                    Label(settings.localized("feature_copy_result"), systemImage: "doc.on.doc")
                                        .font(.caption)
                                }
                            }

                            Text(expandedPrompt)
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
