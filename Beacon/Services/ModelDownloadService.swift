import Foundation
import Combine

// MARK: - Download state

enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)  // 0.0 – 1.0
    case downloaded
    case failed(String)
}

// MARK: - Service

@MainActor
class ModelDownloadService: NSObject, ObservableObject {

    static let shared = ModelDownloadService()

    @Published var state: ModelDownloadState = .notDownloaded

    // Hugging Face repo for Gemma 4 E4B LiteRT-LM.
    // NOTE: Gemma models on HF require accepting Google's terms of use.
    // If the download returns 401/403, supply your HF token in Settings.
    // Filename: verify against https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm
    private let downloadURL = URL(string:
        "https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm"
    )!

    private var downloadTask: URLSessionDownloadTask?
    private var urlSession: URLSession!
    private var resumeData: Data?

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 0  // no timeout for large file
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        refreshState()
    }

    func refreshState() {
        if LocalModelManager.isModelPresent {
            state = .downloaded
        } else if case .downloading = state {
            // keep current
        } else {
            state = .notDownloaded
        }
    }

    // MARK: - Download

    func startDownload(hfToken: String?) {
        guard case .notDownloaded = state else { return }

        state = .downloading(progress: 0)

        var request = URLRequest(url: downloadURL)
        request.timeoutInterval = 0
        if let token = hfToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        downloadTask = urlSession.downloadTask(with: request)
        downloadTask?.resume()
    }

    func resumeDownload(hfToken: String?) {
        if let data = resumeData {
            downloadTask = urlSession.downloadTask(withResumeData: data)
            downloadTask?.resume()
            resumeData = nil
        } else {
            state = .notDownloaded
            startDownload(hfToken: hfToken)
        }
    }

    func cancelDownload() {
        downloadTask?.cancel(byProducingResumeData: { [weak self] data in
            Task { @MainActor [weak self] in
                self?.resumeData = data
                self?.state = .notDownloaded
            }
        })
    }

    func deleteModel() {
        try? FileManager.default.removeItem(at: LocalModelManager.modelURL)
        Task { await LocalModelManager.shared.unloadEngine() }
        state = .notDownloaded
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloadService: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        Task { @MainActor [weak self] in
            self?.state = .downloading(progress: progress)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Reject non-200 responses — URLSessionDownloadTask fires this delegate
        // even for 404/403/503, which would save an HTML error page as the model.
        if let httpResponse = downloadTask.response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            Task { @MainActor [weak self] in
                self?.state = .failed("Server returned HTTP \(httpResponse.statusCode). Check your HF token or try again.")
            }
            return
        }

        let dest = LocalModelManager.modelURL
        do {
            let dir = dest.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: location, to: dest)
            Task { @MainActor [weak self] in
                self?.state = .downloaded
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.state = .failed(error.localizedDescription)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        let nsError = error as NSError
        // NSURLErrorCancelled means user tapped cancel — not a real failure
        guard nsError.code != NSURLErrorCancelled else { return }
        Task { @MainActor [weak self] in
            self?.state = .failed(error.localizedDescription)
        }
    }
}
