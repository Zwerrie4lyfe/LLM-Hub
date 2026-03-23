import SwiftUI

struct ContentView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(
                onNavigateToChat: { path.append(Screen.chat) },
                onNavigateToModels: { path.append(Screen.models) },
                onNavigateToSettings: { path.append(Screen.settings) },
                onNavigateToWritingAid: { path.append(Screen.writingAid) },
                onNavigateToTranslator: { path.append(Screen.translator) },
                onNavigateToTranscriber: { path.append(Screen.transcriber) },
                onNavigateToScamDetector: { path.append(Screen.scamDetector) },
                onNavigateToImageGenerator: { path.append(Screen.imageGenerator) },
                onNavigateToVibeCoder: { path.append(Screen.vibeCoder) },
                onNavigateToCreatorGeneration: { path.append(Screen.creatorGeneration) }
            )
            .navigationDestination(for: Screen.self) { screen in
                switch screen {
                case .chat:
                    ChatScreen(
                        onNavigateToSettings: { path.append(Screen.settings) },
                        onNavigateToModels: { path.append(Screen.models) },
                        onNavigateBack: { path.removeLast() }
                    )
                    .navigationBarBackButtonHidden(true)
                case .models:
                    ModelDownloadScreen(onNavigateBack: { path.removeLast() })
                        .navigationBarBackButtonHidden(true)
                case .settings:
                    SettingsScreen(
                        onNavigateBack: { path.removeLast() },
                        onNavigateToModels: { path.append(Screen.models) }
                    )
                    .navigationBarBackButtonHidden(true)
                case .writingAid:
                    WritingAidScreen(
                        onNavigateBack: { path.removeLast() },
                        onNavigateToModels: { path.append(Screen.models) }
                    )
                    .navigationBarBackButtonHidden(true)
                case .translator:
                    TranslatorScreen(
                        onNavigateBack: { path.removeLast() },
                        onNavigateToModels: { path.append(Screen.models) }
                    )
                    .navigationBarBackButtonHidden(true)
                case .transcriber:
                    TranscriberScreen(
                        onNavigateBack: { path.removeLast() },
                        onNavigateToModels: { path.append(Screen.models) }
                    )
                    .navigationBarBackButtonHidden(true)
                case .scamDetector:
                    ScamDetectorScreen(
                        onNavigateBack: { path.removeLast() },
                        onNavigateToModels: { path.append(Screen.models) }
                    )
                    .navigationBarBackButtonHidden(true)
                case .imageGenerator:
                    ImageGeneratorScreen(
                        onNavigateBack: { path.removeLast() },
                        onNavigateToModels: { path.append(Screen.models) }
                    )
                    .navigationBarBackButtonHidden(true)
                case .vibeCoder:
                    VibeCoderScreen(
                        onNavigateBack: { path.removeLast() },
                        onNavigateToModels: { path.append(Screen.models) }
                    )
                    .navigationBarBackButtonHidden(true)
                case .creatorGeneration:
                    CreatorGenerationScreen(
                        onNavigateBack: { path.removeLast() },
                        onNavigateToModels: { path.append(Screen.models) },
                        onNavigateToChat: { path.append(Screen.chat) }
                    )
                    .navigationBarBackButtonHidden(true)
                }
            }
        }
    }
}

enum Screen: Hashable {
    case chat
    case models
    case settings
    case writingAid
    case translator
    case transcriber
    case scamDetector
    case imageGenerator
    case vibeCoder
    case creatorGeneration
}
