import SwiftUI

struct ChatHistoryView: View {
    @ObservedObject private var store = ConversationStore.shared
    let onLoad: (Conversation) -> Void
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if store.conversations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundStyle(AppTheme.primary.opacity(0.3))
                        Text("NO SAVED CHATS")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.primary.opacity(0.4))
                    }
                } else {
                    List {
                        ForEach(store.conversations) { conversation in
                            Button {
                                onLoad(conversation)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(conversation.title.uppercased())
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(AppTheme.primary)
                                        .lineLimit(1)
                                    HStack(spacing: 12) {
                                        Text("\(conversation.messages.count) MSG\(conversation.messages.count == 1 ? "" : "S")")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(AppTheme.primary.opacity(0.5))
                                        Text(Self.dateFormatter.string(from: conversation.updatedAt).uppercased())
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(AppTheme.primary.opacity(0.5))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(AppTheme.surfaceContainerLowest)
                            .listRowSeparatorTint(AppTheme.primary.opacity(0.15))
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                store.delete(id: store.conversations[idx].id)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PAST CHATS")
                        .font(.system(.headline, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(AppTheme.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("DONE") { dismiss() }
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.secondary)
                }
            }
        }
    }
}
