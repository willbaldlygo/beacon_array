import Foundation

// MARK: - Models

struct ArrayStatus: Codable, Sendable {
    let status: String
    let version: String
    let hostname: String
    let uptimeSeconds: Double
    
    enum CodingKeys: String, CodingKey {
        case status, version, hostname
        case uptimeSeconds = "uptime_seconds"
    }
}

struct IngestRequest: Codable, Sendable {
    let sourceType: String
    let title: String
    var content: String?
    var summary: String?
    var sourceUrl: String?
    var device: String?
    var tags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case sourceType = "source_type"
        case title, content, summary
        case sourceUrl = "source_url"
        case device, tags
    }
    
    init(sourceType: String = "note", title: String, content: String? = nil, summary: String? = nil, sourceUrl: String? = nil, device: String = "beacon", tags: [String]? = nil) {
        self.sourceType = sourceType
        self.title = title
        self.content = content
        self.summary = summary
        self.sourceUrl = sourceUrl
        self.device = device
        self.tags = tags
    }
}

struct IngestResponse: Codable, Sendable {
    let success: Bool
    let message: String
    let filePath: String?
    let itemId: String?
    
    enum CodingKeys: String, CodingKey {
        case success, message
        case filePath = "file_path"
        case itemId = "item_id"
    }
}

struct QueueResponse: Codable, Sendable {
    let count: Int
    let items: [QueueItem]
}

struct QueueItem: Codable, Identifiable, Sendable {
    let file: String
    let title: String
    let sourceType: String
    let capturedAt: String
    let device: String?
    let status: String?
    var id: String { file }
    
    enum CodingKeys: String, CodingKey {
        case file, title, device, status
        case sourceType = "source_type"
        case capturedAt = "captured_at"
    }
}

struct Message: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    
    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [Message]
    let createdAt: Date
    var updatedAt: Date
    
    init(title: String = "New Conversation") {
        self.id = UUID()
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    mutating func addMessage(_ message: Message) {
        messages.append(message)
        updatedAt = Date()
    }
}

// MARK: - API Response Models

struct SessionsListResponse: Codable, Sendable {
    let count: Int
    let sessions: [SessionSummary]
}

struct SessionSummary: Codable, Identifiable, Sendable {
    let id: String
    let timestamp: String
    let client: String
    let project: String?
    let contextForNext: String?
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, client, project
        case contextForNext = "context_for_next"
    }
}

// MARK: - Session Create

struct SessionDecision: Codable, Sendable {
    let what: String
    let why: String
    let confidence: String
    init(what: String, why: String, confidence: String = "medium") {
        self.what = what; self.why = why; self.confidence = confidence
    }
}

struct SessionLearning: Codable, Sendable {
    let topic: String
    let insight: String
    let source: String?
    init(topic: String, insight: String, source: String? = nil) {
        self.topic = topic; self.insight = insight; self.source = source
    }
}

struct SessionTodo: Codable, Sendable {
    let task: String
    let priority: String
    let due: String?
    init(task: String, priority: String = "medium", due: String? = nil) {
        self.task = task; self.priority = priority; self.due = due
    }
}

struct SessionFileChange: Codable, Sendable {
    let path: String
    let action: String
    let purpose: String?
    enum CodingKeys: String, CodingKey { case path, action, purpose }
    init(path: String, action: String, purpose: String? = nil) {
        self.path = path; self.action = action; self.purpose = purpose
    }
}

struct SessionCreate: Codable, Sendable {
    let client: String
    let model: String?
    let project: String?
    let durationMinutes: Int?
    let decisions: [SessionDecision]
    let learnings: [SessionLearning]
    let todos: [SessionTodo]
    let artifactsCreated: [String]
    let fileChanges: [SessionFileChange]
    let contextForNext: String?

    enum CodingKeys: String, CodingKey {
        case client, model, project
        case durationMinutes = "duration_minutes"
        case decisions, learnings, todos
        case artifactsCreated = "artifacts_created"
        case fileChanges = "file_changes"
        case contextForNext = "context_for_next"
    }
}

struct SessionCreateResponse: Codable, Sendable {
    let id: String
    let timestamp: String
    let client: String
}


