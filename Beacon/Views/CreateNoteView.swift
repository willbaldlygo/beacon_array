import SwiftUI

struct CreateNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var noteService = NoteService()
    
    @State private var noteTitle = ""
    @State private var noteContent = ""
    @State private var tagsText = ""
    @State private var isVoiceMode = false
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
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
                        
                        // Note Type Picker
                        MondrianPicker(
                            title: "NOTE TYPE",
                            selection: $isVoiceMode,
                            options: [false, true] // false = Text, true = Voice
                        )
                        .hidden() // Hiding the generic one to implement specific labels below
                        .overlay(
                            VStack(alignment: .leading, spacing: 8) {
                                Text("NOTE TYPE")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(AppTheme.primary.opacity(0.6))
                                
                                HStack(spacing: 0) {
                                    pickerButton(title: "TEXT", isSelected: !isVoiceMode) { isVoiceMode = false }
                                    pickerButton(title: "VOICE", isSelected: isVoiceMode) { isVoiceMode = true }
                                }
                            }
                        )
                        
                        // Details Section
                        VStack(spacing: 16) {
                            SectionHeader(title: "DETAILS")
                            
                            MondrianTextField(title: "Title", text: $noteTitle)
                            MondrianTextField(title: "Tags (comma separated)", text: $tagsText)
                        }
                        
                        // Content Section
                        VStack(spacing: 16) {
                            SectionHeader(title: isVoiceMode ? "RECORDING" : "CONTENT")
                            
                            if isVoiceMode {
                                VoiceRecordingView(noteService: noteService)
                                
                                if !noteService.transcribedText.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("TRANSCRIPT")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(AppTheme.primary.opacity(0.6))
                                        
                                        Text(noteService.transcribedText)
                                            .font(.system(.body, design: .monospaced))
                                            .padding(12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(AppTheme.surfaceContainerLowest)
                                            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
                                    }
                                }
                            } else {
                                MondrianTextField(title: "Body", text: $noteContent, axis: .vertical)
                            }
                        }
                        
                        // Actions
                        VStack(spacing: 12) {
                            Button(action: submitNote) {
                                if isSubmitting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("SAVE TO ARRAY")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.tertiaryFixed))
                            .disabled(noteTitle.isEmpty || isSubmitting || (!isVoiceMode && noteContent.isEmpty))
                            .opacity((noteTitle.isEmpty || isSubmitting || (!isVoiceMode && noteContent.isEmpty)) ? 0.5 : 1.0)
                            
                            Button("CANCEL") {
                                dismiss()
                            }
                            .buttonStyle(MondrianButtonStyle())
                        }
                        .padding(.top, 16)
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CREATE NOTE")
                        .font(.system(.headline, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Note saved to Array inbox")
            }
        }
    }
    
    private func pickerButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? AppTheme.tertiaryFixed : AppTheme.surfaceContainerLowest)
                .foregroundStyle(AppTheme.primary.opacity(isSelected ? 1.0 : 0.6))
                .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
        }
        .buttonStyle(.plain)
    }
    
    private func submitNote() {
        isSubmitting = true
        
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        Task {
            do {
                if isVoiceMode {
                    try await noteService.submitAudioNote(title: noteTitle, tags: tags)
                } else {
                    try await noteService.submitTextNote(title: noteTitle, content: noteContent, tags: tags)
                }
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

struct VoiceRecordingView: View {
    @ObservedObject var noteService: NoteService
    
    var body: some View {
        VStack(spacing: 16) {
            if noteService.isTranscribing {
                HStack {
                    Spacer()
                    ProgressView("Transcribing...")
                        .font(.system(.caption, design: .monospaced))
                    Spacer()
                }
                .padding()
                .background(AppTheme.surfaceContainerLowest)
                .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
            } else {
                Button(action: toggleRecording) {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(noteService.isRecording ? AppTheme.error : AppTheme.secondary)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: noteService.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(noteService.isRecording ? "Reflect..." : "Tap to Record")
                                .font(.system(.subheadline, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.primary)
                            
                            if noteService.isRecording {
                                Text("Recording in progress")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.error)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(AppTheme.surfaceContainerLowest)
                    .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func toggleRecording() {
        if noteService.isRecording {
            noteService.stopRecording()
        } else {
            do {
                try noteService.startRecording()
            } catch {
                noteService.error = error.localizedDescription
            }
        }
    }
}
