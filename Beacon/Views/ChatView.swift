import SwiftUI

struct ChatView: View {
    @State private var messageText = ""
    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var showingSaveAlert = false
    @State private var saveResult: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Divider()
                        .background(AppTheme.ink)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(messages) { message in
                                    MondrianMessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding(.vertical, 24)
                            .padding(.horizontal, 16)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let lastMessage = messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Input Area
                    VStack(spacing: 0) {
                        Divider()
                            .background(AppTheme.ink)
                        
                        HStack(alignment: .bottom, spacing: 12) {
                            TextField("Enter message...", text: $messageText, axis: .vertical)
                                .font(.system(.body, design: .serif))
                                .textFieldStyle(.plain)
                                .padding(16)
                                .background(AppTheme.paper)
                                .overlay(
                                    Rectangle()
                                        .stroke(AppTheme.ink, lineWidth: 1)
                                )
                                .frame(minHeight: 50)
                            
                            Button {
                                sendMessage()
                            } label: {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(AppTheme.paper)
                                    .frame(width: 50, height: 50)
                                    .background(messageText.isEmpty ? Color.gray : AppTheme.accentRed)
                                    .overlay(
                                        Rectangle()
                                            .stroke(AppTheme.ink, lineWidth: 1)
                                    )
                            }
                            .disabled(messageText.isEmpty || isLoading)
                        }
                        .padding(16)
                        .background(AppTheme.background)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("BEACON")
                        .font(.system(.headline, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(AppTheme.ink)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveConversation()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundStyle(AppTheme.ink)
                    }
                    .disabled(messages.isEmpty)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        messages.removeAll()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(AppTheme.ink)
                    }
                }
            }
            .alert("STATUS", isPresented: $showingSaveAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveResult ?? "Conversation saved to Array.")
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let userMessage = Message(role: .user, content: messageText)
        messages.append(userMessage)
        
        let input = messageText
        messageText = ""
        isLoading = true
        
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            
            let response = Message(
                role: .assistant,
                content: "Beacon (Layer 1) acknowledges reception of: \"\(input)\"\n\nInference engine offline. Message logged."
            )
            
            await MainActor.run {
                messages.append(response)
                isLoading = false
            }
        }
    }
    
    private func saveConversation() {
        guard !messages.isEmpty else { return }
        
        Task {
            do {
                var conversation = Conversation(title: "Beacon Chat")
                for msg in messages {
                    conversation.addMessage(msg)
                }
                let result = try await ArrayService.shared.saveConversation(conversation)
                await MainActor.run {
                    saveResult = result.message
                    showingSaveAlert = true
                }
            } catch {
                await MainActor.run {
                    saveResult = "Error: \(error.localizedDescription)"
                    showingSaveAlert = true
                }
            }
        }
    }
}

struct MondrianMessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                // Label
                Text(message.role == .user ? "USER" : "SYSTEM")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.ink.opacity(0.6))
                    .padding(.horizontal, 4)
                
                // Content Card
                Text(message.content)
                    .font(.system(.body, design: message.role == .assistant ? .monospaced : .serif))
                    .fontWeight(.regular)
                    .shadow(radius: 0)
                    .foregroundStyle(AppTheme.ink)
                    .lineSpacing(4)
                    .padding(16)
                    .background(message.role == .user ? AppTheme.accentOchre : Color.white)
                    .overlay(
                        Rectangle()
                            .stroke(AppTheme.ink, lineWidth: 1)
                    )
            }
            
            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }
}
