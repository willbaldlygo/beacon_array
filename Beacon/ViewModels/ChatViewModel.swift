import Foundation
import SwiftUI

class ChatViewModel: ObservableObject {
    @Published var conversation: Conversation
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentInput = ""
    
    private let claudeService = ClaudeService()
    private let arrayService = ArrayService.shared // Assuming ArrayService is also singleton or accessible
    
    init() {
        self.conversation = Conversation(title: "New Chat")
    }
    
    @MainActor
    func sendMessage() async {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMsg = Message(role: .user, content: currentInput)
        conversation.addMessage(userMsg)
        
        // Clear input immediately for UX
        let inputToSend = currentInput
        currentInput = ""
        isLoading = true
        error = nil
        
        do {
            let responseText = try await claudeService.sendMessage(
                userMessage: inputToSend,
                conversationHistory: conversation.messages
            )
            
            let assistantMsg = Message(role: .assistant, content: responseText)
            conversation.addMessage(assistantMsg)
            
            // Log to Array
            try await saveConversationToArray()
            
        } catch {
            self.error = error.localizedDescription
            // Optionally restore input or handle gracefully
        }
        
        isLoading = false
    }
    
    private func saveConversationToArray() async throws {
        _ = try await ArrayService.shared.saveConversation(conversation)
    }
    
    func clearChat() {
        conversation = Conversation(title: "New Chat")
    }
}
