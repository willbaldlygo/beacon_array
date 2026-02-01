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
        NavigationView {
            Form {
                Section {
                    Picker("Note Type", selection: $isVoiceMode) {
                        Text("Text").tag(false)
                        Text("Voice").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Details") {
                    TextField("Title", text: $noteTitle)
                    
                    TextField("Tags (comma separated)", text: $tagsText)
                        .textInputAutocapitalization(.never)
                }
                
                if isVoiceMode {
                    Section("Recording") {
                        VoiceRecordingView(noteService: noteService)
                        
                        if !noteService.transcribedText.isEmpty {
                            Text(noteService.transcribedText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Section("Content") {
                        TextEditor(text: $noteContent)
                            .frame(minHeight: 150)
                    }
                }
                
                Section {
                    Button(action: submitNote) {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save to Array")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(noteTitle.isEmpty || isSubmitting || 
                              (!isVoiceMode && noteContent.isEmpty))
                }
            }
            .navigationTitle("Create Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
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
                ProgressView("Transcribing...")
            } else {
                Button(action: toggleRecording) {
                    VStack {
                        Image(systemName: noteService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(noteService.isRecording ? .red : .blue)
                        
                        Text(noteService.isRecording ? "Tap to Stop" : "Tap to Record")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
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
