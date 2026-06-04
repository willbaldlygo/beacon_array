import SwiftUI

struct InboxView: View {
    @State private var items: [QueueItem] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingCreateNote = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Divider().background(AppTheme.ink)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if let error = error {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundStyle(AppTheme.accentRed)
                            Text(error)
                                .font(.system(.body, design: .serif))
                                .multilineTextAlignment(.center)
                            Button("RETRY") {
                                Task { await loadItems() }
                            }
                            .buttonStyle(MondrianButtonStyle())
                        }
                        .padding(32)
                    } else if items.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 32))
                                .foregroundStyle(AppTheme.ink.opacity(0.3))
                            Text("INBOX EMPTY")
                                .font(.system(.headline, design: .monospaced))
                                .foregroundStyle(AppTheme.ink.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(items) { item in
                                    MondrianInboxRow(item: item)
                                }
                            }
                            .padding(16)
                        }
                        .refreshable {
                            await loadItems()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingCreateNote = true
                    } label: {
                        Circle()
                            .fill(AppTheme.accentRed)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("INBOX")
                        .font(.system(.headline, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(AppTheme.ink)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await loadItems() }
                    } label: {
                        Circle()
                            .fill(AppTheme.accentBlue)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .opacity(isLoading ? 0.5 : 1.0)
                }
            }
            .sheet(isPresented: $showingCreateNote) {
                CreateNoteView()
            }
            .task {
                await loadItems()
            }
        }
    }
    
    private func loadItems() async {
        isLoading = true
        error = nil
        do {
            let response = try await ArrayService.shared.getQueue()
            await MainActor.run {
                items = response.items
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct MondrianInboxRow: View {
    let item: QueueItem
    
    var body: some View {
        HStack(spacing: 0) {
            // Type Indicator Strip
            Rectangle()
                .fill(colorForType(item.sourceType))
                .frame(width: 8)
                .overlay(
                    Rectangle()
                        .stroke(AppTheme.ink, lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.system(.headline, design: .serif))
                    .fontWeight(.regular)
                    .shadow(radius: 0)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                
                HStack {
                    Label(item.sourceType.uppercased(), systemImage: iconForType(item.sourceType))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    
                    Spacer()
                    
                    Text(formatDate(item.capturedAt))
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(AppTheme.ink.opacity(0.6))
            }
            .padding(16)
        }
        .background(AppTheme.paper)
        .overlay(
            Rectangle()
                .stroke(AppTheme.ink, lineWidth: 1)
        )
        .overlay(
            Rectangle()
                .stroke(AppTheme.ink, lineWidth: 1)
        )
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "note": return "note.text"
        case "url": return "link"
        case "pdf": return "doc.fill"
        case "session_trace": return "text.bubble"
        default: return "doc"
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type {
        case "note": return AppTheme.accentOchre
        case "session_trace": return AppTheme.accentBlue
        case "pdf": return AppTheme.accentRed
        default: return Color.gray
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        if let tIndex = dateString.firstIndex(of: "T") {
            return String(dateString[..<tIndex])
        }
        return dateString
    }
}


