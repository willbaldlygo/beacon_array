import Foundation
import Combine

class ClaudeService: LLMService {
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
        model: String = "claude-haiku-4-5-20251001"
    ) async throws -> String {
        
        guard let rawKey = getAPIKey(), !rawKey.isEmpty else {
            throw ClaudeError.noAPIKey
        }
        let apiKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullSystemPrompt = systemPrompt
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        
        // Build message list from history, honouring the LLMService contract:
        // conversationHistory's last item is the current user turn (added by
        // ChatViewModel before calling here), so drop it to avoid duplication,
        // then append userMessage as the live turn.
        let apiMessages = conversationHistory
            .filter { $0.role != .system }
            .dropLast()
            .map { msg -> [String: String] in
                ["role": msg.role.rawValue, "content": msg.content]
            }

        var finalMessages = apiMessages
        finalMessages.append(["role": "user", "content": userMessage])
        
        let resolvedModel = model.isEmpty ? "claude-haiku-4-5-20251001" : model
        let body: [String: Any] = [
            "model": resolvedModel,
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
            #if DEBUG
            if let errorString = String(data: data, encoding: .utf8) {
                print("🔴 RAW API ERROR: \(errorString)")
            }
            #endif

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

