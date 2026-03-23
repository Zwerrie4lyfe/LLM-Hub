import SwiftUI

// MARK: - Saved Creator model
struct SavedCreator: Identifiable, Codable {
    var id: String
    var name: String
    var systemPrompt: String
    var createdAt: String
}

// MARK: - CreatorGenerationScreen
struct CreatorGenerationScreen: View {
    @EnvironmentObject var settings: AppSettings

    var onNavigateBack: () -> Void
    var onNavigateToModels: () -> Void
    var onNavigateToChat: () -> Void

    @StateObject private var backend = LLMBackend.shared
    @State private var descriptionText: String = ""
    @State private var generatedPrompt: String = ""
    @State private var isGenerating: Bool = false
    @State private var generationTask: Task<Void, Never>?
    @State private var savedCreators: [SavedCreator] = []
    @State private var creatorToDelete: SavedCreator? = nil
    @State private var showDeleteAlert: Bool = false

    private var modelLoaded: Bool { backend.isLoaded }

    private let systemPromptPrefix =
        "You are an AI persona designer. The user wants to create a custom AI assistant. " +
        "Generate a detailed PCTF (Persona, Context, Task, Format) system prompt based on their description. " +
        "The system prompt should define who the AI is, its expertise, how it behaves, and how it formats responses. " +
        "Make it detailed and effective. Return only the system prompt text.\n\nUser's description: "

    private func generatePersona() {
        guard modelLoaded, !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        generatedPrompt = ""
        isGenerating = true
        generationTask = Task {
            do {
                let prompt = systemPromptPrefix + descriptionText
                try await LLMBackend.shared.generate(prompt: prompt) { partial, _, _ in
                    Task { @MainActor in generatedPrompt = partial }
                }
            } catch {
                await MainActor.run { generatedPrompt = error.localizedDescription }
            }
            await MainActor.run { isGenerating = false }
        }
    }

    private func cancel() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    private func saveAndChat() {
        guard !generatedPrompt.isEmpty else { return }
        let creator = makeCreator(from: generatedPrompt)
        saveCreator(creator)
        UserDefaults.standard.set(generatedPrompt, forKey: "pending_creator_prompt")
        onNavigateToChat()
    }

    private func saveCreator(_ creator: SavedCreator) {
        var list = loadCreators()
        list.insert(creator, at: 0)
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "saved_creators")
        }
        savedCreators = list
    }

    private func loadCreators() -> [SavedCreator] {
        guard let data = UserDefaults.standard.data(forKey: "saved_creators"),
              let list = try? JSONDecoder().decode([SavedCreator].self, from: data)
        else { return [] }
        return list
    }

    private func deleteCreator(_ creator: SavedCreator) {
        var list = loadCreators()
        list.removeAll { $0.id == creator.id }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "saved_creators")
        }
        savedCreators = list
    }

    private func makeCreator(from prompt: String) -> SavedCreator {
        let firstLine = prompt.components(separatedBy: "\n").first ?? ""
        let name = String(firstLine.prefix(30)).trimmingCharacters(in: .whitespaces)
        let iso = ISO8601DateFormatter().string(from: Date())
        return SavedCreator(id: UUID().uuidString, name: name.isEmpty ? "Custom AI" : name, systemPrompt: prompt, createdAt: iso)
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
                Text(settings.localized("creator_screen_title"))
                    .font(.headline)
                Spacer()
                // Balance the back button
                Color.clear.frame(width: 60, height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Hero
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "8EC5FC"), Color(hex: "E0C3FC")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text(settings.localized("creator_bring_to_life"))
                            .font(.title2.bold())
                        Text(settings.localized("creator_description"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Prompt input
                    VStack(alignment: .leading, spacing: 6) {
                        Text(settings.localized("creator_prompt_label"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                            if descriptionText.isEmpty {
                                Text(settings.localized("creator_prompt_placeholder"))
                                    .foregroundColor(.secondary)
                                    .padding(12)
                            }
                            TextEditor(text: $descriptionText)
                                .frame(minHeight: 110)
                                .padding(8)
                                .background(Color.clear)
                        }
                        .frame(minHeight: 120)
                    }

                    // Generate / Cancel
                    if !modelLoaded {
                        Button { onNavigateToModels() } label: {
                            Label(settings.localized("creator_load_model_first"), systemImage: "arrow.down.circle")
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
                                Text(settings.localized("creator_brewing"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button { generatePersona() } label: {
                            Label(settings.localized("creator_generate_persona"), systemImage: "sparkles")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Color.purple.opacity(0.4)
                                        : Color.purple
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // Generated result
                    if !generatedPrompt.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(settings.localized("creator_result_heading"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.secondary)

                            Text(settings.localized("creator_system_prompt_label"))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(generatedPrompt)
                                .font(.body)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button { saveAndChat() } label: {
                                Label(settings.localized("creator_save_and_chat"), systemImage: "bubble.left.and.bubble.right.fill")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    // Saved creAItors list
                    if !savedCreators.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(settings.localized("drawer_my_creators"))
                                .font(.headline)
                                .padding(.top, 4)

                            ForEach(savedCreators) { creator in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.purple)
                                        .font(.title3)
                                        .frame(width: 32)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(creator.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text(creator.systemPrompt)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Button {
                                        creatorToDelete = creator
                                        showDeleteAlert = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    generatedPrompt = creator.systemPrompt
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            savedCreators = loadCreators()
        }
        .alert(settings.localized("dialog_delete_creator_title"), isPresented: $showDeleteAlert, presenting: creatorToDelete) { creator in
            Button(role: .destructive) {
                deleteCreator(creator)
            } label: {
                Text(settings.localized("delete"))
            }
            Button(settings.localized("cancel"), role: .cancel) {}
        } message: { creator in
            Text(settings.localized("dialog_delete_creator_message"))
        }
    }
}
