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
    
    // MARK: - Status
    
    /// Check if The Array is online and get status info
    func getStatus() async throws -> ArrayStatus {
        let url = URL(string: "\(baseURL)/api/v1/status")!
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try decoder.decode(ArrayStatus.self, from: data)
    }
    
    // MARK: - Ingest
    
    /// Save a note or artifact to The Array inbox
    func ingest(_ request: IngestRequest) async throws -> IngestResponse {
        let url = URL(string: "\(baseURL)/api/v1/ingest")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        try validateResponse(response)
        return try decoder.decode(IngestResponse.self, from: data)
    }
    
    /// Save a simple note to The Array
    func saveNote(title: String, content: String, tags: [String] = []) async throws -> IngestResponse {
        let request = IngestRequest(
            sourceType: "note",
            title: title,
            content: content,
            device: "beacon",
            tags: tags
        )
        return try await ingest(request)
    }
    
    /// Save a conversation as a trace to The Array
    func saveConversation(_ conversation: Conversation) async throws -> IngestResponse {
        let content = conversation.messages.map { msg in
            "**\(msg.role.rawValue.capitalized)**: \(msg.content)"
        }.joined(separator: "\n\n")
        
        let request = IngestRequest(
            sourceType: "session_trace",
            title: "Beacon Conversation - \(conversation.title)",
            content: content,
            device: "beacon",
            tags: ["beacon", "conversation", "trace"]
        )
        return try await ingest(request)
    }
    
    /// Get recent conversations for context
    func getRecentSessions(limit: Int = 5) async throws -> [Conversation] {
        let url = URL(string: "\(baseURL)/api/v1/sessions/recent?limit=\(limit)")!
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try decoder.decode([Conversation].self, from: data)
    }
    
    // MARK: - Queue
    
    /// Get items in the inbox queue
    func getQueue() async throws -> QueueResponse {
        let url = URL(string: "\(baseURL)/api/v1/ingest/queue")!
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try decoder.decode(QueueResponse.self, from: data)
    }
    
    // MARK: - Health
    
    /// Check ingest endpoint health
    func checkHealth() async throws -> Bool {
        let url = URL(string: "\(baseURL)/api/v1/ingest/health")!
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? String {
            return status == "ok"
        }
        return false
    }
    
    // MARK: - Helpers
    
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ArrayError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ArrayError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Errors

enum ArrayError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from The Array"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
