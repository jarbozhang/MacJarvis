import Foundation
import AVFoundation
import os
import WhisperKit

private let logger = Logger(subsystem: "com.macjarvis", category: "VoiceService")

private func logToFile(_ msg: String) {
    let path = "/tmp/macjarvis-debug.log"
    let line = "[\(Date())] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: path) {
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }
}

@Observable
@MainActor
class VoiceService {
    var isRecording: Bool = false
    var isTranscribing: Bool = false
    var isSpeaking: Bool = false
    var transcript: String = ""
    var audioLevel: Float = 0.0
    var isModelLoaded: Bool = false
    var modelLoadProgress: String = ""
    var shouldAskToDownloadModel: Bool = false
    var isLoadingModel: Bool {
        isModelLoading
    }
    var isVoiceModelUnavailable: Bool {
        modelLoadProgress == "MODEL MISSING" || modelLoadProgress == "LOAD FAILED"
    }

    private var isModelLoading: Bool = false
    private var whisperKit: WhisperKit?
    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private let synthesizer = AVSpeechSynthesizer()
    private let modelName = "openai_whisper-base"
    private let modelRepo = "argmaxinc/whisperkit-coreml"
    private let promptedForModelDownloadKey = "MacJarvis.promptedForVoiceModelDownload"
    private let modelFolderPathKey = "MacJarvis.voiceModelFolderPath"

    var canRecord: Bool {
        isModelLoaded && !isTranscribing
    }

    var modelStatusLabel: String {
        if isModelLoaded { return "MODEL READY" }
        if !modelLoadProgress.isEmpty { return modelLoadProgress }
        return "MODEL NOT LOADED"
    }

    // MARK: - Model Loading

    func loadModel() {
        loadModel(allowDownload: false)
    }

    func prepareForRecording() {
        if isModelLoaded || isModelLoading || shouldAskToDownloadModel || isVoiceModelUnavailable { return }
        loadModel()
    }

    func promptForModelDownload() {
        shouldAskToDownloadModel = true
        recordingError = ""
    }

    func downloadModel() {
        UserDefaults.standard.set(true, forKey: promptedForModelDownloadKey)
        shouldAskToDownloadModel = false
        loadModel(allowDownload: true)
    }

    func skipModelDownload() {
        UserDefaults.standard.set(true, forKey: promptedForModelDownloadKey)
        shouldAskToDownloadModel = false
        isModelLoading = false
        modelLoadProgress = "MODEL MISSING"
    }

    private func loadModel(allowDownload: Bool) {
        guard !isModelLoaded, !isModelLoading else {
            logToFile("[VoiceService] Model already loaded or loading, skipping")
            return
        }
        isModelLoading = true
        modelLoadProgress = "LOADING..."
        logToFile("[VoiceService] Starting model load...")

        Task.detached {
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent("MacJarvis", isDirectory: true)
            let modelsBaseURL = appSupportURL?.appendingPathComponent("models", isDirectory: true)
            let savedModelDir = UserDefaults.standard.string(forKey: self.modelFolderPathKey).flatMap {
                $0.contains("/Documents/") ? nil : $0
            }
            let legacyModelDir = modelsBaseURL?
                .appendingPathComponent(self.modelRepo, isDirectory: true)
                .appendingPathComponent(self.modelName, isDirectory: true)
                .path
            let localModelDir = [savedModelDir, legacyModelDir]
                .compactMap { $0 }
                .first { self.hasModelConfig(at: $0) }
            logToFile("[VoiceService] Init WhisperKit, localModel=\(localModelDir ?? "none"), allowDownload=\(allowDownload)")

            do {
                let kit: WhisperKit
                if let localModelDir {
                    kit = try await WhisperKit(
                        modelFolder: localModelDir,
                        computeOptions: ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine),
                        verbose: false,
                        logLevel: .error,
                        prewarm: false,
                        load: true,
                        download: false
                    )
                    UserDefaults.standard.set(localModelDir, forKey: self.modelFolderPathKey)
                } else if allowDownload, let modelsBaseURL {
                    try FileManager.default.createDirectory(at: modelsBaseURL, withIntermediateDirectories: true)
                    await MainActor.run { self.modelLoadProgress = "DOWNLOADING..." }
                    kit = try await WhisperKit(
                        model: self.modelName,
                        downloadBase: modelsBaseURL,
                        modelRepo: self.modelRepo,
                        computeOptions: ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine),
                        verbose: false,
                        logLevel: .error,
                        prewarm: false,
                        load: true,
                        download: true
                    )
                    if let modelFolder = kit.modelFolder?.path {
                        UserDefaults.standard.set(modelFolder, forKey: self.modelFolderPathKey)
                        logToFile("[VoiceService] Downloaded model folder: \(modelFolder)")
                    }
                } else {
                    let hasPrompted = UserDefaults.standard.bool(forKey: self.promptedForModelDownloadKey)
                    await MainActor.run {
                        self.isModelLoading = false
                        self.modelLoadProgress = "MODEL MISSING"
                        self.recordingError = "MODEL MISSING"
                        self.shouldAskToDownloadModel = !hasPrompted
                    }
                    logToFile("[VoiceService] Model missing, prompt=\(!hasPrompted)")
                    return
                }
                logToFile("[VoiceService] WhisperKit loaded OK")
                await MainActor.run {
                    self.whisperKit = kit
                    self.isModelLoaded = true
                    self.isModelLoading = false
                    self.modelLoadProgress = ""
                }
            } catch {
                logToFile("[VoiceService] Load failed: \(error)")
                await MainActor.run {
                    self.isModelLoading = false
                    self.modelLoadProgress = "LOAD FAILED"
                    self.recordingError = "LOAD FAILED"
                }
            }
        }
    }

    private nonisolated func hasModelConfig(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: URL(fileURLWithPath: path).appendingPathComponent("config.json").path)
    }

    // MARK: - Recording

    var recordingError: String = ""

    func startRecording() {
        prepareForRecording()
        guard canRecord else {
            if !isModelLoaded {
                recordingError = isModelLoading ? "MODEL LOADING..." : (modelLoadProgress.isEmpty ? "MODEL MISSING" : modelLoadProgress)
            } else if isTranscribing {
                recordingError = "BUSY TRANSCRIBING"
            }
            logToFile("[VoiceService] canRecord=false, isModelLoaded=\(self.isModelLoaded), isTranscribing=\(self.isTranscribing)")
            return
        }
        recordingError = ""

        audioBuffer = []
        isRecording = true

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // WhisperKit expects 16kHz mono Float32
        guard let whisperFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false) else {
            isRecording = false
            return
        }

        let nativeFormat = inputNode.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: nativeFormat, to: whisperFormat) else {
            isRecording = false
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            guard let self else { return }

            // Resample to 16kHz mono
            let ratio = whisperFormat.sampleRate / nativeFormat.sampleRate
            let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: outputFrameCount) else { return }

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if error == nil, let channelData = convertedBuffer.floatChannelData?[0] {
                let frameCount = Int(convertedBuffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
                let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
                let rms = sqrt(sumOfSquares / Float(max(frameCount, 1)))
                let level = min(rms * 5.0, 1.0)
                Task { @MainActor in
                    self.audioBuffer.append(contentsOf: samples)
                    self.audioLevel = level
                }
            }
        }

        do {
            try engine.start()
            audioEngine = engine
            logToFile("[VoiceService] Recording started, format: \(nativeFormat)")
        } catch {
            logToFile("[VoiceService] Engine start failed: \(error)")
            recordingError = "MIC ERROR: \(error.localizedDescription)"
            isRecording = false
        }
    }

    func stopAndTranscribe() async -> String? {
        guard isRecording else { return nil }

        // Stop engine first, then remove tap to avoid audio IO thread crash
        let engine = audioEngine
        audioEngine = nil
        isRecording = false
        audioLevel = 0.0

        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)

        isTranscribing = true

        guard let whisperKit, !audioBuffer.isEmpty else {
            isTranscribing = false
            return nil
        }

        let samples = audioBuffer
        audioBuffer = []

        // Run Whisper inference on background thread to avoid blocking UI
        let result: String? = await Task.detached {
            do {
                let options = DecodingOptions(
                    task: .transcribe,
                    language: "zh",
                    temperatureFallbackCount: 0,
                    usePrefillPrompt: true,
                    detectLanguage: false
                )
                let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
                let text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                // Filter out WhisperKit blank/noise markers
                let cleaned = text.replacingOccurrences(of: "[BLANK_AUDIO]", with: "").trimmingCharacters(in: .whitespaces)
                return cleaned.isEmpty ? nil : cleaned
            } catch {
                return nil
            }
        }.value

        transcript = result ?? ""
        isTranscribing = false
        return result
    }

    // MARK: - TTS

    func speak(_ text: String) {
        stopSpeaking()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        isSpeaking = true
        synthesizer.speak(utterance)

        // Monitor completion
        Task {
            while synthesizer.isSpeaking {
                try? await Task.sleep(for: .milliseconds(200))
            }
            isSpeaking = false
        }
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }
    }

    func cleanup() {
        let engine = audioEngine
        audioEngine = nil
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        whisperKit = nil
        isModelLoaded = false
    }
}
