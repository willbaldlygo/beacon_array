import SwiftUI

// MARK: - Design System

enum AppTheme {
    static let background = Color(hex: "F9F9F7") // Warm Paper
    static let ink = Color(hex: "1A1A1A")        // Deep Charcoal
    static let paper = Color(hex: "FFFFFF")      // Pure White (Elements on Background)
    static let accentRed = Color(hex: "C4443B")  // Satellite A: Terracotta Red
    static let accentBlue = Color(hex: "09737D") // Satellite B: Teal
    static let accentOchre = Color(hex: "DCA545") // Core: Yellow Ochre
    
    static let border: CGFloat = 1.0
    static let radius: CGFloat = 0.0 // Sharp corners for Mondrian look
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

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


