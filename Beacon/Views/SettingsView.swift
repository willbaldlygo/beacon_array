import SwiftUI

struct SettingsView: View {
    @State private var arrayStatus: ArrayStatus?
    @State private var isConnected = false
    @State private var isChecking = false
    @State private var isChecking = false
    @State private var lastChecked: Date?
    @State private var apiKey = ""
    @State private var showKey = false
    @State private var isSavingKey = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Divider().background(AppTheme.ink)
                            .padding(.bottom, 8)
                        
                        // Status Card
                        VStack(spacing: 0) {
                            HStack {
                                Text("SYSTEM STATUS")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                Spacer()
                                Circle()
                                    .fill(isConnected ? Color.green : AppTheme.accentRed)
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().stroke(AppTheme.ink, lineWidth: 1))
                            }
                            .padding(12)
                            .background(AppTheme.ink.opacity(0.05))
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
                                .buttonStyle(MondrianButtonStyle())
                                .disabled(isChecking)
                                .padding(.top, 8)
                            }
                            .padding(16)
                            .background(AppTheme.paper)
                            .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
                        }
                        
                        // Quick Actions
                        SectionHeader(title: "QUICK ACTIONS")
                        
                        Button {
                            saveQuickNote()
                        } label: {
                            HStack {
                                Image(systemName: "note.text")
                                Text("CREATE NOTE")
                                Spacer()
                            }
                        }
                        .buttonStyle(MondrianButtonStyle())
                        
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
                await checkConnection()
                loadAPIKey()
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
            }
        } catch {
            await MainActor.run {
                isConnected = false
                isChecking = false
                lastChecked = Date()
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
        KeychainHelper.save(key: "anthropic_api_key", value: apiKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSavingKey = false
        }
    }
    
    private func clearAPIKey() {
        KeychainHelper.delete(key: "anthropic_api_key")
        apiKey = ""
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.ink.opacity(0.6))
            Spacer()
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
