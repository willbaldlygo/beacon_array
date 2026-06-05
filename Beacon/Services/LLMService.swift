import Foundation

/// Shared interface for all chat backends (Claude, Gemma, …).
///
/// **History contract:** `conversationHistory` must include the current user
/// turn as its final element (i.e. ChatViewModel adds the message *before*
/// calling here). Implementations are responsible for dropping that last entry
/// before building their own message list and sending `userMessage` as the
/// live turn. This mirrors how `LocalModelManager.generate` handles
/// `initialMessages` via `.dropLast()`.
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
