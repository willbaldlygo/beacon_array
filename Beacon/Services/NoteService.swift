import Foundation
import Speech
import AVFoundation

class NoteService: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var transcribedText = ""
    @Published var error: String?
    
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    
    // Existing service
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
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    // MARK: - Transcription
    
    func transcribeRecording() async throws -> String {
        guard let audioURL = audioFileURL else {
            throw NoteError.noRecording
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw NoteError.speechRecognizerUnavailable
        }
        
        // Request authorization if needed
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard authStatus == .authorized else {
            throw NoteError.notAuthorized
        }
        
        DispatchQueue.main.async {
            self.isTranscribing = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.isTranscribing = false
            }
        }
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
    
    func submitAudioNote(title: String, tags: [String] = []) async throws {
        let transcription = try await transcribeRecording()
        
        DispatchQueue.main.async {
            self.transcribedText = transcription
        }
        
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
    case speechRecognizerUnavailable
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .noRecording:
            return "No recording found"
        case .speechRecognizerUnavailable:
            return "Speech recognition is not available"
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable in Settings."
        }
    }
}
