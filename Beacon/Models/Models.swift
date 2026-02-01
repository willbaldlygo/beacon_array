import SwiftUI

// MARK: - Design System

enum AppTheme {
    static let background = Color(hex: "F9F9F7") // Warm Paper
    static let ink = Color(hex: "1A1A1A")        // Deep Charcoal
    static let paper = Color(hex: "FFFFFF")      // Pure White
    static let accentRed = Color(hex: "E63946")  // Primary Red
    static let accentBlue = Color(hex: "1D3557") // Deep Blue
    static let accentOchre = Color(hex: "DCA545") // User's Yellow Ochre
    
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

struct ArrayStatus: Codable {
    let status: String
    let version: String
    let hostname: String
    let uptimeSeconds: Double
    
    enum CodingKeys: String, CodingKey {
        case status, version, hostname
        case uptimeSeconds = "uptime_seconds"
    }
}

struct IngestRequest: Codable {
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

struct IngestResponse: Codable {
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

struct QueueResponse: Codable {
    let count: Int
    let items: [QueueItem]
}

struct QueueItem: Codable, Identifiable {
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
