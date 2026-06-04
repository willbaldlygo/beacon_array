import Foundation
import LiteRTLM

// MARK: - Errors

enum LocalModelError: LocalizedError {
    case modelNotDownloaded
    case engineInitFailed(String)
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "Gemma model not downloaded. Go to Settings → Local Model to download it."
        case .engineInitFailed(let msg):
            return "Failed to initialise Gemma engine: \(msg)"
        case .inferenceFailed(let msg):
            return "Gemma inference failed: \(msg)"
        }
    }
}

// MARK: - Manager

actor LocalModelManager {

    static let shared = LocalModelManager()

    private var engine: LiteRTLM.Engine?

    // MARK: - Configuration
    //
    // iOS runs ~3GB LiteRT-LM models at the edge of the per-app memory limit.
    // - CPU backend: ~961 MB resident, lazily memory-mapped. Safe on any device,
    //   no special entitlements needed. Slower decode.
    // - GPU backend: ~3,380 MB resident. Faster, but needs the increased-memory-limit
    //   and extended-virtual-addressing entitlements or it crashes at prefill with a
    //   null embedding-table pointer (EmbeddingLookupManager::LookupPrefill).
    // We default to CPU for reliability. A native EXC_BAD_ACCESS cannot be caught in
    // Swift, so the backend must be chosen correctly up front — there is no runtime fallback.
    private static let backend: LiteRTLM.Backend = .cpu()

    // Caps the KV-cache size to keep peak memory low. Enough for normal chat; PM-mode
    // prompts with full workflow docs may need raising (and will likely require GPU+entitlements).
    private static let maxNumTokens = 8192

    // MARK: - Model path

    static var modelURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("gemma-4-e4b.litertlm")
    }

    static var isModelPresent: Bool {
        FileManager.default.fileExists(atPath: modelURL.path)
    }

    /// The expected file is ~3.66 GB. Anything much smaller is a truncated download
    /// or an error/LFS-pointer page saved in its place — which would crash the native
    /// layer with an opaque error. Use this to fail loudly and clearly instead.
    static var modelFileSizeBytes: Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: modelURL.path)
        return (attrs?[.size] as? Int64) ?? 0
    }

    private static let minValidModelBytes: Int64 = 3_000_000_000  // 3 GB floor

    // MARK: - Engine lifecycle

    private func getEngine() async throws -> LiteRTLM.Engine {
        if let engine { return engine }

        guard LocalModelManager.isModelPresent else {
            throw LocalModelError.modelNotDownloaded
        }

        let size = LocalModelManager.modelFileSizeBytes
        guard size >= LocalModelManager.minValidModelBytes else {
            throw LocalModelError.engineInitFailed(
                "Model file looks incomplete (\(size / 1_000_000) MB, expected ~3660 MB). " +
                "Delete it in Settings → Local Model and download again."
            )
        }

        let cacheDir = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask)[0].path

        do {
            let config = try LiteRTLM.EngineConfig(
                modelPath: LocalModelManager.modelURL.path,
                backend: LocalModelManager.backend,
                maxNumTokens: LocalModelManager.maxNumTokens,
                cacheDir: cacheDir
            )
            let newEngine = LiteRTLM.Engine(engineConfig: config)
            try await newEngine.initialize()
            self.engine = newEngine
            return newEngine
        } catch {
            throw LocalModelError.engineInitFailed(error.localizedDescription)
        }
    }

    func unloadEngine() {
        engine = nil
    }

    // MARK: - Chat

    func generate(
        systemPrompt: String,
        history: [Message],
        userMessage: String
    ) async throws -> String {
        let engine = try await getEngine()

        do {
            // Pass system prompt and prior history via ConversationConfig so the model
            // receives them with proper role formatting rather than as a raw text blob.
            let systemMsg = LiteRTLM.Message(systemPrompt, role: .system)

            // ChatViewModel adds the current user message to history BEFORE calling here,
            // so history's last item is the message we're about to send. Drop it to
            // avoid sending it twice (once in initialMessages, once as the current turn).
            let historyMessages: [LiteRTLM.Message] = history
                .filter { $0.role != .system }
                .dropLast()
                .map { msg in
                    // LiteRT-LM uses .model for assistant turns (not .assistant)
                    let lmRole: LiteRTLM.Role = msg.role == .user ? .user : .model
                    return LiteRTLM.Message(msg.content, role: lmRole)
                }

            let convConfig = LiteRTLM.ConversationConfig(
                systemMessage: systemMsg,
                initialMessages: historyMessages
            )

            let conversation = try await engine.createConversation(with: convConfig)

            let userMsg = LiteRTLM.Message(userMessage, role: .user)
            let response = try await conversation.sendMessage(userMsg)
            return response.toString
        } catch let error as LocalModelError {
            // Unload on failure — a null return or exceeded KV cache can leave
            // the engine in a bad state. Next call will reinitialise cleanly.
            self.engine = nil
            throw error
        } catch {
            self.engine = nil
            throw LocalModelError.inferenceFailed(error.localizedDescription)
        }
    }

}
