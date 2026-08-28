import Foundation

class ContextBuilder {

    /// The assistant's identity, reflecting which backend is actually serving the chat,
    /// so the model doesn't misrepresent itself (e.g. on-device Gemma claiming to be Claude).
    static var assistantIdentity: String {
        let backend = UserDefaults.standard.string(forKey: "selectedLLMBackend") ?? "claude"
        switch backend {
        case "gemma":
            return "You are Gemma 4 E4B, a local AI model running entirely on-device on Will's iPhone via Beacon — his mobile interface to The Array. You have no cloud connection; everything you process stays on the device."
        default:
            return "You are Claude, assisting Will via Beacon — his mobile interface to The Array."
        }
    }

    // Using QueueItem as it corresponds to InboxItem in the schema
    static func buildSystemPrompt(
        sessions: [SessionSummary],
        attachedFiles: [FileContent] = []
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, d MMMM yyyy"
        let currentDate = dateFormatter.string(from: Date())
        
        var prompt = """
        \(assistantIdentity)

        **Today's Date:** \(currentDate)
        
        \(UserProfile.shared.getFormattedProfile())
        
        \(TaskService.shared.getFormattedTasks())
        
        ## The Array
        The Array is Will's Raspberry Pi-based knowledge system. You have access to recent session context below.
        
        """
        
        // Add recent sessions
        if !sessions.isEmpty {
            prompt += "\n## Recent Sessions\n"
            for session in sessions.prefix(3) {
                prompt += "- [\(session.timestamp)] via \(session.client)"
                if let project = session.project {
                    prompt += " (project: \(project))"
                }
                if let context = session.contextForNext, !context.isEmpty {
                    prompt += "\n  Context: \(context)"
                }
                prompt += "\n"
            }
        }
        
        // Add attached files (User selected)
        if !attachedFiles.isEmpty {
            prompt += "\n## Attached Context\n"
            for file in attachedFiles {
                prompt += "\n### File: \(file.path)\n```\n\(file.content)\n```\n"
            }
        }
        
        prompt += """
        
        ## Your Role
        Help Will with whatever he needs. You can reference the context above when relevant, but don't force it. Focus on being genuinely useful.
        
        You are running on Beacon (iOS). When URLs are shared, their content is automatically fetched and included in the Attached Context section above — use it directly. You cannot browse the web live, but you can work with any content that has been attached.
        """
        
        return prompt
    }
    
    static func buildMinimalPrompt() -> String {
        return """
        \(assistantIdentity)

        Be concise and direct. Will has ADHD and values practical, actionable responses.
        Avoid unnecessary preamble and corporate speak.
        """
    }

    /// Prompt for Gemma — identity + attached files only.
    /// Skips session history and user profile to leave the KV cache free for conversation.
    /// Large files may still exceed the 8192-token budget and cause a null return.
    static func buildGemmaPrompt(attachedFiles: [FileContent] = []) -> String {
        var prompt = buildMinimalPrompt()

        if !attachedFiles.isEmpty {
            prompt += "\n\n## Attached Context"
            for file in attachedFiles {
                prompt += "\n### \(file.name)\n```\n\(file.content)\n```"
            }
        }

        return prompt
    }
    
    // MARK: - PM Workflow Prompt
    
    static func buildPMSystemPrompt(context: PMContext) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, d MMMM yyyy"
        let currentDate = dateFormatter.string(from: Date())
        
        var prompt = """
        **Today's Date:** \(currentDate)
        **Interface:** Beacon (iOS) — PM Mode
        
        \(UserProfile.shared.getFormattedProfile())
        
        ---
        
        # PM Workflow Instructions
        
        \(context.workflowDocument)
        
        ---
        
        # Current State
        
        ## Tasks (PM/tasks.md)
        
        \(context.tasks)
        
        ## Strategic Decisions (PM/decisions.md)
        
        \(context.decisions)
        
        """
        
        // Add recent session logs from the API
        if !context.recentSessions.isEmpty {
            prompt += "\n## Recent Sessions (from sessions.db)\n"
            for session in context.recentSessions {
                prompt += "- [\(session.timestamp)] via \(session.client)"
                if let project = session.project {
                    prompt += " (project: \(project))"
                }
                if let ctx = session.contextForNext, !ctx.isEmpty {
                    prompt += "\n  Context: \(ctx)"
                }
                prompt += "\n"
            }
        } else if let err = context.sessionsError {
            prompt += "\n## Recent Sessions (from sessions.db)\n"
            prompt += "⚠️ **sessions.db fetch failed** — diagnostic error: `\(err)`\n"
            prompt += "Please surface this error verbatim in your check-in response so Will can debug it.\n"
        } else {
            prompt += "\n## Recent Sessions (from sessions.db)\nNo sessions found.\n"
        }
        
        // Add recent markdown log files
        if !context.recentLogFiles.isEmpty {
            prompt += "\n## Recent Activity Logs (markdown)\n"
            for log in context.recentLogFiles {
                prompt += "\n### \(log.name)\n\(log.content)\n"
            }
        }
        
        prompt += """
        
        ---
        
        **IMPORTANT — Beacon Limitations:**
        You are running on Beacon (iOS), not a desktop agent. You cannot directly edit files. If task updates are needed, output the updated content in a fenced code block labelled `tasks.md` and Will can apply it.
        
        Begin the PM check-in now.
        """
        
        return prompt
    }
}

