import SwiftUI

struct SettingsView: View {
    @State private var arrayStatus: ArrayStatus?
    @State private var isConnected = false
    @State private var isChecking = false
    @State private var lastChecked: Date?
    @State private var apiKey = ""
    @State private var showKey = false
    @State private var isSavingKey = false

    @State private var arrayApiKey = ""
    @State private var showArrayKey = false
    @State private var isSavingArrayKey = false

    @State private var showingCreateNote = false
    @State private var errorMessage: String?

    // Local model
    @StateObject private var downloadService = ModelDownloadService.shared
    @AppStorage("selectedLLMBackend") private var selectedBackend = "claude"
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                ScrollView {
                    VStack(spacing: 24) {
                        Divider().background(AppTheme.ink)
                            .padding(.bottom, 8)
                        
                        // Status Card
                        VStack(spacing: 0) {
                            HStack {
                                Text("SYSTEM STATUS")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppTheme.paper)
                                Spacer()
                                Circle()
                                    .fill(isConnected ? Color.green : AppTheme.accentRed)
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().stroke(AppTheme.paper, lineWidth: 1))
                            }
                            .padding(12)
                            .background(AppTheme.accentBlue)
                            .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 12) {
                                StatusRow(label: "CONNECTION", value: isConnected ? "ONLINE" : "OFFLINE")
                                if let status = arrayStatus {
                                    StatusRow(label: "HOSTNAME", value: status.hostname.uppercased())
                                    StatusRow(label: "VERSION", value: status.version)
                                }
                                
                                Button {
                                    Task { await checkConnection() }
                                } label: {
                                    HStack {
                                        Text(isChecking ? "PINGING..." : "TEST CONNECTION")
                                        Spacer()
                                        Image(systemName: "arrow.clockwise")
                                    }
                                }
                                .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentBlue))
                                .disabled(isChecking)
                                .padding(.top, 8)
                                
                                if let error = errorMessage {
                                    Text(error)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(AppTheme.accentRed)
                                        .padding(.vertical, 4)
                                        .fixedSize(horizontal: false, vertical: true) // Allow wrapping
                                }
                            }
                            .padding(16)
                            .background(AppTheme.paper)
                            .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
                        }
                        
                        // Quick Actions
                        SectionHeader(title: "QUICK ACTIONS")
                        
                        Button {
                            showingCreateNote = true
                        } label: {
                            HStack {
                                Image(systemName: "note.text")
                                Text("CREATE NOTE")
                                Spacer()
                            }
                        }
                        .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentBlue))
                        
                        // Configuration
                        SectionHeader(title: "CONFIGURATION")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ANTHROPIC API KEY")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.ink.opacity(0.6))
                            
                            HStack {
                                if showKey {
                                    TextField("sk-...", text: $apiKey)
                                        .font(.system(.body, design: .monospaced))
                                        .textFieldStyle(.plain)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .onSubmit {
                                            saveAPIKey()
                                        }
                                } else {
                                    SecureField("sk-...", text: $apiKey)
                                        .font(.system(.body, design: .monospaced))
                                        .textFieldStyle(.plain)
                                        .textInputAutocapitalization(.never)
                                        .onSubmit {
                                            saveAPIKey()
                                        }
                                }
                                
                                Button {
                                    showKey.toggle()
                                } label: {
                                    Image(systemName: showKey ? "eye.slash" : "eye")
                                        .foregroundStyle(AppTheme.ink.opacity(0.6))
                                }
                            }
                            .padding(12)
                            .background(AppTheme.accentOchre)
                            .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
                            
                            HStack(spacing: 12) {
                                Button(action: saveAPIKey) {
                                    HStack {
                                        Text(isSavingKey ? "SAVING..." : "SAVE KEY")
                                        if isSavingKey {
                                            ProgressView()
                                                .scaleEffect(0.5)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentBlue))
                                
                                Button(action: clearAPIKey) {
                                    Image(systemName: "trash")
                                        .frame(height: 44) // Match button height roughly
                                        .foregroundStyle(AppTheme.paper)
                                }
                                .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentRed))
                            }
                        }
                        .padding(16)
                        .background(AppTheme.paper)
                        .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ARRAY API KEY")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.ink.opacity(0.6))
                            
                            HStack {
                                if showArrayKey {
                                    TextField("default_unsafe_key...", text: $arrayApiKey)
                                        .font(.system(.body, design: .monospaced))
                                        .textFieldStyle(.plain)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .onSubmit {
                                            saveArrayAPIKey()
                                        }
                                } else {
                                    SecureField("default_unsafe_key...", text: $arrayApiKey)
                                        .font(.system(.body, design: .monospaced))
                                        .textFieldStyle(.plain)
                                        .textInputAutocapitalization(.never)
                                        .onSubmit {
                                            saveArrayAPIKey()
                                        }
                                }
                                
                                Button {
                                    showArrayKey.toggle()
                                } label: {
                                    Image(systemName: showArrayKey ? "eye.slash" : "eye")
                                        .foregroundStyle(AppTheme.ink.opacity(0.6))
                                }
                            }
                            .padding(12)
                            .background(AppTheme.accentOchre)
                            .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
                            
                            HStack(spacing: 12) {
                                Button(action: saveArrayAPIKey) {
                                    HStack {
                                        Text(isSavingArrayKey ? "SAVING..." : "SAVE KEY")
                                        if isSavingArrayKey {
                                            ProgressView()
                                                .scaleEffect(0.5)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentBlue))
                                
                                Button(action: clearArrayAPIKey) {
                                    Image(systemName: "trash")
                                        .frame(height: 44) // Match button height roughly
                                        .foregroundStyle(AppTheme.paper)
                                }
                                .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentRed))
                            }
                        }
                        .padding(16)
                        .background(AppTheme.paper)
                        .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
                        
                        // Local Model
                        SectionHeader(title: "LOCAL MODEL")

                        LocalModelSection(
                            downloadService: downloadService,
                            selectedBackend: $selectedBackend
                        )

                        // About
                        SectionHeader(title: "ABOUT BEACON")
                        
                        VStack(alignment: .leading, spacing: 0) {
                            AboutRow(label: "VERSION", value: "1.0 (LAYER 1)")
                            Divider().background(AppTheme.ink)
                            AboutRow(label: "PROJECT", value: "CONSTELLATION")
                            Divider().background(AppTheme.ink)
                            AboutRow(label: "BUILD", value: "NATIVE iOS")
                        }
                        .background(AppTheme.paper)
                        .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            // Add safe area padding for scroll content
            .safeAreaInset(edge: .bottom) {
                 Color.clear.frame(height: 100)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SYSTEM")
                        .font(.system(.headline, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .task {
                loadArrayAPIKey()
                await checkConnection()
                loadAPIKey()
            }
            .sheet(isPresented: $showingCreateNote) {
                CreateNoteView()
            }
        }
    }
    
    private func checkConnection() async {
        isChecking = true
        do {
            let status = try await ArrayService.shared.getStatus()
            await MainActor.run {
                arrayStatus = status
                isConnected = true
                isChecking = false
                lastChecked = Date()
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                isConnected = false
                isChecking = false
                lastChecked = Date()
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func saveQuickNote() {
        Task {
            try? await ArrayService.shared.saveNote(
                title: "Test from Beacon",
                content: "System check initiated at \(Date().formatted())",
                tags: ["beacon", "test"]
            )
        }
    }
    
    // MARK: - API Key Management
    
    private func loadAPIKey() {
        if let key = KeychainHelper.get(key: "anthropic_api_key") {
            apiKey = key
        }
    }
    
    private func saveAPIKey() {
        isSavingKey = true
        let sanitizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainHelper.save(key: "anthropic_api_key", value: sanitizedKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSavingKey = false
        }
    }
    
    private func clearAPIKey() {
        KeychainHelper.delete(key: "anthropic_api_key")
        apiKey = ""
    }
    
    private func loadArrayAPIKey() {
        if let key = KeychainHelper.get(key: "array_api_key") {
            arrayApiKey = key
        }
    }
    
    private func saveArrayAPIKey() {
        isSavingArrayKey = true
        let sanitizedKey = arrayApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainHelper.save(key: "array_api_key", value: sanitizedKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSavingArrayKey = false
        }
    }
    
    private func clearArrayAPIKey() {
        KeychainHelper.delete(key: "array_api_key")
        arrayApiKey = ""
    }
}



// MARK: - Local Model Section

struct LocalModelSection: View {
    @ObservedObject var downloadService: ModelDownloadService
    @Binding var selectedBackend: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Model status row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GEMMA 4 E4B")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.ink)
                    Text("3.7 GB · On-device · Private")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.ink.opacity(0.6))
                }
                Spacer()
                statusBadge
            }

            // Progress bar while downloading
            if case .downloading(let progress) = downloadService.state {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                        .tint(AppTheme.accentBlue)
                    Text("\(Int(progress * 100))%  ·  3.7 GB total")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.ink.opacity(0.5))
                }
            }

            // Action buttons
            actionButtons

            // Backend toggle — only when model is downloaded
            if downloadService.state == .downloaded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACTIVE MODEL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.ink.opacity(0.6))
                    HStack(spacing: 0) {
                        ForEach(["claude", "gemma"], id: \.self) { backend in
                            Button {
                                selectedBackend = backend
                            } label: {
                                Text(backend == "claude" ? "CLAUDE HAIKU" : "GEMMA 4 E4B")
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedBackend == backend ? AppTheme.accentOchre : AppTheme.paper)
                                    .foregroundStyle(AppTheme.ink)
                            }
                            .buttonStyle(.plain)
                            .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
                        }
                    }
                }

                Button {
                    downloadService.deleteModel()
                    selectedBackend = "claude"
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("DELETE MODEL  (FREE 3.7 GB)")
                        Spacer()
                    }
                }
                .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentRed))
            }
        }
        .padding(16)
        .background(AppTheme.paper)
        .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch downloadService.state {
        case .notDownloaded:
            Text("NOT DOWNLOADED")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.ink.opacity(0.5))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .overlay(Rectangle().stroke(AppTheme.ink.opacity(0.3), lineWidth: 1))
        case .downloading:
            Text("DOWNLOADING")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.paper)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(AppTheme.accentBlue)
        case .downloaded:
            Text("READY")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.paper)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.green)
        case .failed:
            Text("FAILED")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.paper)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(AppTheme.accentRed)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch downloadService.state {
        case .notDownloaded:
            Button {
                downloadService.startDownload(hfToken: nil)
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle")
                    Text("DOWNLOAD GEMMA MODEL  (3.7 GB)")
                    Spacer()
                }
            }
            .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentBlue))

        case .downloading:
            Button {
                downloadService.cancelDownload()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("CANCEL DOWNLOAD")
                    Spacer()
                }
            }
            .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentRed))

        case .failed(let msg):
            VStack(alignment: .leading, spacing: 8) {
                Text(msg)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AppTheme.accentRed)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    downloadService.resumeDownload(hfToken: nil)
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("RETRY DOWNLOAD")
                        Spacer()
                    }
                }
                .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentOchre))
            }

        case .downloaded:
            EmptyView()
        }
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.ink.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(AppTheme.ink)
        }
    }
}

struct AboutRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.ink.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(16)
    }
}

#Preview {
    SettingsView()
}
