import SwiftUI
import WebKit

// MARK: - WebView
struct WebView: UIViewRepresentable {
    let htmlContent: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow only local loads; block external navigation for sandboxing
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - VibeCoderScreen
struct VibeCoderScreen: View {
    @EnvironmentObject var settings: AppSettings

    var onNavigateBack: () -> Void
    var onNavigateToModels: () -> Void

    @StateObject private var backend = LLMBackend.shared
    @State private var promptText: String = ""
    @State private var generatedCode: String = ""
    @State private var isGenerating: Bool = false
    @State private var generationTask: Task<Void, Never>?
    @State private var isRefineMode: Bool = false
    @State private var showPreview: Bool = false

    private var modelLoaded: Bool { backend.isLoaded }

    private var isHTML: Bool {
        let lower = generatedCode.lowercased()
        return lower.contains("<!doctype html") || lower.contains("<html") || lower.contains("<body")
    }

    private let generationSystemPrompt =
        "You are an expert software developer. Generate clean, working code based on the user's description. " +
        "If the request is for a web app or visual interface, generate complete HTML/CSS/JavaScript in a single file. " +
        "If it's a Python script, generate clean Python. Add helpful comments. Return only the code without any explanation outside of code comments."

    private func buildPrompt() -> String {
        if isRefineMode && !generatedCode.isEmpty {
            return "You are an expert software developer. The user has existing code and wants to modify it. " +
                "Apply the requested changes and return the complete updated code. Return only the code.\n\n" +
                "Existing code:\n```\n\(generatedCode)\n```\n\nRequested change: \(promptText)"
        }
        return generationSystemPrompt + "\n\nUser request: " + promptText
    }

    private func generate() {
        guard modelLoaded, !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if !isRefineMode { generatedCode = "" }
        isGenerating = true
        generationTask = Task {
            do {
                let prompt = buildPrompt()
                try await LLMBackend.shared.generate(prompt: prompt) { partial, _, _ in
                    Task { @MainActor in generatedCode = partial }
                }
            } catch {
                await MainActor.run { generatedCode = error.localizedDescription }
            }
            await MainActor.run {
                isGenerating = false
                promptText = ""
            }
        }
    }

    private func cancel() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    private func clearAll() {
        generatedCode = ""
        promptText = ""
        isRefineMode = false
        showPreview = false
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
                Text(settings.localized("vibe_coder_title"))
                    .font(.headline)
                Spacer()
                Button { clearAll() } label: {
                    Text(settings.localized("vibe_coder_clear"))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            if showPreview && isHTML {
                // Web preview
                VStack(spacing: 0) {
                    HStack {
                        Button { showPreview = false } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        Text(settings.localized("vibe_coder_preview"))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    WebView(htmlContent: generatedCode)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Mode toggle
                        if !generatedCode.isEmpty {
                            HStack {
                                Toggle(isOn: $isRefineMode) {
                                    Label(settings.localized("vibe_coder_modification_mode"), systemImage: "pencil.and.outline")
                                        .font(.subheadline)
                                }
                                .toggleStyle(.switch)
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Prompt input
                        VStack(alignment: .leading, spacing: 6) {
                            Text(isRefineMode
                                 ? settings.localized("vibe_coder_refine")
                                 : settings.localized("vibe_coder_prompt_label"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.secondary)

                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                                if promptText.isEmpty {
                                    Text(settings.localized("vibe_coder_prompt_hint"))
                                        .foregroundColor(.secondary)
                                        .padding(12)
                                }
                                TextEditor(text: $promptText)
                                    .frame(minHeight: 90)
                                    .padding(8)
                                    .background(Color.clear)
                            }
                            .frame(minHeight: 100)
                        }

                        // Generate / Cancel
                        if !modelLoaded {
                            Button { onNavigateToModels() } label: {
                                Label(settings.localized("vibe_coder_no_model"), systemImage: "arrow.down.circle")
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
                                    Text(settings.localized("vibe_coder_stop_generation"))
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        } else {
                            Button { generate() } label: {
                                Label(
                                    isRefineMode
                                        ? settings.localized("vibe_coder_refine")
                                        : settings.localized("vibe_coder_generate"),
                                    systemImage: isRefineMode ? "pencil.and.outline" : "chevron.left.slash.chevron.right"
                                )
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Color.indigo.opacity(0.4)
                                        : Color.indigo
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        // Code display
                        if !generatedCode.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(settings.localized("vibe_coder_generated_code"))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if isHTML {
                                        Button {
                                            showPreview = true
                                        } label: {
                                            Label(settings.localized("vibe_coder_preview"), systemImage: "eye")
                                                .font(.caption)
                                        }
                                    }
                                    Button {
                                        UIPasteboard.general.string = generatedCode
                                    } label: {
                                        Label(settings.localized("vibe_coder_copy"), systemImage: "doc.on.doc")
                                            .font(.caption)
                                    }
                                }

                                ScrollView(.horizontal, showsIndicators: true) {
                                    Text(generatedCode)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.green)
                                        .padding(14)
                                        .frame(minWidth: 300, alignment: .leading)
                                }
                                .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationBarHidden(true)
    }
}
