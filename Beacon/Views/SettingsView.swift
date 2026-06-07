import SwiftUI

struct SettingsView: View {
    @State private var arrayStatus: ArrayStatus?
    @State private var isConnected = false
    @State private var isChecking = false
    @State private var lastChecked: Date?

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
                        Divider().background(AppTheme.primary)
                            .padding(.bottom, 8)

                        // Status Card
                        VStack(spacing: 0) {
                            HStack {
                                Text("SYSTEM STATUS")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppTheme.onSecondary)
                                Spacer()
                                Circle()
                                    .fill(isConnected ? Color.green : AppTheme.error)
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().stroke(AppTheme.onSecondary, lineWidth: 1))
                            }
                            .padding(12)
                            .background(AppTheme.secondary)
                            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))

                            VStack(alignment: .leading, spacing: 12) {
                                StatusRow(label: "CONNECTION", value: isConnected ? "ONLINE" : "OFFLINE")
                                if let status = arrayStatus {
                                    StatusRow(label: "HOSTNAME", value: status.hostname.uppercased())
                                }
                                StatusRow(label: "VERSION", value: "3.0.2")

                                Button {
                                    Task { await checkConnection() }
                                } label: {
                                    HStack {
                                        Text(isChecking ? "PINGING..." : "TEST CONNECTION")
                                        Spacer()
                                        Image(systemName: "arrow.clockwise")
                                    }
                                }
                                .buttonStyle(MondrianPillButtonStyle(backgroundColor: AppTheme.secondary, verticalPadding: 12))
                                .disabled(isChecking)
                                .padding(.top, 8)

                                if let error = errorMessage {
                                    Text(error)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(AppTheme.error)
                                        .padding(.vertical, 4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(16)
                            .background(AppTheme.surfaceContainerLowest)
                            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
                        }

                        // Quick Actions
                        SectionHeader(title: "QUICK ACTIONS")

                        Button {
                            showingCreateNote = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "note.text")
                                Text("CREATE NOTE")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MondrianPillButtonStyle(backgroundColor: AppTheme.surfaceContainerLowest, verticalPadding: 14))

                        // Local Model
                        SectionHeader(title: "LOCAL MODEL")

                        LocalModelSection(
                            downloadService: downloadService,
                            selectedBackend: $selectedBackend
                        )

                        // System Visualization
                        SystemVisualizationPanel()
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                 Color.clear.frame(height: 100)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SYSTEM")
                        .font(.system(.headline, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .task {
                await checkConnection()
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
                        .foregroundStyle(AppTheme.primary)
                    Text("3.7 GB · On-device · Private")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.primary.opacity(0.6))
                }
                Spacer()
                statusBadge
            }

            // Progress bar while downloading
            if case .downloading(let progress) = downloadService.state {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                        .tint(AppTheme.secondary)
                    Text("\(Int(progress * 100))%  ·  3.7 GB total")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.primary.opacity(0.5))
                }
            }

            // Action buttons
            actionButtons

            // Backend toggle — only when model is downloaded
            if downloadService.state == .downloaded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACTIVE MODEL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.primary.opacity(0.6))
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
                                    .background(selectedBackend == backend ? AppTheme.tertiaryFixed : AppTheme.surfaceContainerLowest)
                                    .foregroundStyle(AppTheme.primary)
                            }
                            .buttonStyle(.plain)
                            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
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
                .buttonStyle(MondrianPillButtonStyle(backgroundColor: AppTheme.error, verticalPadding: 12))
            }
        }
        .padding(16)
        .background(AppTheme.surfaceContainerLowest)
        .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch downloadService.state {
        case .notDownloaded:
            Text("NOT DOWNLOADED")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.primary.opacity(0.5))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(AppTheme.surfaceContainerLow)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.primary.opacity(0.3), lineWidth: AppTheme.border))
        case .downloading:
            Text("DOWNLOADING")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.onSecondary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(AppTheme.secondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.primary, lineWidth: AppTheme.border))
        case .downloaded:
            Text("READY")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.secondary)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.secondary, lineWidth: AppTheme.border))
        case .failed:
            Text("FAILED")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.onError)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(AppTheme.error)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.primary, lineWidth: AppTheme.border))
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
                    Text("DOWNLOAD GEMMA MODEL (3.7 GB)")
                    Spacer()
                }
            }
            .buttonStyle(MondrianPillButtonStyle(backgroundColor: AppTheme.secondary, verticalPadding: 12))

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
            .buttonStyle(MondrianPillButtonStyle(backgroundColor: AppTheme.error, verticalPadding: 12))

        case .failed(let msg):
            VStack(alignment: .leading, spacing: 8) {
                Text(msg)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AppTheme.error)
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
                .buttonStyle(MondrianPillButtonStyle(backgroundColor: AppTheme.tertiaryFixed, verticalPadding: 12))
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
                .foregroundStyle(AppTheme.primary.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(AppTheme.primary)
        }
    }
}

struct SystemVisualizationPanel: View {
    var body: some View {
        MondrianOrbitalSystem(isSmall: true, showVoiceIcon: false)
            .background(Color.white)
            .frame(height: 256)
            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
    }
}

#Preview {
    SettingsView()
}
