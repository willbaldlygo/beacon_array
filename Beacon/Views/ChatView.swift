import SwiftUI

// Error handling improvement: Define reusable ChatError type for chat-related errors
enum ChatError: LocalizedError, Equatable {
    case missingAPIKey
    case networkFailure(String)
    case exportFailure(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "API key is missing."
        case .networkFailure(let reason): return "Network error: \(reason)"
        case .exportFailure(let reason): return "Export failed: \(reason)"
        case .unknown(let msg): return msg
        }
    }
}

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showingSaveAlert = false
    @State private var saveResult: ChatError?
    @State private var showingFilePicker = false
    @State private var showingURLInput = false
    @State private var urlInput = ""
    @State private var showingExportSheet = false
    @State private var exportTitle = ""
    @State private var exportTags = ""
    @State private var showingHistory = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                VStack(spacing: 0) {
                    Divider()
                        .background(AppTheme.primary)
                    
                    // PM Mode Banner
                    if viewModel.isPMMode {
                        HStack(spacing: 8) {
                            Image(systemName: "briefcase.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("PM MODE")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .tracking(2)
                            Spacer()
                            Button {
                                viewModel.exitPMMode()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                        .foregroundStyle(AppTheme.onSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.secondary)
                        .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
                    }
                    
                    MessageListView(viewModel: viewModel)
                    
                    ChatInputArea(
                        viewModel: viewModel,
                        showingFilePicker: $showingFilePicker,
                        showingURLInput: $showingURLInput,
                        urlInput: $urlInput
                    )
                }
            }
            .alert("Paste Link", isPresented: $showingURLInput) {
                TextField("URL", text: $urlInput)
                Button("Cancel", role: .cancel) { }
                Button("Add") {
                    if let url = URL(string: urlInput) {
                        Task {
                            await viewModel.ingestURL(url)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportSheet(
                    exportTitle: $exportTitle,
                    exportTags: $exportTags,
                    isPresented: $showingExportSheet,
                    onExport: { title, tags in
                        Task {
                            await viewModel.exportConversation(title: title, tags: tags)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingFilePicker) {
                FilePickerSheet(
                    isPresented: $showingFilePicker,
                    onAttach: { file in
                        viewModel.attachFile(file)
                    }
                )
            }
            .sheet(isPresented: $showingHistory) {
                ChatHistoryView { conversation in
                    viewModel.loadConversation(conversation)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                 Color.clear.frame(height: 0)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("BEACON")
                        .font(.system(.headline, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(AppTheme.primary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingHistory = true
                    } label: {
                        MondrianCircleIcon(color: AppTheme.primary.opacity(0.5), systemImage: "clock.arrow.circlepath")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    let isExportDisabled = viewModel.conversation.messages.isEmpty || viewModel.isLoading
                    Button(action: {
                        ConversationStore.shared.save(viewModel.conversation)
                        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
                        exportTitle = "Chat - \(dateString)"
                        exportTags = ""
                        showingExportSheet = true
                    }) {
                        MondrianCircleIcon(color: AppTheme.secondary, customImage: "floppy-disk")
                    }
                    .disabled(isExportDisabled)
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        ConversationStore.shared.save(viewModel.conversation)
                        viewModel.clearChat()
                    }) {
                        MondrianCircleIcon(color: AppTheme.secondary, systemImage: "square.and.pencil")
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

struct MessageListView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
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
                            .foregroundColor(AppTheme.error)
                            .padding()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                AppTheme.background
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.conversation.messages.count) { _, _ in
                if let lastMessage = viewModel.conversation.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct ChatInputArea: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var showingFilePicker: Bool
    @Binding var showingURLInput: Bool
    @Binding var urlInput: String
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppTheme.primary)
            
            // Attached Context Stack
            if !viewModel.attachedContext.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.attachedContext) { file in
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.primary)
                                Text(file.name)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(AppTheme.primary)
                                
                                Button {
                                    viewModel.removeFile(file)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(AppTheme.primary)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(AppTheme.surfaceContainerLowest)
                            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                // Attach Button — hidden in PM mode (attachments not applicable)
                if !viewModel.isPMMode {
                    Menu {
                        Button {
                            showingFilePicker = true
                        } label: {
                            Label("Attach File", systemImage: "doc")
                        }

                        Button {
                            urlInput = ""
                            showingURLInput = true
                        } label: {
                            Label("Paste Link", systemImage: "link")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 44, height: 50)
                            .background(AppTheme.surfaceContainerLowest)
                            .overlay(
                                Rectangle()
                                    .stroke(AppTheme.primary, lineWidth: AppTheme.border)
                            )
                    }
                }
                
                TextField("Enter message...", text: $viewModel.currentInput, axis: .vertical)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(AppTheme.primary)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(AppTheme.surfaceContainerLowest)
                    .overlay(
                        Rectangle()
                            .stroke(AppTheme.primary, lineWidth: AppTheme.border)
                    )
                    .frame(minHeight: 50)
                
                Button {
                    Task {
                        await viewModel.sendMessage()
                    }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.onPrimary)
                        .frame(width: 50, height: 50)
                        .background(viewModel.currentInput.isEmpty ? Color.gray : AppTheme.error)
                }
                .disabled(viewModel.currentInput.isEmpty || viewModel.isLoading)
            }
            .padding(16)
            .background(AppTheme.background)
        }
    }
}

// MARK: - Sheet Views

struct ExportSheet: View {
    @Binding var exportTitle: String
    @Binding var exportTags: String
    @Binding var isPresented: Bool
    let onExport: (String, [String]) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Export Metadata")) {
                    TextField("Title", text: $exportTitle)
                    TextField("Tags (comma separated)", text: $exportTags)
                }
            }
            .navigationTitle("Export Chat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        let tags = exportTags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                        onExport(exportTitle, tags)
                        isPresented = false
                    }
                    .disabled(exportTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct FilePickerSheet: View {
    @Binding var isPresented: Bool
    let onAttach: (FileContent) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    FileBrowserView(path: "", mode: .picker) { selectedFile in
                        onAttach(selectedFile)
                        isPresented = false
                    }
                    .navigationTitle("All Files")
                } label: {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(AppTheme.tertiaryFixed)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "externaldrive")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppTheme.primary)
                            )
                        Text("Browse All Files")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(AppTheme.primary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(AppTheme.surfaceContainerLowest)
                
                NavigationLink {
                    FileBrowserView(path: "projects/constellation/beacon/logs", mode: .picker) { selectedFile in
                        onAttach(selectedFile)
                        isPresented = false
                    }
                    .navigationTitle("Chat Log")
                } label: {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(AppTheme.secondary)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white)
                            )
                        Text("Chat Log")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(AppTheme.primary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(AppTheme.surfaceContainerLowest)
                
                NavigationLink {
                    FileBrowserView(path: "knowledge/inbox", mode: .picker) { selectedFile in
                        onAttach(selectedFile)
                        isPresented = false
                    }
                    .navigationTitle("Inbox")
                } label: {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(AppTheme.error)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "tray.and.arrow.down")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white)
                            )
                        Text("Inbox")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(AppTheme.primary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(AppTheme.surfaceContainerLowest)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Attach File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Components

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
                    .foregroundStyle(AppTheme.primary.opacity(0.6))
                    .padding(.horizontal, 4)
                
                // Content Card
                Text(message.content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .fontWeight(.regular)
                    .shadow(radius: 0)
                    .foregroundStyle(AppTheme.primary)
                    .lineSpacing(4)
                    .padding(16)
                    .background(message.role == .user ? AppTheme.tertiaryFixed : AppTheme.surfaceContainerLowest)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.primary, lineWidth: AppTheme.border)
                    )
            }
            
            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }
}

// Visual-only component for toolbar icons
struct MondrianCircleIcon: View {
    let color: Color
    var systemImage: String? = nil
    var customImage: String? = nil

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 36, height: 36)
            .overlay {
                if let name = systemImage {
                    Image(systemName: name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                } else if let name = customImage {
                    Image(name)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.white)
                }
            }
    }
}
