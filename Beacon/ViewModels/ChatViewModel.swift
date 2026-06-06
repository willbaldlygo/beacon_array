import Foundation
import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var conversation: Conversation
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentInput = ""
    @Published var isPMMode = false
    
    @Published var attachedContext: [FileContent] = []
    
    private let claudeService = ClaudeService()
    private let gemmaService = GemmaService()
    private let arrayService = ArrayService.shared

    private var isGemmaActive: Bool {
        (UserDefaults.standard.string(forKey: "selectedLLMBackend") ?? "claude") == "gemma"
    }

    private var activeLLMService: LLMService {
        isGemmaActive ? gemmaService : claudeService
    }
    private let contentExtractor = ContentExtractor.shared
    private let pmService = PMWorkflowService.shared
    private let logService = LogWorkflowService.shared
    
    init() {
        self.conversation = Conversation(title: "New Chat")
    }
    
    @MainActor
    func sendMessage() async {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 0. Check for workflow triggers
        if PMWorkflowService.isPMTrigger(currentInput) {
            await activatePMMode()
            return
        }
        
        if LogWorkflowService.isLogTrigger(currentInput) {
            await activateLogMode()
            return
        }
        
        // 1. Auto-detect URLs in user input and fetch their content
        let detectedURLs = detectURLs(in: currentInput)
        for url in detectedURLs {
            // Don't duplicate if already attached via the + button
            if !attachedContext.contains(where: { $0.path == url.absoluteString }) {
                do {
                    let content = try await contentExtractor.extract(from: url)
                    attachedContext.append(content)
                } catch {
                    print("⚠️ Failed to fetch URL \(url): \(error.localizedDescription)")
                }
            }
        }
        
        // 2. Build user message text — annotate if attachments exist
        var userMessageText = currentInput
        if !attachedContext.isEmpty {
            let attachmentLabels = attachedContext.map { file in
                return "[Attached: \(file.name) — \(file.path)]"
            }.joined(separator: "\n")
            userMessageText += "\n\n\(attachmentLabels)"
        }
        
        let userMsg = Message(role: .user, content: userMessageText)
        conversation.addMessage(userMsg)
        
        let inputToSend = userMessageText
        currentInput = ""
        isLoading = true
        error = nil
        
        // 3. Build System Prompt
        var systemPrompt: String
        
        if isPMMode {
            systemPrompt = pmSystemPrompt ?? ContextBuilder.buildMinimalPrompt()
        } else if isGemmaActive {
            // Gemma: include attached files but skip heavy session/profile context
            // to keep the KV cache free for conversation.
            systemPrompt = ContextBuilder.buildGemmaPrompt(attachedFiles: attachedContext)
        } else {
            systemPrompt = ContextBuilder.buildMinimalPrompt()

            let includeContext = UserDefaults.standard.bool(forKey: "includeArrayContext")
            let shouldInclude = UserDefaults.standard.object(forKey: "includeArrayContext") == nil ? true : includeContext

            if shouldInclude {
                do {
                    let sessions = try await arrayService.getRecentSessions(limit: 3)
                    systemPrompt = ContextBuilder.buildSystemPrompt(
                        sessions: sessions,
                        attachedFiles: attachedContext
                    )
                } catch {
                    print("⚠️ Context fetch failed: \(error.localizedDescription)")
                }
            }
        }
        
        // 4. Send — PM mode always uses Claude regardless of backend setting
        let llmService: LLMService = isPMMode ? claudeService : activeLLMService
        do {
            let responseText = try await llmService.sendMessage(
                userMessage: inputToSend,
                conversationHistory: conversation.messages,
                systemPrompt: systemPrompt
            )
            
            let assistantMsg = Message(role: .assistant, content: responseText)
            conversation.addMessage(assistantMsg)

        } catch {
            self.error = error.localizedDescription
        }

        // Clear attached files after sending (regardless of success/failure)
        attachedContext.removeAll()
        
        isLoading = false
    }
    
    // MARK: - PM Mode
    
    private var pmSystemPrompt: String?
    
    /// Activate PM mode: fetch all context and start the check-in
    @MainActor
    private func activatePMMode() async {
        let triggerText = currentInput
        currentInput = ""
        isLoading = true
        error = nil
        
        // Show the user's trigger in the conversation
        let userMsg = Message(role: .user, content: triggerText)
        conversation.addMessage(userMsg)
        
        do {
            // Fetch all PM context from the Array
            let context = try await pmService.fetchPMContext()
            
            // Build the PM system prompt and cache it for the session
            pmSystemPrompt = ContextBuilder.buildPMSystemPrompt(context: context)
            isPMMode = true
            
            // PM workflow always uses Claude — the prompt (workflow doc + tasks +
            // decisions + session logs) far exceeds Gemma's KV cache limit.
            let responseText = try await claudeService.sendMessage(
                userMessage: "Run the PM check-in workflow now. Read the context provided and conduct the check-in as described in the workflow instructions.",
                conversationHistory: conversation.messages,
                systemPrompt: pmSystemPrompt!
            )
            
            let assistantMsg = Message(role: .assistant, content: responseText)
            conversation.addMessage(assistantMsg)

        } catch {
            self.error = "PM Mode failed: \(error.localizedDescription)"
            isPMMode = false
            pmSystemPrompt = nil
        }
        
        isLoading = false
    }

    // MARK: - Log Mode

    /// Activate log mode: Claude synthesises the session into structured JSON,
    /// which is immediately posted to logs/ and sessions.db automatically.
    @MainActor
    private func activateLogMode() async {
        let triggerText = currentInput
        currentInput = ""
        isLoading = true
        error = nil

        let userMsg = Message(role: .user, content: triggerText)
        conversation.addMessage(userMsg)

        // Build plain-text conversation summary for Claude to work from
        let conversationSummary = conversation.messages
            .filter { $0.role != .system }
            .map { "**\($0.role == .user ? "USER" : "BEACON")**: \($0.content)" }
            .joined(separator: "\n\n---\n\n")

        let systemPrompt = LogWorkflowService.buildLogSystemPrompt(conversationSummary: conversationSummary)

        do {
            // Log workflow always uses Claude — requires strict JSON output and
            // large context (full conversation summary) that Gemma handles poorly.
            let jsonResponse = try await claudeService.sendMessage(
                userMessage: "Produce the session log JSON now.",
                conversationHistory: conversation.messages,
                systemPrompt: systemPrompt
            )

            // Post to Array (markdown file + sessions.db)
            let confirmation = try await logService.postLog(jsonResponse: jsonResponse)

            let assistantMsg = Message(role: .assistant, content: confirmation)
            conversation.addMessage(assistantMsg)

        } catch {
            let errMsg = Message(role: .assistant, content: "⚠️ Log failed: \(error.localizedDescription)")
            conversation.addMessage(errMsg)
        }

        isLoading = false
    }

    // MARK: - URL Detection
    
    /// Detect URLs in a text string using NSDataDetector
    private func detectURLs(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { $0.url }
    }
    
    private func saveConversationToArray() async throws {
        _ = try await ArrayService.shared.saveConversation(conversation)
    }
    
    func attachFile(_ file: FileContent) {
        // Prevent duplicates
        if !attachedContext.contains(where: { $0.path == file.path }) {
            attachedContext.append(file)
        }
    }
    
    func removeFile(_ file: FileContent) {
        attachedContext.removeAll(where: { $0.path == file.path })
    }
    
    func clearChat() {
        conversation = Conversation(title: "New Chat")
        attachedContext.removeAll()
        isPMMode = false
        pmSystemPrompt = nil
    }

    func exitPMMode() {
        isPMMode = false
        pmSystemPrompt = nil
        attachedContext.removeAll()
    }

    func loadConversation(_ conversation: Conversation) {
        self.conversation = conversation
        attachedContext.removeAll()
        isPMMode = false
        pmSystemPrompt = nil
    }
    
    @MainActor
    func ingestURL(_ url: URL) async {
        isLoading = true
        do {
            let content = try await contentExtractor.extract(from: url)
            attachFile(content)
        } catch {
            self.error = "Failed to ingest URL: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    @MainActor
    func exportConversation(title: String, tags: [String]) async {
        guard !conversation.messages.isEmpty else { return }
        
        isLoading = true
        
        // Build markdown content
        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short)
        var markdown = "# Beacon Chat Export\n\n"
        markdown += "**Date:** \(dateString)\n\n"
        markdown += "---\n\n"
        
        for msg in conversation.messages {
            let role = msg.role == .user ? "**USER**" : "**BEACON**"
            markdown += "\(role)\n\n\(msg.content)\n\n---\n\n"
        }
        
        // Send to inbox via ingest API
        do {
            _ = try await arrayService.saveNote(
                title: title,
                content: markdown,
                tags: tags + ["beacon", "chat-export"]
            )
        } catch {
            self.error = "Export failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
