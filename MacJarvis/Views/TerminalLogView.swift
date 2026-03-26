import SwiftUI

struct TerminalLogView: View {
    @Environment(\.theme) var theme
    @Environment(OpenClawService.self) private var clawService
    @Environment(VoiceService.self) private var voiceService

    @State private var isInputMode = false
    @State private var inputText = ""
    @State private var isPTTActive = false
    @State private var pttDelayTask: Task<Void, Never>?

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Terminal header
            HStack(spacing: 6) {
                Circle()
                    .fill(theme.primary)
                    .frame(width: 6, height: 6)

                Text("Logs_Live :: Extended_Readout_v4")
                    .font(AppTheme.monoFont(size: 10))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(theme.onSurfaceVariant)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle().fill(theme.outlineVariant.opacity(0.1)).frame(height: 1)
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(clawService.messages) { msg in
                            terminalLine(for: msg)
                                .id(msg.id)
                        }
                    }
                }
                .onChange(of: clawService.messages.count) {
                    if let last = clawService.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // Command area
            if isInputMode {
                HStack(spacing: 8) {
                    TextField("Enter command...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(AppTheme.monoFont(size: 12))
                        .foregroundColor(theme.primary)
                        .padding(8)
                        .background(theme.surfaceContainer)
                        .onSubmit { sendMessage() }

                    Button("SEND") { sendMessage() }
                        .font(AppTheme.headlineFont(size: 11))
                        .foregroundColor(theme.surface)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(theme.primary)
                        .buttonStyle(.plain)

                    Button("ESC") {
                        isInputMode = false
                        inputText = ""
                    }
                    .font(AppTheme.labelFont(size: 10))
                    .foregroundColor(theme.onSurfaceVariant)
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                    Text(commandButtonLabel)
                        .font(AppTheme.headlineFont(size: 12))
                        .tracking(3)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundColor(theme.surface)
                .background(commandButtonColor)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard pttDelayTask == nil && !isPTTActive else { return }
                            // Schedule PTT start after 0.3s hold
                            pttDelayTask = Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(300))
                                guard !Task.isCancelled else { return }
                                if !voiceService.isRecording && !voiceService.isTranscribing {
                                    isPTTActive = true
                                    voiceService.startRecording()
                                }
                            }
                        }
                        .onEnded { _ in
                            if voiceService.isRecording {
                                // Long press release — stop and transcribe
                                isPTTActive = false
                                pttDelayTask?.cancel()
                                pttDelayTask = nil
                                Task { await voiceService.stopAndTranscribe() }
                            } else {
                                // Short tap — cancel PTT, enter text input
                                pttDelayTask?.cancel()
                                pttDelayTask = nil
                                isPTTActive = false
                                isInputMode = true
                            }
                        }
                )
                .onChange(of: voiceService.isTranscribing) { _, isTranscribing in
                    if !isTranscribing && !voiceService.transcript.isEmpty {
                        // Auto-send transcribed text
                        clawService.sendMessage(voiceService.transcript)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(theme.surfaceContainerLowest)
        .overlay(Rectangle().stroke(theme.outlineVariant.opacity(0.2), lineWidth: 1))
    }

    private var commandButtonColor: Color {
        if voiceService.isRecording { return theme.error }
        if voiceService.isTranscribing { return theme.secondary }
        return theme.primary
    }

    private var commandButtonLabel: String {
        if voiceService.isRecording { return "LISTENING..." }
        if voiceService.isTranscribing { return "TRANSCRIBING..." }
        if !voiceService.recordingError.isEmpty { return voiceService.recordingError }
        if !voiceService.isModelLoaded { return voiceService.modelLoadProgress.isEmpty ? "LOADING MODEL..." : voiceService.modelLoadProgress }
        return "NEW COMMAND"
    }

    private func terminalLine(for msg: ChatMessage) -> some View {
        let timestamp = timeFormatter.string(from: msg.timestamp)
        let prefix = msg.role == .user ? "USER" : "CLAW"
        let color = msg.role == .assistant ? theme.primary : theme.onSurface

        return HStack(alignment: .top, spacing: 0) {
            Text("[\(timestamp)] ")
                .foregroundColor(theme.onSurfaceVariant)
            Text(">> \(prefix): ")
                .foregroundColor(color)
            Text(msg.content)
                .foregroundColor(color.opacity(0.7))
        }
        .font(AppTheme.monoFont(size: 11))
        .lineLimit(nil)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        clawService.sendMessage(text)
        inputText = ""
        isInputMode = false
    }
}
