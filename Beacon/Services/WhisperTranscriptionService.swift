import Foundation
import WhisperKit

// MARK: - Errors

enum TranscriptionServiceError: LocalizedError {
    case emptyResult
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyResult:
            return "Whisper returned an empty transcription. The audio may be silent or too short."
        case .transcriptionFailed(let msg):
            return "Transcription failed: \(msg)"
        }
    }
}

// MARK: - Service

actor WhisperTranscriptionService {

    static let shared = WhisperTranscriptionService()

    // large-v3 turbo: best multilingual quality Argmax recommends, ~630 MB download.
    // Downloaded automatically by WhisperKit on first use and cached in app storage.
    static let modelName = "large-v3-v20240930_626MB"

    private var whisperKit: WhisperKit?

    // MARK: - Transcription

    func transcribe(audioFileURL: URL) async throws -> String {
        let kit = try await getWhisperKit()

        do {
            let results = try await kit.transcribe(audioPath: audioFileURL.path)
            let text = results.map(\.text).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw TranscriptionServiceError.emptyResult
            }
            return text
        } catch let error as TranscriptionServiceError {
            throw error
        } catch {
            throw TranscriptionServiceError.transcriptionFailed(error.localizedDescription)
        }
    }

    func unload() {
        whisperKit = nil
    }

    // MARK: - Private

    private func getWhisperKit() async throws -> WhisperKit {
        if let whisperKit { return whisperKit }
        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let downloadDir = appSupport.appendingPathComponent("whisperkit_models", isDirectory: true)
            try? FileManager.default.createDirectory(at: downloadDir, withIntermediateDirectories: true)

            let config = WhisperKitConfig(
                model: WhisperTranscriptionService.modelName,
                downloadBase: downloadDir
            )
            let kit = try await WhisperKit(config)
            self.whisperKit = kit
            return kit
        } catch {
            throw TranscriptionServiceError.transcriptionFailed(error.localizedDescription)
        }
    }
}
