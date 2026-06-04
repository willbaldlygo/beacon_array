import Foundation

/// Adapts LocalModelManager to the LLMService protocol.
/// The `model` parameter is ignored — always uses the downloaded Gemma 4 E4B.
class GemmaService: LLMService {

    func sendMessage(
        userMessage: String,
        conversationHistory: [Message],
        systemPrompt: String,
        model: String
    ) async throws -> String {
        try await LocalModelManager.shared.generate(
            systemPrompt: systemPrompt,
            history: conversationHistory,
            userMessage: userMessage
        )
    }
}
