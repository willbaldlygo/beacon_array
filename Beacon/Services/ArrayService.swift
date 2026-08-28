import Foundation

/// Service for communicating with The Array API
actor ArrayService {

    static let shared = ArrayService()

    private let baseURL = "https://array.baldlygo.uk"
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    private func getAPIKey() async throws -> String {
        let key: String? = await MainActor.run { KeychainHelper.get(key: "array_api_key") }
        guard let key, !key.isEmpty else { throw ArrayError.noAPIKey }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Status

    func getStatus() async throws -> ArrayStatus {
        let url = URL(string: "\(baseURL)/api/v1/status")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await getAPIKey())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try await MainActor.run { try decoder.decode(ArrayStatus.self, from: data) }
    }

    // MARK: - Ingest

    func ingest(_ request: IngestRequest) async throws -> IngestResponse {
        let url = URL(string: "\(baseURL)/api/v1/ingest")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(try await getAPIKey())", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try await MainActor.run { try encoder.encode(request) }

        let (data, response) = try await session.data(for: urlRequest)
        try validateResponse(response, data: data)
        return try await MainActor.run { try decoder.decode(IngestResponse.self, from: data) }
    }

    func saveNote(title: String, content: String, tags: [String] = []) async throws -> IngestResponse {
        let request = await MainActor.run {
            IngestRequest(sourceType: "note", title: title, content: content, device: "beacon", tags: tags)
        }
        return try await ingest(request)
    }

    func saveConversation(_ conversation: Conversation) async throws -> IngestResponse {
        let content = conversation.messages.map { msg in
            "**\(msg.role.rawValue.capitalized)**: \(msg.content)"
        }.joined(separator: "\n\n")

        let request = await MainActor.run {
            IngestRequest(sourceType: "session_trace", title: "Beacon Conversation - \(conversation.title)",
                          content: content, device: "beacon", tags: ["beacon", "conversation", "trace"])
        }
        return try await ingest(request)
    }

    func getRecentSessions(limit: Int = 5) async throws -> [SessionSummary] {
        let url = URL(string: "\(baseURL)/api/v1/sessions/recent?limit=\(limit)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await getAPIKey())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try await MainActor.run { try decoder.decode(SessionsListResponse.self, from: data) }.sessions
    }

    func createSession(_ payload: SessionCreate) async throws -> SessionCreateResponse {
        let url = URL(string: "\(baseURL)/api/v1/sessions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await getAPIKey())", forHTTPHeaderField: "Authorization")
        request.httpBody = try await MainActor.run { try encoder.encode(payload) }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try await MainActor.run { try decoder.decode(SessionCreateResponse.self, from: data) }
    }

    func writeFile(path: String, content: String) async throws -> WriteResponse {
        let url = URL(string: "\(baseURL)/api/v1/files/write")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await getAPIKey())", forHTTPHeaderField: "Authorization")
        request.httpBody = try await MainActor.run { try encoder.encode(WriteRequest(path: path, content: content, create_directories: true)) }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try await MainActor.run { try decoder.decode(WriteResponse.self, from: data) }
    }

    // MARK: - Queue

    func getQueue() async throws -> QueueResponse {
        let url = URL(string: "\(baseURL)/api/v1/ingest/queue")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await getAPIKey())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try await MainActor.run { try decoder.decode(QueueResponse.self, from: data) }
    }

    // MARK: - Health

    func checkHealth() async throws -> Bool {
        let url = URL(string: "\(baseURL)/api/v1/ingest/health")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try await getAPIKey())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? String {
            return status == "ok"
        }
        return false
    }

    // MARK: - URL Extraction

    /// Ask the Array to fetch and extract readable content from a URL
    /// using server-side Mozilla Readability.
    func extractURL(_ url: URL) async throws -> FileContent {
        guard var components = URLComponents(string: "\(baseURL)/api/v1/extract") else {
            throw ArrayError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]

        guard let requestURL = components.url else {
            throw ArrayError.invalidResponse
        }

        var request = URLRequest(url: requestURL)
        request.setValue("Bearer \(try await getAPIKey())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let result = try await MainActor.run {
            try JSONDecoder().decode(ExtractResponse.self, from: data)
        }

        return FileContent(
            path: result.url,
            name: result.title,
            content: result.content,
            size: result.contentLength,
            modified: ISO8601DateFormatter().string(from: Date())
        )
    }

    // MARK: - Helpers

    /// FastAPI reports errors as `detail`, which is a string for HTTPException
    /// and an object for the Manager's structured errors. Handle both.
    private static func detailMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = object["detail"] else { return nil }
        if let text = detail as? String { return text }
        if let structured = detail as? [String: Any],
           let message = structured["message"] as? String { return message }
        return nil
    }

    private func validateResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ArrayError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            // Surface what the server actually said. Discarding the body turned
            // TaskViewer's real failure into a bare "Array API error (400)" and
            // hid the cause for three weeks in August 2026. The Array's refusals
            // are written to be acted on -- a 403 from files/write names the
            // Manager tool to use instead -- and are worthless unseen.
            if let data, let detail = Self.detailMessage(from: data) {
                throw ArrayError.apiError(statusCode: httpResponse.statusCode, detail: detail)
            }
            throw ArrayError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Errors

enum ArrayError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(statusCode: Int, detail: String)
    case decodingError(Error)
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from The Array"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .apiError(_, let detail):
            return detail
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noAPIKey:
            return "Array API Key not found. Please add it in Settings."
        }
    }
}

// MARK: - Extract Response

struct ExtractResponse: Codable, Sendable {
    let title: String
    let content: String
    let url: String
    let contentLength: Int

    enum CodingKeys: String, CodingKey {
        case title, content, url
        case contentLength = "content_length"
    }
}
