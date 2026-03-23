import SwiftUI

// MARK: - Risk Level
private enum RiskLevel: String {
    case safe       = "SAFE"
    case lowRisk    = "LOW RISK"
    case mediumRisk = "MEDIUM RISK"
    case highRisk   = "HIGH RISK"
    case scam       = "SCAM/PHISHING"

    var color: Color {
        switch self {
        case .safe:                    return .green
        case .lowRisk, .mediumRisk:    return .yellow
        case .highRisk, .scam:         return .red
        }
    }

    var icon: String {
        switch self {
        case .safe:       return "checkmark.shield.fill"
        case .lowRisk:    return "exclamationmark.shield.fill"
        case .mediumRisk: return "exclamationmark.shield.fill"
        case .highRisk:   return "xmark.shield.fill"
        case .scam:       return "xmark.shield.fill"
        }
    }

    static func parse(from text: String) -> RiskLevel? {
        let upper = text.uppercased()
        if upper.contains("SCAM") || upper.contains("PHISHING") { return .scam }
        if upper.contains("HIGH RISK") { return .highRisk }
        if upper.contains("MEDIUM RISK") { return .mediumRisk }
        if upper.contains("LOW RISK") { return .lowRisk }
        if upper.contains("SAFE") { return .safe }
        return nil
    }
}

// MARK: - ScamDetectorScreen
struct ScamDetectorScreen: View {
    @EnvironmentObject var settings: AppSettings

    var onNavigateBack: () -> Void
    var onNavigateToModels: () -> Void

    @StateObject private var backend = LLMBackend.shared
    @State private var inputText: String = ""
    @State private var resultText: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var analysisTask: Task<Void, Never>?
    @State private var parsedRisk: RiskLevel? = nil

    private var modelLoaded: Bool { backend.isLoaded }

    private let systemPrompt =
        "You are a cybersecurity expert specializing in scam and phishing detection. " +
        "Analyze the following content and provide: " +
        "1) A risk level (SAFE, LOW RISK, MEDIUM RISK, HIGH RISK, or SCAM/PHISHING) " +
        "2) A brief explanation of what you found " +
        "3) Key red flags or reassuring signs. Be concise and clear.\n\nContent to analyze:\n\n"

    private func analyze() {
        guard modelLoaded, !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        resultText = ""
        parsedRisk = nil
        isAnalyzing = true
        analysisTask = Task {
            do {
                let prompt = systemPrompt + inputText
                try await LLMBackend.shared.generate(prompt: prompt) { partial, _, _ in
                    Task { @MainActor in
                        resultText = partial
                        parsedRisk = RiskLevel.parse(from: partial)
                    }
                }
            } catch {
                await MainActor.run { resultText = error.localizedDescription }
            }
            await MainActor.run { isAnalyzing = false }
        }
    }

    private func cancel() {
        analysisTask?.cancel()
        analysisTask = nil
        isAnalyzing = false
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
                Text(settings.localized("scam_detector_title"))
                    .font(.headline)
                Spacer()
                Button { inputText = ""; resultText = ""; parsedRisk = nil } label: {
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
                    // Input area
                    VStack(alignment: .leading, spacing: 6) {
                        Text(settings.localized("scam_detector_input_label"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                            if inputText.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(settings.localized("scam_detector_input_hint"))
                                        .foregroundColor(.secondary)
                                    Text(settings.localized("scam_detector_url_hint"))
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding(12)
                            }
                            TextEditor(text: $inputText)
                                .frame(minHeight: 130)
                                .padding(8)
                                .background(Color.clear)
                        }
                        .frame(minHeight: 140)
                    }

                    // Analyze / No-model button
                    if !modelLoaded {
                        Button { onNavigateToModels() } label: {
                            Label(settings.localized("scam_detector_no_model"), systemImage: "arrow.down.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else if isAnalyzing {
                        Button { cancel() } label: {
                            HStack {
                                ProgressView().tint(.white)
                                Text(settings.localized("scam_detector_analyzing"))
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button { analyze() } label: {
                            Label(settings.localized("scam_detector_analyze"), systemImage: "shield.lefthalf.filled")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.accentColor.opacity(0.4) : Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // Risk badge (shown as result builds)
                    if let risk = parsedRisk {
                        HStack(spacing: 10) {
                            Image(systemName: risk.icon)
                                .font(.title2)
                                .foregroundColor(risk.color)
                            Text(risk.rawValue)
                                .font(.headline.bold())
                                .foregroundColor(risk.color)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(risk.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Full result
                    if !resultText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(settings.localized("scam_detector_result"))
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
