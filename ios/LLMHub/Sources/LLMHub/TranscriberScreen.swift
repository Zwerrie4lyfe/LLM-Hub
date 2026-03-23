import AVFoundation
import Speech
import SwiftUI

// MARK: - TranscriberScreen
@MainActor
struct TranscriberScreen: View {
    @EnvironmentObject var settings: AppSettings

    var onNavigateBack: () -> Void
    var onNavigateToModels: () -> Void

    @StateObject private var backend = LLMBackend.shared
    @StateObject private var recorder = AudioRecorderManager()

    @State private var transcriptionResult: String = ""
    @State private var isTranscribing: Bool = false
    @State private var showFilePicker: Bool = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var durationTimer: Timer?

    private var modelLoaded: Bool { backend.isLoaded }

    private func startRecording() {
        recorder.startRecording()
        recordingDuration = 0
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in recordingDuration += 1 }
        }
    }

    private func stopRecordingAndTranscribe() {
        durationTimer?.invalidate()
        durationTimer = nil
        recorder.stopRecording()
        guard let url = recorder.recordedFileURL else { return }
        transcribeWithSpeech(url: url)
    }

    private func transcribeWithSpeech(url: URL) {
        isTranscribing = true
        transcriptionResult = ""
        Task {
            do {
                let result = try await SpeechTranscriber.transcribe(url: url)
                transcriptionResult = result
            } catch {
                transcriptionResult = error.localizedDescription
            }
            isTranscribing = false
        }
    }

    private func durationLabel(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
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
                Text(settings.localized("transcriber_title"))
                    .font(.headline)
                Spacer()
                Button {
                    transcriptionResult = ""
                    recorder.clearRecording()
                } label: {
                    Text(settings.localized("feature_clear"))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Record button area
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(recorder.isRecording ? Color.red : Color.accentColor)
                                .frame(width: 80, height: 80)
                                .shadow(color: (recorder.isRecording ? Color.red : Color.accentColor).opacity(0.4), radius: 10)

                            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                        }
                        .onTapGesture {
                            if recorder.isRecording {
                                stopRecordingAndTranscribe()
                            } else {
                                startRecording()
                            }
                        }

                        if recorder.isRecording {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text(settings.localized("transcriber_recording"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.red)
                                Text(durationLabel(recordingDuration))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Button { stopRecordingAndTranscribe() } label: {
                                Text(settings.localized("transcriber_stop"))
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        } else {
                            Text(settings.localized("transcriber_record"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity)

                    Divider().padding(.horizontal, 32)

                    // Upload button
                    Button {
                        showFilePicker = true
                    } label: {
                        Label(settings.localized("transcriber_upload"), systemImage: "folder")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                    .disabled(recorder.isRecording)

                    // Recording playback indicator
                    if let _ = recorder.recordedFileURL, !recorder.isRecording {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(settings.localized("transcriber_transcribe"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                    }

                    // Transcribing state
                    if isTranscribing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(settings.localized("transcribing"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }

                    // Permission warning
                    if recorder.permissionDenied {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(settings.localized("transcriber_microphone_permission"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 16)
                    }

                    // Result
                    if !transcriptionResult.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(settings.localized("transcriber_result"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = transcriptionResult
                                } label: {
                                    Label(settings.localized("feature_copy_result"), systemImage: "doc.on.doc")
                                        .font(.caption)
                                }
                            }

                            Text(transcriptionResult)
                                .font(.body)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 20)
                }
            }
        }
        .navigationBarHidden(true)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio, .mp3, .wav, .aiff, .mpeg4Audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                transcribeWithSpeech(url: url)
                if accessing { url.stopAccessingSecurityScopedResource() }
            case .failure:
                break
            }
        }
        .onDisappear {
            durationTimer?.invalidate()
            durationTimer = nil
            if recorder.isRecording { recorder.stopRecording() }
        }
    }
}

// MARK: - Audio Recorder Manager
@MainActor
final class AudioRecorderManager: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordedFileURL: URL? = nil
    @Published var permissionDenied: Bool = false

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    func startRecording() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                guard granted else {
                    self.permissionDenied = true
                    return
                }
                self.permissionDenied = false
                self.beginRecording()
            }
        }
    }

    private func beginRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: tempURL, settings: settings)
            audioRecorder?.record()
            recordingURL = tempURL
            isRecording = true
        } catch {
            isRecording = false
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordedFileURL = recordingURL
    }

    func clearRecording() {
        recordedFileURL = nil
        recordingURL = nil
    }
}

// MARK: - Speech Transcriber
enum SpeechTranscriber {
    static func transcribe(url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                guard status == .authorized else {
                    continuation.resume(throwing: NSError(
                        domain: "SpeechRecognizer",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized."]
                    ))
                    return
                }

                guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
                    continuation.resume(throwing: NSError(
                        domain: "SpeechRecognizer",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available."]
                    ))
                    return
                }

                let request = SFSpeechURLRecognitionRequest(url: url)
                request.shouldReportPartialResults = false
                request.requiresOnDeviceRecognition = true

                recognizer.recognitionTask(with: request) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if let result, result.isFinal {
                        continuation.resume(returning: result.bestTranscription.formattedString)
                    }
                }
            }
        }
    }
}
