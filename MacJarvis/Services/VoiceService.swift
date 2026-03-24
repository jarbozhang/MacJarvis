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

    private var isModelLoading: Bool = false
    private var whisperKit: WhisperKit?
    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private let synthesizer = AVSpeechSynthesizer()

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
        guard !isModelLoaded, !isModelLoading else {
            logToFile("[VoiceService] Model already loaded or loading, skipping")
            return
        }
        isModelLoading = true
        modelLoadProgress = "LOADING..."
        logToFile("[VoiceService] Starting model load...")

        Task.detached {
            let localModelDir = NSHomeDirectory() + "/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-base"
            let hasLocalModel = FileManager.default.fileExists(atPath: localModelDir + "/config.json")
            logToFile("[VoiceService] Init WhisperKit, localModel=\(hasLocalModel)")

            do {
                let kit: WhisperKit
                if hasLocalModel {
                    kit = try await WhisperKit(
                        modelFolder: localModelDir,
                        computeOptions: ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine),
                        verbose: false,
                        logLevel: .error,
                        prewarm: false,
                        load: true,
                        download: false
                    )
                } else {
                    await MainActor.run { self.modelLoadProgress = "DOWNLOADING..." }
                    kit = try await WhisperKit(
                        model: "openai_whisper-base",
                        computeOptions: ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine),
                        verbose: false,
                        logLevel: .error,
                        prewarm: false,
                        load: true,
                        download: true
                    )
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
                }
            }
        }
    }

    // MARK: - Recording

    var recordingError: String = ""

    func startRecording() {
        guard canRecord else {
            if !isModelLoaded {
                recordingError = "MODEL LOADING..."
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
