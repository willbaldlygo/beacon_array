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
                        .foregroundStyle(AppTheme.ink)
                }
                if case .done = viewModel.state {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { viewModel.reset() } label: {
                            MondrianCircleIcon(color: AppTheme.accentRed, systemImage: "trash")
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

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Divider().background(AppTheme.ink)

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
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 100) }
    }
}

private struct IdleControls: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @Binding var showingFilePicker: Bool

    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "RECORD")

            Button {
                Task { await viewModel.requestMicPermissionAndRecord() }
            } label: {
                HStack {
                    Image(systemName: "mic.fill")
                    Text("RECORD VOICENOTE")
                    Spacer()
                }
            }
            .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentRed))

            SectionHeader(title: "IMPORT")

            Button {
                showingFilePicker = true
            } label: {
                HStack {
                    Image(systemName: "waveform.badge.plus")
                    Text("IMPORT AUDIO FILE")
                    Spacer()
                }
            }
            .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentBlue))

            VStack(alignment: .leading, spacing: 8) {
                Text("SUPPORTED FORMATS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.ink.opacity(0.6))
                Text("M4A · WAV · MP3 · AIFF")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(AppTheme.ink.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.paper)
            .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
        }
    }
}

private struct RecordingControls: View {
    @ObservedObject var viewModel: TranscriptionViewModel

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Circle()
                    .fill(AppTheme.accentRed)
                    .frame(width: 10, height: 10)
                Text("RECORDING  \(formattedTime)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
            }
            .padding(16)
            .background(AppTheme.paper)
            .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))

            Button {
                viewModel.stopRecording()
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("STOP & TRANSCRIBE")
                    Spacer()
                }
            }
            .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentOchre))
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
                    .foregroundStyle(AppTheme.ink)
                Spacer()
            }
            .padding(16)
            .background(AppTheme.paper)
            .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))

            Text("On first use, Whisper downloads ~630 MB — this can take a few minutes. Subsequent transcriptions are fast.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(AppTheme.ink.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TranscriptResult: View {
    let transcript: String
    @ObservedObject var viewModel: TranscriptionViewModel

    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "TRANSCRIPT")

            Text(transcript)
                .font(.system(.body, design: .serif))
                .foregroundStyle(AppTheme.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppTheme.paper)
                .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))

            HStack(spacing: 12) {
                ShareLink(item: transcript) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("SHARE")
                        Spacer()
                    }
                }
                .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.paper))

                Button {
                    Task { await viewModel.saveToArray(transcript: transcript) }
                } label: {
                    HStack {
                        Image(systemName: viewModel.savedToArray ? "checkmark" : "arrow.up.to.line")
                        Text(viewModel.savedToArray ? "SAVED" : "SAVE TO ARRAY")
                        Spacer()
                    }
                }
                .buttonStyle(MondrianButtonStyle(
                    backgroundColor: viewModel.savedToArray ? AppTheme.accentOchre : AppTheme.accentBlue
                ))
                .disabled(viewModel.savedToArray)
            }
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
                .foregroundStyle(AppTheme.accentRed)
            Text(message)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button("TRY AGAIN", action: onDismiss)
                .buttonStyle(MondrianButtonStyle(backgroundColor: AppTheme.accentRed))
        }
        .padding(16)
        .background(AppTheme.paper)
        .overlay(Rectangle().stroke(AppTheme.accentRed, lineWidth: 1))
    }
}

private struct ModelRequiredPrompt: View {
    var body: some View {
        VStack(spacing: 24) {
            Divider().background(AppTheme.ink)

            VStack(alignment: .leading, spacing: 12) {
                Text("LOCAL MODEL REQUIRED")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.ink)
                Text("Transcription uses on-device Gemma 4 E4B. Download the model (3.7 GB) from the System tab to enable this feature.")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(AppTheme.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(AppTheme.paper)
            .overlay(Rectangle().stroke(AppTheme.ink, lineWidth: 1))
        }
        .padding(16)
    }
}
