import Foundation
import AVFoundation
import Combine

@MainActor
class NoteService: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var transcribedText = ""
    @Published var error: String?

    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?

    private let arrayService = ArrayService.shared

    // MARK: - Text Note

    func submitTextNote(title: String, content: String, tags: [String] = []) async throws {
        _ = try await arrayService.saveNote(title: title, content: content, tags: tags)
    }

    // MARK: - Audio Recording

    func startRecording() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        audioFileURL = documentsPath.appendingPathComponent("voice_note_\(Date().timeIntervalSince1970).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: audioFileURL!, settings: settings)
        audioRecorder?.record()
        isRecording = true
    }

    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
    }

    // MARK: - Transcription (on-device via WhisperKit)

    func transcribeRecording() async throws -> String {
        guard let audioURL = audioFileURL else {
            throw NoteError.noRecording
        }

        isTranscribing = true
        defer { isTranscribing = false }

        // WhisperKit decodes/resamples any AVFoundation-readable format internally.
        return try await WhisperTranscriptionService.shared.transcribe(audioFileURL: audioURL)
    }

    func submitAudioNote(title: String, tags: [String] = []) async throws {
        let transcription = try await transcribeRecording()
        transcribedText = transcription

        let request = IngestRequest(
            sourceType: "voice_note",
            title: title,
            content: transcription,
            device: "beacon-ios",
            tags: tags
        )
        _ = try await arrayService.ingest(request)

        // Clean up audio file
        if let url = audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

enum NoteError: Error, LocalizedError {
    case noRecording

    var errorDescription: String? {
        switch self {
        case .noRecording:
            return "No recording found"
        }
    }
}
