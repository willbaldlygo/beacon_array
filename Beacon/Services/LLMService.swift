import Foundation

protocol LLMService {
    func sendMessage(
        userMessage: String,
        conversationHistory: [Message],
        systemPrompt: String,
        model: String
    ) async throws -> String
}

extension LLMService {
    func sendMessage(
        userMessage: String,
        conversationHistory: [Message],
        systemPrompt: String
    ) async throws -> String {
        try await sendMessage(
            userMessage: userMessage,
            conversationHistory: conversationHistory,
            systemPrompt: systemPrompt,
            model: ""
        )
    }
}
