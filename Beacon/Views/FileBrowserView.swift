import SwiftUI

struct FileBrowserView: View {
    enum BrowserMode {
        case normal
        case picker
    }
    
    let path: String
    let mode: BrowserMode
    let onSelect: ((FileContent) -> Void)?
    
    @StateObject private var service = FileBrowserService()
    
    init(path: String = "", mode: BrowserMode = .normal, onSelect: ((FileContent) -> Void)? = nil) {
        self.path = path
        self.mode = mode
        self.onSelect = onSelect
    }
    
    // Breadcrumb segments for the current path
    private var breadcrumbSegments: [(name: String, path: String)] {
        let current = service.currentPath
        var result: [(String, String)] = [("Array", "")]
        guard !current.isEmpty else { return result }
        let parts = current.split(separator: "/").map(String.init)
        var accum = ""
        for part in parts {
            accum = accum.isEmpty ? part : "\(accum)/\(part)"
            result.append((part, accum))
        }
        return result
    }
    
    var body: some View {
        Group {
            if service.isLoading && service.items.isEmpty {
                ProgressView("Loading...")
            } else if let error = service.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.error)
                    Text(error)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await service.loadDirectory(path: path) }
                    }
                    .buttonStyle(MondrianButtonStyle())
                }
                .padding()
            } else {
                List {
                    // Breadcrumb header row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(breadcrumbSegments.enumerated()), id: \.offset) { index, crumb in
                                Button {
                                    Task { await service.loadDirectory(path: crumb.path) }
                                } label: {
                                    Text(crumb.name)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(AppTheme.primary)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(AppTheme.surfaceContainerLowest)
                                        .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
                                }
                                if index < breadcrumbSegments.count - 1 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppTheme.primary.opacity(0.6))
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                    }
                    .listRowBackground(AppTheme.surfaceContainerLowest)
                    .listRowSeparator(.hidden)
                    
                    if service.items.isEmpty {
                        Text("Empty directory")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(service.items) { item in
                            if item.isDirectory {
                                NavigationLink {
                                    FileBrowserView(path: item.path, mode: mode, onSelect: onSelect)
                                } label: {
                                    FileRow(item: item)
                                }
                                .listRowBackground(AppTheme.surfaceContainerLowest)
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 4)
                            } else {
                                // File behavior depends on mode
                                if mode == .picker {
                                    Button {
                                        Task {
                                            if let content = try? await service.readFile(path: item.path) {
                                                onSelect?(content)
                                            }
                                        }
                                    } label: {
                                        FileRow(item: item)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(AppTheme.surfaceContainerLowest)
                                    .listRowSeparator(.hidden)
                                    .padding(.vertical, 4)
                                } else {
                                    NavigationLink {
                                        FileDetailView(item: item, canEdit: canEdit(item))
                                    } label: {
                                        FileRow(item: item)
                                    }
                                    .listRowBackground(AppTheme.surfaceContainerLowest)
                                    .listRowSeparator(.hidden)
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(AppTheme.background)
            }
        }
        .navigationTitle(urlObtainedLastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Load only if empty (or could reload on appear)
            if service.items.isEmpty {
                await service.loadDirectory(path: path)
            }
        }
        .navigationDestination(for: FileItem.self) { item in
            if item.isDirectory {
                FileBrowserView(path: item.path, mode: mode, onSelect: onSelect)
            } else if mode == .normal {
                FileDetailView(item: item, canEdit: canEdit(item))
            }
        }
        .refreshable {
            await service.loadDirectory(path: path)
        }
    }
    
    private var urlObtainedLastPathComponent: String {
        if path.isEmpty { return "Files" }
        return (path as NSString).lastPathComponent
    }
    
    private func canEdit(_ item: FileItem) -> Bool {
        let editableExtensions: Set<String> = [".md", ".txt", ".json", ".yaml", ".yml"]
        guard let ext = item.fileExtension else { return false }
        return editableExtensions.contains(ext)
    }
}

struct FileRow: View {
    let item: FileItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.title3)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(AppTheme.primary)
                
                if let size = item.size {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(AppTheme.surfaceContainerLowest)
        .overlay(
            Rectangle()
                .stroke(AppTheme.primary, lineWidth: AppTheme.border)
        )
    }
    
    var iconName: String {
        if item.isDirectory { return "folder.fill" }
        // Simple mapping
        if item.name.hasSuffix(".md") { return "doc.text.fill" }
        if item.name.hasSuffix(".py") { return "terminal.fill" }
        if item.name.hasSuffix(".swift") { return "swift" }
        return "doc.fill"
    }
    
    var iconColor: Color {
        if item.isDirectory { return AppTheme.tertiaryFixed } // Ochre
        return AppTheme.secondary // Teal
    }
}

struct FileDetailView: View {
    let item: FileItem
    let canEdit: Bool
    
    @StateObject private var service = FileBrowserService()
    @State private var content: String?
    @State private var fileInfo: FileContent?
    @State private var isEditing = false
    @State private var editBuffer = ""
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var showDiscardAlert = false
    
    private var hasUnsavedChanges: Bool {
        isEditing && editBuffer != (content ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            metadataHeader
            contentArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.background.ignoresSafeArea())
        .overlay(alignment: .bottom) { toastOverlay }
        .navigationTitle(item.name)
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
        .animation(.easeInOut(duration: 0.2), value: saveMessage)
    }
    
    @ViewBuilder
    private var metadataHeader: some View {
        if let info = fileInfo {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.onSecondary)
                        .lineLimit(1)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(info.size), countStyle: .file) + "  ·  " + formattedDate(info.modified))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(AppTheme.onSecondary.opacity(0.7))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.secondary)
            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
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
                    .background(AppTheme.surfaceContainerLowest)
                    .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
                    .padding(12)
            } else {
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(AppTheme.primary)
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
                .foregroundStyle(AppTheme.error)
            Text(error)
                .font(.system(.caption, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.error)
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
                .foregroundStyle(AppTheme.onSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.secondary)
                .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
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
                .foregroundStyle(AppTheme.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await saveFile() } } label: {
                    if isSaving { ProgressView().scaleEffect(0.7) }
                    else { Text("Save").font(.system(.body, design: .monospaced)).bold() }
                }
                .disabled(isSaving)
                .foregroundStyle(AppTheme.secondary)
            }
        } else if canEdit {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    editBuffer = content ?? ""
                    isEditing = true
                }
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AppTheme.primary)
            }
        }
    }

    
    private func loadFile() async {
        do {
            let result = try await service.readFile(path: item.path)
            self.fileInfo = result
            self.content = result.content
        } catch {
            service.error = error.localizedDescription
        }
    }
    
    private func saveFile() async {
        isSaving = true
        do {
            try await service.writeFile(path: item.path, content: editBuffer)
            content = editBuffer
            isEditing = false
            withAnimation { saveMessage = "SAVED ✓" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { saveMessage = nil }
            }
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
