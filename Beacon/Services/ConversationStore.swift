import Foundation
import Combine

class ConversationStore: ObservableObject {
    static let shared = ConversationStore()

    @Published private(set) var conversations: [Conversation] = []

    private let storeURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("beacon_chats.json")
    }()

    private init() {
        load()
    }

    func save(_ conversation: Conversation) {
        guard !conversation.messages.isEmpty else { return }
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx] = conversation
        } else {
            conversations.insert(conversation, at: 0)
        }
        persist()
    }

    func delete(id: UUID) {
        conversations.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([Conversation].self, from: data)
        else { return }
        conversations = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
