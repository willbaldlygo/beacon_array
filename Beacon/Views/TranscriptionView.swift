import SwiftUI
import Combine
import UniformTypeIdentifiers

struct TranscriptionView: View {

    @StateObject private var viewModel = TranscriptionViewModel()
    @State private var showingFilePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                TranscriptionContent(
                    viewModel: viewModel,
                    showingFilePicker: $showingFilePicker
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("VOICE")
                        .font(.system(.headline, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(AppTheme.primary)
                }
                if case .done = viewModel.state {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { viewModel.reset() } label: {
                            MondrianCircleIcon(color: AppTheme.error, systemImage: "trash")
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.audio, .wav, .mp3, .mpeg4Audio, .aiff],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                Task {
                    await viewModel.transcribe(url: url)
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }
}

// MARK: - Subviews

private struct TranscriptionContent: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @Binding var showingFilePicker: Bool

    private var showVisualizer: Bool {
        switch viewModel.state {
        case .idle, .recording:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if showVisualizer {
                    MondrianOrbitalSystem(isSmall: false, showVoiceIcon: true)
                        .background(AppTheme.surface)
                        .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
                    
                    if viewModel.state == .recording {
                        AcousticFieldVisualizer(audioLevel: viewModel.audioLevel)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.surface)
                            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
                            .padding(.bottom, 24)
                    } else {
                        Spacer().frame(height: 24)
                    }
                } else {
                    Divider().background(AppTheme.primary)
                        .padding(.bottom, 24)
                }

                switch viewModel.state {
                case .idle:
                    IdleControls(viewModel: viewModel, showingFilePicker: $showingFilePicker)

                case .recording:
                    RecordingControls(viewModel: viewModel)

                case .transcribing:
                    TranscribingIndicator()

                case .done(let text):
                    TranscriptResult(transcript: text, viewModel: viewModel)

                case .failed(let msg):
                    ErrorCard(message: msg) { viewModel.reset() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 100) }
    }
}

private struct IdleControls: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @Binding var showingFilePicker: Bool

    var body: some View {
        VStack(spacing: 32) {
            // Action Section
            VStack(spacing: 16) {
                Button {
                    Task { await viewModel.requestMicPermissionAndRecord() }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(AppTheme.primary, lineWidth: 1))
                            .overlay {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(AppTheme.error)
                            }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RECORD VOICE")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                            Text("START CAPTURE")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .opacity(0.7)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: 320)
                }
                .buttonStyle(MondrianPillButtonStyle(backgroundColor: AppTheme.error, verticalPadding: 12))
                
                Button {
                    showingFilePicker = true
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(AppTheme.primary, lineWidth: 1))
                            .overlay {
                                Image(systemName: "waveform.badge.plus")
                                    .font(.system(size: 18))
                                    .foregroundStyle(AppTheme.secondary)
                            }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("IMPORT AUDIO")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                            Text("BATCH PROCESS")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .opacity(0.7)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: 320)
                }
                .buttonStyle(MondrianPillButtonStyle(backgroundColor: AppTheme.secondary, verticalPadding: 12))
            }
            .padding(.horizontal, 16)
            
            // Subtle status and formats stack
            VStack(spacing: 20) {
                // Subtle status
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("NEURAL ENGINE ONLINE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    Spacer()
                }
                .foregroundStyle(AppTheme.primary)
                .opacity(0.55)
                
                Divider().background(AppTheme.primary.opacity(0.15))
                
                // Clean text list of formats
                VStack(alignment: .leading, spacing: 8) {
                    Text("SUPPORTED FORMATS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.primary)
                        .opacity(0.75)
                    
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• .WAV (Lossless)")
                            Text("• .MP3 (Standard)")
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• .M4A (Compressed)")
                            Text("• .FLAC (High-Res)")
                        }
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.primary)
                    .opacity(0.65)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct RecordingControls: View {
    @ObservedObject var viewModel: TranscriptionViewModel

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Circle()
                    .fill(AppTheme.error)
                    .frame(width: 10, height: 10)
                Text("RECORDING  \(formattedTime)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(AppTheme.primary)
                Spacer()
            }
            .padding(16)
            .background(AppTheme.surfaceContainerLowest)
            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
            .padding(.horizontal, 16)

            Button {
                viewModel.stopRecording()
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(AppTheme.primary, lineWidth: 1))
                        .overlay {
                            Image(systemName: "stop.fill")
                                .foregroundStyle(AppTheme.primary)
                        }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("STOP & TRANSCRIBE")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                        Text("STOP RECORDING")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .opacity(0.7)
                    }
                    Spacer()
                }
                .frame(maxWidth: 320)
            }
            .buttonStyle(MondrianPillButtonStyle(backgroundColor: AppTheme.tertiaryFixed, verticalPadding: 12))
            .padding(.horizontal, 16)
        }
    }

    private var formattedTime: String {
        let e = viewModel.recordingSeconds
        return String(format: "%02d:%02d", e / 60, e % 60)
    }
}

private struct TranscribingIndicator: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ProgressView()
                    .padding(.trailing, 8)
                Text("TRANSCRIBING…")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(AppTheme.primary)
                Spacer()
            }
            .padding(16)
            .background(AppTheme.surfaceContainerLowest)
            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
            .padding(.horizontal, 16)

            Text("On first use, Whisper downloads ~630 MB — this can take a few minutes. Subsequent transcriptions are fast.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(AppTheme.primary.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
        }
    }
}

private struct TranscriptResult: View {
    let transcript: String
    @ObservedObject var viewModel: TranscriptionViewModel

    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "TRANSCRIPT")
                .padding(.horizontal, 16)

            Text(transcript)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AppTheme.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppTheme.surfaceContainerLowest)
                .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
                .padding(.horizontal, 16)

            HStack(spacing: 12) {
                ShareLink(item: transcript) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("SHARE")
                        Spacer()
                    }
                }
                .buttonStyle(MondrianPillButtonStyle(
                    backgroundColor: AppTheme.surfaceContainerLowest,
                    horizontalPadding: 16,
                    fixedHeight: 48
                ))

                Button {
                    Task { await viewModel.saveToArray(transcript: transcript) }
                } label: {
                    HStack {
                        Image(systemName: viewModel.savedToArray ? "checkmark" : "arrow.up.to.line")
                        Text(viewModel.savedToArray ? "SAVED" : "SAVE TO ARRAY")
                        Spacer()
                    }
                }
                .buttonStyle(MondrianPillButtonStyle(
                    backgroundColor: viewModel.savedToArray ? AppTheme.tertiaryFixed : AppTheme.secondary,
                    horizontalPadding: 16,
                    fixedHeight: 48
                ))
                .disabled(viewModel.savedToArray)
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct ErrorCard: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ERROR")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.error)
            Text(message)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AppTheme.primary)
                .fixedSize(horizontal: false, vertical: true)
            Button("TRY AGAIN", action: onDismiss)
                .buttonStyle(MondrianPillButtonStyle(backgroundColor: AppTheme.error, verticalPadding: 10))
        }
        .padding(16)
        .background(AppTheme.surfaceContainerLowest)
        .overlay(Rectangle().stroke(AppTheme.error, lineWidth: AppTheme.border))
        .padding(.horizontal, 16)
    }
}

private struct ModelRequiredPrompt: View {
    var body: some View {
        VStack(spacing: 24) {
            Divider().background(AppTheme.primary)

            VStack(alignment: .leading, spacing: 12) {
                Text("LOCAL MODEL REQUIRED")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.primary)
                Text("Transcription uses on-device Gemma 4 E4B. Download the model (3.7 GB) from the System tab to enable this feature.")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(AppTheme.primary.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(AppTheme.surfaceContainerLowest)
            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
        }
        .padding(16)
    }
}
