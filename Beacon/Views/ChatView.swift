import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
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
                                ForEach(viewModel.conversation.messages) { message in
                                    MondrianMessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                if viewModel.isLoading {
                                    HStack {
                                        ProgressView()
                                            .padding()
                                        Spacer()
                                    }
                                }
                                
                                if let error = viewModel.error {
                                    Text("Error: \(error)")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(AppTheme.accentRed)
                                        .padding()
                                }
                            }
                            .padding(.vertical, 24)
                            .padding(.horizontal, 16)
                        }
                        .onChange(of: viewModel.conversation.messages.count) { _, _ in
                            if let lastMessage = viewModel.conversation.messages.last {
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
                            TextField("Enter message...", text: $viewModel.currentInput, axis: .vertical)
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
                                Task {
                                    await viewModel.sendMessage()
                                }
                            } label: {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(AppTheme.paper)
                                    .frame(width: 50, height: 50)
                                    .background(viewModel.currentInput.isEmpty ? Color.gray : AppTheme.accentRed)
                                    .overlay(
                                        Rectangle()
                                            .stroke(AppTheme.ink, lineWidth: 1)
                                    )
                            }
                            .disabled(viewModel.currentInput.isEmpty || viewModel.isLoading)
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
                        // Manually triggering a save if desired, 
                        // though ViewModel logs to array after every message
                        // We could show "Saved" status instead
                    } label: {
                        Image(systemName: "icloud.and.arrow.up")
                            .foregroundStyle(AppTheme.ink.opacity(0.3)) // Disabled look as it's auto
                    }
                    .disabled(true)
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.clearChat()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(AppTheme.ink)
                    }
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
