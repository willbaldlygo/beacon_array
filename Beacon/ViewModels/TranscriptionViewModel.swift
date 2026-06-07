import Foundation
import AVFoundation
import Combine

enum TranscriptionState: Equatable {
    case idle
    case recording
    case transcribing
    case done(String)
    case failed(String)
}

@MainActor
class TranscriptionViewModel: NSObject, ObservableObject {

    @Published var state: TranscriptionState = .idle
    @Published var savedToArray = false
    @Published var recordingSeconds: Int = 0
    @Published var audioLevel: Float = 0.0

    private var audioRecorder: AVAudioRecorder?
    private var currentRecordingURL: URL?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?

    // MARK: - Recording

    func requestMicPermissionAndRecord() async {
        let granted: Bool
        if #available(iOS 17, *) {
            granted = await AVAudioApplication.requestRecordPermission()
        } else {
            granted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
        guard granted else {
            state = .failed("Microphone permission denied. Enable it in Settings → Privacy → Microphone.")
            return
        }
        startRecording()
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            state = .failed("Audio session error: \(error.localizedDescription)")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            currentRecordingURL = url
            recordingSeconds = 0
            state = .recording
            startTimer()
        } catch {
            state = .failed("Failed to start recording: \(error.localizedDescription)")
        }
    }

    private func startTimer() {
        recordingSeconds = 0
        audioLevel = 0.0

        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, case .recording = self.state else { return }
                self.recordingSeconds += 1
            }
        }

        levelTimer?.invalidate()
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, case .recording = self.state, let recorder = self.audioRecorder else { return }
                recorder.updateMeters()
                let avg = recorder.averagePower(forChannel: 0)
                
                // Map dB scale (-50dB to 0dB) to normalized range (0.0 to 1.0)
                let minDb: Float = -50.0
                let normalizedLevel: Float
                if avg < minDb {
                    normalizedLevel = 0.0
                } else if avg >= 0.0 {
                    normalizedLevel = 1.0
                } else {
                    normalizedLevel = (avg - minDb) / (-minDb)
                }
                
                // Exponential decay smoothing
                self.audioLevel = self.audioLevel * 0.4 + normalizedLevel * 0.6
            }
        }
    }

    func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        // transcription triggered by AVAudioRecorderDelegate.audioRecorderDidFinishRecording
    }

    // MARK: - Transcription

    func transcribe(url: URL) async {
        state = .transcribing
        do {
            // WhisperKit decodes and resamples any AVFoundation-readable format internally.
            let text = try await WhisperTranscriptionService.shared.transcribe(audioFileURL: url)
            state = .done(text)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Save to Array

    func saveToArray(transcript: String) async {
        savedToArray = false
        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        do {
            _ = try await ArrayService.shared.saveNote(
                title: "Voicenote — \(dateString)",
                content: transcript,
                tags: ["beacon", "voicenote", "transcript"]
            )
            savedToArray = true
        } catch {
            state = .failed("Save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Reset

    func reset() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentRecordingURL = nil
        recordingSeconds = 0
        state = .idle
        savedToArray = false
        audioLevel = 0.0
    }
}

// MARK: - AVAudioRecorderDelegate

extension TranscriptionViewModel: AVAudioRecorderDelegate {

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let url = recorder.url
        Task { @MainActor [weak self] in
            if flag {
                await self?.transcribe(url: url)
            } else {
                self?.state = .failed("Recording did not complete successfully.")
            }
        }
    }
}
