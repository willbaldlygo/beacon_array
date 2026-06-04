import Foundation

/// Service for the /log workflow.
/// On trigger: Claude synthesises the session into structured JSON + markdown,
/// then both are posted automatically — markdown to logs/, session row to sessions.db.
class LogWorkflowService {

    static let shared = LogWorkflowService()
    private let arrayService = ArrayService.shared
    private init() {}

    // MARK: - Command Detection

    static func isLogTrigger(_ input: String) -> Bool {
        let normalised = input
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return ["log", "log session", "arrayend", "end session", "projectend"]
            .contains(normalised)
    }

    // MARK: - Prompt Builder

    /// Builds the system prompt asking Claude to produce a structured log as a single JSON object.
    /// The JSON is parsed and used to write the markdown log and sessions.db entry automatically.
    static func buildLogSystemPrompt(conversationSummary: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, d MMMM yyyy"
        let currentDate = dateFormatter.string(from: Date())

        let datestamp = {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd"
            return f.string(from: Date())
        }()

        return """
        **Today's Date:** \(currentDate)
        **Interface:** Beacon (iOS) — Log Mode

        You are a session logger. Synthesise the conversation below into a structured session log.

        ## Conversation

        \(conversationSummary)

        ---

        ## Instructions

        Respond with a single JSON object. No preamble, no commentary, no markdown fences — raw JSON only.

        The JSON must match this exact structure:

        {
          "project": "<infer from conversation, or General>",
          "summary": "<2-3 sentence summary>",
          "context_for_next": "<handoff note for the next session — be specific about state>",
          "decisions": [
            { "what": "<decision>", "why": "<rationale>", "confidence": "high|medium|low" }
          ],
          "learnings": [
            { "topic": "<topic>", "insight": "<insight>" }
          ],
          "todos": [
            { "task": "<task>", "priority": "high|medium|low" }
          ],
          "file_changes": [
            { "path": "<relative path>", "action": "created|modified|deleted", "purpose": "<why>" }
          ],
          "markdown_log": "# Session Log: \(currentDate)\\n**Client:** Beacon\\n**Project:** <project>\\n\\n## Summary\\n<summary>\\n\\n## Decisions\\n- <decisions>\\n\\n## Next Session Focus\\n<context_for_next>"
        }

        Rules:
        - All arrays may be empty ([]) if nothing applies
        - The "markdown_log" value must be a valid JSON string (escape newlines as \\n)
        - The log filename will be: logs/beacon_\(datestamp)_<project-slug>.md
         Output raw JSON only — the app will parse it directly with JSONSerialization.
        Do NOT wrap the JSON in markdown code fences (no ```json). Just the JSON object, nothing else.
        """
    }

    // MARK: - Post to Array

    /// Parse Claude's JSON response and post both the markdown file and sessions.db entry.
    func postLog(jsonResponse: String) async throws -> String {
        // Strip markdown code fences if Claude wrapped the JSON despite instructions
        var cleaned = jsonResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            // Remove opening fence line (e.g. ```json or ```)
            if let newline = cleaned.range(of: "\n") {
                cleaned = String(cleaned[newline.upperBound...])
            }
            // Remove closing fence
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ Log: failed to parse JSON. Raw response: \(jsonResponse.prefix(300))")
            throw LogError.invalidJSON
        }

        let project = json["project"] as? String ?? "general"
        let contextForNext = json["context_for_next"] as? String
        let markdownLog = json["markdown_log"] as? String ?? jsonResponse

        // Build filename
        let datestamp = {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd"
            return f.string(from: Date())
        }()
        let slug = project.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
            .components(separatedBy: "_")
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        let logPath = "logs/beacon_\(datestamp)_\(slug).md"

        // Parse sub-arrays
        let decisions = (json["decisions"] as? [[String: Any]] ?? []).compactMap { d -> SessionDecision? in
            guard let what = d["what"] as? String, let why = d["why"] as? String else { return nil }
            return SessionDecision(what: what, why: why, confidence: d["confidence"] as? String ?? "medium")
        }
        let learnings = (json["learnings"] as? [[String: Any]] ?? []).compactMap { l -> SessionLearning? in
            guard let topic = l["topic"] as? String, let insight = l["insight"] as? String else { return nil }
            return SessionLearning(topic: topic, insight: insight)
        }
        let todos = (json["todos"] as? [[String: Any]] ?? []).compactMap { t -> SessionTodo? in
            guard let task = t["task"] as? String else { return nil }
            return SessionTodo(task: task, priority: t["priority"] as? String ?? "medium")
        }
        let fileChanges = (json["file_changes"] as? [[String: Any]] ?? []).compactMap { f -> SessionFileChange? in
            guard let path = f["path"] as? String, let action = f["action"] as? String else { return nil }
            return SessionFileChange(path: path, action: action, purpose: f["purpose"] as? String)
        }

        // 1. Write markdown log to logs/
        let writeResult = try await arrayService.writeFile(path: logPath, content: markdownLog)
        print("✅ Log written to \(writeResult.path) (\(writeResult.bytes_written) bytes)")

        // 2. Create sessions.db entry
        let sessionPayload = SessionCreate(
            client: "beacon",
            model: nil,
            project: project,
            durationMinutes: nil,
            decisions: decisions,
            learnings: learnings,
            todos: todos,
            artifactsCreated: [logPath],
            fileChanges: fileChanges,
            contextForNext: contextForNext
        )
        let sessionResult = try await arrayService.createSession(sessionPayload)
        print("✅ Session logged to sessions.db: \(sessionResult.id)")

        return "✅ Session logged:\n- `\(logPath)`\n- sessions.db entry `\(sessionResult.id)`"
    }
}

// MARK: - Errors

enum LogError: LocalizedError {
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Could not parse the session log JSON from Claude's response."
        }
    }
}
