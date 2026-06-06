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
                    
                    AcousticFieldVisualizer()
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.surface)
                        .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
                        .padding(.bottom, 24)
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
        VStack(spacing: 24) {
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
            
            // Status strip
            SystemStatusStrip()
                .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
            
            // Formats Card
            SupportedFormatsGrid()
                .padding(.horizontal, 16)
        }
    }
}

private struct SystemStatusStrip: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Section 1: System Status
                VStack(alignment: .leading, spacing: 4) {
                    Text("SYSTEM STATUS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.7))
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("NEURAL ENGINE ONLINE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                
                // Section 2: Privacy Mode
                VStack(alignment: .leading, spacing: 4) {
                    Text("PRIVACY MODE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.7))
                    HStack(spacing: 6) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white)
                        Text("LOCAL-ONLY PROCESSING")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppTheme.primary)
            .frame(height: 60)
        }
    }
}

private struct SupportedFormatsGrid: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(AppTheme.primary)
                Text("SUPPORTED FORMATS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 1) {
                FormatCell(extensionStr: ".WAV", label: "LOSSLESS")
                FormatCell(extensionStr: ".M4A", label: "COMPRESSED")
                FormatCell(extensionStr: ".MP3", label: "STANDARD")
                FormatCell(extensionStr: ".FLAC", label: "HIGH-RES")
            }
            .background(AppTheme.primary)
            .border(AppTheme.primary, width: 1)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Transcription is optimized for clear speech in quiet environments. Ambient noise reduction is applied automatically.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AppTheme.primary)
                    .padding(.leading, 12)
                    .overlay(
                        Rectangle()
                            .fill(AppTheme.secondary)
                            .frame(width: 4)
                            .frame(maxHeight: .infinity),
                        alignment: .leading
                    )
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(AppTheme.surface)
        .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: AppTheme.border))
    }
}

struct FormatCell: View {
    let extensionStr: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(extensionStr)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.secondary)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.surface)
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
                .buttonStyle(MondrianPillButtonStyle(backgroundColor: AppTheme.surfaceContainerLowest, verticalPadding: 10))

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
                    verticalPadding: 10
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
