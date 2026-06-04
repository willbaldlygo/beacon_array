import SwiftUI

struct TasksView: View {
    @StateObject private var service = FileBrowserService()
    @State private var content: String?
    @State private var fileInfo: FileContent?
    @State private var isEditing = false
    @State private var editBuffer = ""
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var showDiscardAlert = false
    
    private let tasksPath = "PM/tasks.md"
    
    private var hasUnsavedChanges: Bool {
        isEditing && editBuffer != (content ?? "")
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                metadataHeader
                contentArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.background.ignoresSafeArea())
            .overlay(alignment: .bottom) { toastOverlay }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(hasUnsavedChanges)
            .toolbar { toolbarContent }
            .confirmationDialog("Discard changes?", isPresented: $showDiscardAlert, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    isEditing = false
                    editBuffer = content ?? ""
                }
                Button(role: .cancel) {
                    // Keep editing
                } label: {
                    Text("Keep Editing")
                }
            }
            .task { await loadFile() }
            .refreshable {
                if !isEditing {
                    await loadFile()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: saveMessage)
        }
    }
    
    @ViewBuilder
    private var metadataHeader: some View {
        if let info = fileInfo {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.paper)
                        .lineLimit(1)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(info.size), countStyle: .file) + "  ·  " + formattedDate(info.modified))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.paper.opacity(0.7))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.accentBlue)
            .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
        }
    }
    
    @ViewBuilder
    private var contentArea: some View {
        if service.isLoading && content == nil {
            VStack {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = service.error {
            errorView(error)
        } else if let content = content {
            if isEditing {
                TextEditor(text: $editBuffer)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.paper)
                    .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
                    .padding(12)
            } else {
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(AppTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
        }
    }
    
    @ViewBuilder
    private func errorView(_ error: String) -> some View {
        Spacer()
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.accentRed)
            Text(error)
                .font(.system(.caption, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.accentRed)
            Button("Retry") {
                Task { service.error = nil; await loadFile() }
            }
            .buttonStyle(MondrianButtonStyle())
        }
        .padding()
        Spacer()
    }
    
    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = saveMessage {
            Text(msg)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.paper)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.accentBlue)
                .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    if hasUnsavedChanges { showDiscardAlert = true } else { isEditing = false }
                }
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AppTheme.ink)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await saveFile() } } label: {
                    if isSaving { ProgressView().scaleEffect(0.7) }
                    else { Text("Save").font(.system(.body, design: .monospaced)).bold() }
                }
                .disabled(isSaving)
                .foregroundStyle(AppTheme.accentBlue)
            }
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    editBuffer = content ?? ""
                    isEditing = true
                }
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AppTheme.ink)
            }
        }
    }
    
    private func loadFile() async {
        service.isLoading = true
        do {
            let result = try await service.readFile(path: tasksPath)
            self.fileInfo = result
            self.content = result.content
            service.error = nil // Clear any previous errors on success
        } catch {
            service.error = error.localizedDescription
        }
        service.isLoading = false
    }
    
    private func saveFile() async {
        isSaving = true
        do {
            try await service.writeFile(path: tasksPath, content: editBuffer)
            content = editBuffer
            isEditing = false
            withAnimation { saveMessage = "SAVED ✓" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { saveMessage = nil }
            }
            // Reload to update metadata optionally
            await loadFile()
        } catch {
            withAnimation { saveMessage = "SAVE FAILED" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { saveMessage = nil }
            }
        }
        isSaving = false
    }
    
    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: date)
        }
        return iso
    }
}

#Preview {
    TasksView()
}
