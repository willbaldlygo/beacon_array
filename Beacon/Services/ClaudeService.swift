import Foundation

class ClaudeService: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"
    
    private let keychainKey = "anthropic_api_key"
    
    var hasAPIKey: Bool {
        KeychainHelper.get(key: keychainKey) != nil
    }
    
    func saveAPIKey(_ key: String) {
        KeychainHelper.save(key: keychainKey, value: key)
    }
    
    func getAPIKey() -> String? {
        KeychainHelper.get(key: keychainKey)
    }
    
    func removeAPIKey() {
        KeychainHelper.delete(key: keychainKey)
    }
    
    // MARK: - Chat
    
    func sendMessage(
        userMessage: String,
        conversationHistory: [Message],
        systemPrompt: String = "You are a helpful AI assistant for The Array knowledge system.",
        model: String = "claude-3-5-sonnet-20241022"
    ) async throws -> String {
        
        guard let apiKey = getAPIKey(), !apiKey.isEmpty else {
            throw ClaudeError.noAPIKey
        }
        
        // Fetch context from Array
        let recentSessions = try? await ArrayService.shared.getRecentSessions(limit: 3)
        let contextPrompt = buildContextPrompt(recentSessions: recentSessions)
        
        // Combine system prompt with context
        let fullSystemPrompt = systemPrompt + "\n\n" + contextPrompt
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        
        // Format messages for API
        // Filter out system messages from history as they go in system parameter
        let apiMessages = conversationHistory.filter { $0.role != .system }.map { msg -> [String: String] in
            return ["role": msg.role.rawValue, "content": msg.content]
        }
        
        // Add current user message
        var finalMessages = apiMessages
        finalMessages.append(["role": "user", "content": userMessage])
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": fullSystemPrompt,
            "messages": finalMessages
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            // Try to parse error
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObj = errorJson["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                throw ClaudeError.apiError(message: message)
            }
            throw ClaudeError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response
        let result = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        
        guard let content = result.content.first?.text else {
            throw ClaudeError.emptyResponse
        }
        
        return content
    }
    
    // MARK: - Context Builder
    
    private func buildContextPrompt(recentSessions: [Conversation]?) -> String {
        guard let sessions = recentSessions, !sessions.isEmpty else {
            return ""
        }
        
        var context = "## CONTEXT FROM RECENT SESSIONS\n"
        
        for session in sessions {
            context += "\n--- Session: \(session.title) (\(session.createdAt.formatted())) ---\n"
            // Take last 3 messages of each session for brevity
            let recentMessages = session.messages.suffix(3)
            for msg in recentMessages {
                context += "\(msg.role.rawValue.uppercased()): \(msg.content.prefix(200))...\n"
            }
        }
        
        return context
    }
}

// MARK: - Models

struct ClaudeResponse: Codable {
    let id: String
    let content: [ClaudeContent]
}

struct ClaudeContent: Codable {
    let type: String
    let text: String
}

enum ClaudeError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case httpError(statusCode: Int)
    case apiError(message: String)
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Anthropic API Key not found. Please add it in Settings."
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Claude API Error: \(code)"
        case .apiError(let msg):
            return "Claude API Error: \(msg)"
        case .emptyResponse:
            return "Claude returned an empty response"
        }
    }
}
