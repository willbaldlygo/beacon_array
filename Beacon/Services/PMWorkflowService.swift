import Foundation

/// All the context needed for a PM check-in session
struct PMContext {
    let workflowDocument: String
    let tasks: String
    let decisions: String
    let recentLogFiles: [FileContent]
    let recentSessions: [SessionSummary]
    let sessionsError: String?   // diagnostic: non-nil if session fetch failed
}

/// Service that fetches all PM context from the Array API
class PMWorkflowService {
    
    static let shared = PMWorkflowService()
    
    private let fileBrowser = FileBrowserService()
    private let arrayService = ArrayService.shared
    
    // PM file paths (relative to array root)
    private let workflowPath = "PM/.agent/workflows/pm.md"
    private let tasksPath = "PM/tasks.md"
    private let decisionsPath = "PM/decisions.md"
    private let logsDirectoryPath = "logs"
    
    private init() {}
    
    /// Fetch all PM context from the Array
    @MainActor
    func fetchPMContext() async throws -> PMContext {
        // Fetch all files concurrently
        async let workflowFetch = fileBrowser.readFile(path: workflowPath)
        async let tasksFetch = fileBrowser.readFile(path: tasksPath)
        async let decisionsFetch = fileBrowser.readFile(path: decisionsPath)
        async let sessionsFetch = arrayService.getRecentSessions(limit: 5)
        
        // Collect results — workflow and tasks are required, others are best-effort
        let workflow: FileContent
        let tasks: FileContent
        
        do {
            workflow = try await workflowFetch
        } catch {
            throw PMWorkflowError.workflowNotFound
        }
        
        do {
            tasks = try await tasksFetch
        } catch {
            throw PMWorkflowError.tasksNotFound
        }
        
        // Decisions and logs are optional
        let decisions: String
        do {
            let decisionsFile = try await decisionsFetch
            decisions = decisionsFile.content
        } catch {
            decisions = "(No decisions.md found)"
        }
        
        let sessions: [SessionSummary]
        let sessionsError: String?
        do {
            sessions = try await sessionsFetch
            sessionsError = nil
            print("✅ PMWorkflow: fetched \(sessions.count) session(s) from sessions.db")
        } catch {
            sessions = []
            sessionsError = error.localizedDescription
            print("❌ PMWorkflow: sessions fetch failed — \(error)")
        }
        
        // Fetch recent markdown log files from the logs directory
        let recentLogs = await fetchRecentLogs()
        
        return PMContext(
            workflowDocument: workflow.content,
            tasks: tasks.content,
            decisions: decisions,
            recentLogFiles: recentLogs,
            recentSessions: sessions,
            sessionsError: sessionsError
        )
    }
    
    /// Fetch the 3 most recent .md log files from the logs directory
    @MainActor
    private func fetchRecentLogs() async -> [FileContent] {
        // Load the logs directory listing
        await fileBrowser.loadDirectory(path: logsDirectoryPath)
        
        // Filter for .md files, take the most recent 3 (items are already sorted by modification time)
        let logFiles = fileBrowser.items
            .filter { !$0.isDirectory && ($0.fileExtension == ".md") }
            .prefix(3)
        
        // Fetch content for each
        var contents: [FileContent] = []
        for file in logFiles {
            do {
                let content = try await fileBrowser.readFile(path: file.path)
                contents.append(content)
            } catch {
                print("⚠️ Failed to read log file \(file.path): \(error.localizedDescription)")
            }
        }
        
        return contents
    }
    
    // MARK: - Command Detection
    
    /// Check if a message is a PM workflow trigger command
    static func isPMTrigger(_ input: String) -> Bool {
        // Normalise: lowercase, strip punctuation, collapse whitespace
        let normalised = input
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        let triggers = [
            "run project manager",
            "project manager",
            "pm",
            "run pm"
        ]
        
        return triggers.contains(normalised)
    }
}

// MARK: - Errors

enum PMWorkflowError: LocalizedError {
    case workflowNotFound
    case tasksNotFound
    case contextFetchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .workflowNotFound:
            return "Could not load PM workflow document from the Array (PM/.agent/workflows/pm.md)"
        case .tasksNotFound:
            return "Could not load tasks.md from the Array (PM/tasks.md)"
        case .contextFetchFailed(let detail):
            return "Failed to fetch PM context: \(detail)"
        }
    }
}
