import AppKit

final class PseudoTerminalView: NSView, NSTextFieldDelegate {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let inputField = NSTextField()
    private let inputContainer = NSView()
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var command: String?
    private var arguments: [String] = []
    private var environment: [String: String] = [:]
    private var hasStarted = false
    private var streamBuffer = ""
    private var isShowingWorkingIndicator = false

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureViews()
    }

    deinit {
        stop()
    }

    override func layout() {
        super.layout()
        let inputHeight: CGFloat = 48
        scrollView.frame = NSRect(x: 0, y: inputHeight, width: bounds.width, height: max(bounds.height - inputHeight, 0))
        inputContainer.frame = NSRect(x: 0, y: 0, width: bounds.width, height: inputHeight)
        inputField.frame = NSRect(x: 14, y: 8, width: max(bounds.width - 28, 0), height: 32)
        textView.minSize = NSSize(width: bounds.width, height: 0)
        textView.maxSize = NSSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
    }

    override func mouseDown(with event: NSEvent) {
        focusInput()
        super.mouseDown(with: event)
    }

    func focusInput() {
        window?.makeFirstResponder(inputField)
    }

    func start(command: String, arguments: [String], environment: [String: String]) {
        guard !hasStarted else { return }
        hasStarted = true
        self.command = command
        self.arguments = arguments
        self.environment = environment

        guard Self.findExecutable(command, in: environment["PATH"] ?? "") != nil else {
            append("Error: '\(command)' not found in PATH\n")
            return
        }

        append("[\(command)] ready. Type a prompt and press Return.\n\n")
    }

    func stop() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil
        stderrPipe = nil

        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let movement = notification.userInfo?["NSTextMovement"] as? Int,
              movement == NSReturnTextMovement else {
            return
        }

        let prompt = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        inputField.stringValue = ""
        guard !prompt.isEmpty else { return }
        runPrompt(prompt)
    }

    private func configureViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.04, green: 0.045, blue: 0.05, alpha: 1).cgColor

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.font = Self.terminalFont
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        addSubview(scrollView)

        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.74).cgColor
        inputContainer.layer?.borderColor = NSColor.white.withAlphaComponent(0.34).cgColor
        inputContainer.layer?.borderWidth = 1
        addSubview(inputContainer)

        inputField.delegate = self
        inputField.isBezeled = true
        inputField.isBordered = true
        inputField.focusRingType = .none
        inputField.backgroundColor = NSColor(red: 0.015, green: 0.018, blue: 0.022, alpha: 1)
        inputField.textColor = .white
        inputField.font = Self.terminalFont
        inputField.placeholderString = "Message agent, then press Return"
        inputField.cell?.sendsActionOnEndEditing = true
        inputContainer.addSubview(inputField)
    }

    private func runPrompt(_ prompt: String) {
        if let process, process.isRunning {
            append("\n[busy] Current request is still running.\n")
            return
        }

        guard let command,
              let execPath = Self.findExecutable(command, in: environment["PATH"] ?? "") else {
            append("Error: agent command is unavailable\n")
            return
        }

        append("> \(prompt)\n\n")
        streamBuffer = ""
        showWorkingIndicator()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: execPath)
        process.arguments = arguments + [prompt]
        process.environment = environment
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
        process.standardInput = FileHandle(forReadingAtPath: "/dev/null")
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        self.process = process

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.appendStreamData(handle.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.appendStreamData(handle.availableData)
        }
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.stdoutPipe?.fileHandleForReading.readabilityHandler = nil
                self?.stderrPipe?.fileHandleForReading.readabilityHandler = nil
                self?.stdoutPipe = nil
                self?.stderrPipe = nil
                self?.process = nil
                self?.clearWorkingIndicator()
                if process.terminationStatus != 0 {
                    self?.append("\n[failed: \(process.terminationStatus)]\n\n")
                } else {
                    self?.append("\n")
                }
                self?.focusInput()
            }
        }

        do {
            try process.run()
        } catch {
            append("Error: failed to start \(command): \(error.localizedDescription)\n\n")
            self.process = nil
            self.stdoutPipe = nil
            self.stderrPipe = nil
        }
    }

    private func appendStreamData(_ data: Data) {
        guard !data.isEmpty else { return }
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let cleanText = Self.stripControlSequences(from: text)
        guard !cleanText.isEmpty else { return }

        if command == "codex", arguments.contains("--json") {
            appendCodexJSONStream(cleanText)
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.clearWorkingIndicator()
            self?.append(cleanText)
        }
    }

    private func appendCodexJSONStream(_ text: String) {
        streamBuffer += text

        var lines = streamBuffer.components(separatedBy: .newlines)
        streamBuffer = lines.popLast() ?? ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard trimmed.first == "{" else { continue }
            guard let data = trimmed.data(using: .utf8),
                  let event = try? JSONDecoder().decode(CodexStreamEvent.self, from: data) else {
                continue
            }

            if let text = event.item?.text, event.item?.type == "agent_message" {
                DispatchQueue.main.async { [weak self] in
                    self?.clearWorkingIndicator()
                    self?.append(text + "\n")
                }
            }
        }
    }

    private func showWorkingIndicator() {
        isShowingWorkingIndicator = true
        append("Working...\n")
    }

    private func clearWorkingIndicator() {
        guard isShowingWorkingIndicator else { return }
        isShowingWorkingIndicator = false

        guard let storage = textView.textStorage else { return }
        let marker = "Working...\n"
        let text = storage.string as NSString
        let range = text.range(of: marker, options: [.backwards])
        guard range.location != NSNotFound else { return }
        storage.deleteCharacters(in: range)
    }

    private func append(_ text: String) {
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor.white,
                .font: Self.terminalFont,
            ]
        )
        textView.textStorage?.append(attributed)
        textView.scrollToEndOfDocument(nil)
    }

    private static func findExecutable(_ name: String, in pathString: String) -> String? {
        for dir in pathString.split(separator: ":").map(String.init) {
            let path = (dir as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    private static func stripControlSequences(from text: String) -> String {
        var output = ""
        var index = text.startIndex

        while index < text.endIndex {
            if text[index] == "\u{1B}" {
                let next = text.index(after: index)
                guard next < text.endIndex else { break }

                switch text[next] {
                case "[":
                    index = skipCSI(in: text, from: text.index(after: next))
                case "]":
                    index = skipOSC(in: text, from: text.index(after: next))
                default:
                    index = text.index(after: next)
                }
                continue
            }

            if text[index] == "\r" {
                output.append("\n")
            } else if !text[index].isASCIIControl || text[index] == "\n" || text[index] == "\t" {
                output.append(text[index])
            }
            index = text.index(after: index)
        }

        return output
    }

    private static func skipCSI(in text: String, from start: String.Index) -> String.Index {
        var index = start
        while index < text.endIndex {
            if let ascii = text[index].asciiValue, ascii >= 0x40, ascii <= 0x7E {
                return text.index(after: index)
            }
            index = text.index(after: index)
        }
        return text.endIndex
    }

    private static func skipOSC(in text: String, from start: String.Index) -> String.Index {
        var index = start
        while index < text.endIndex {
            if text[index] == "\u{7}" {
                return text.index(after: index)
            }
            if text[index] == "\u{1B}" {
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "\\" {
                    return text.index(after: next)
                }
            }
            index = text.index(after: index)
        }
        return text.endIndex
    }

    private static let terminalFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
}

private extension Character {
    var isASCIIControl: Bool {
        guard let scalar = unicodeScalars.first, unicodeScalars.count == 1 else { return false }
        return scalar.value < 0x20 || scalar.value == 0x7F
    }

    var asciiValue: UInt8? {
        guard let scalar = unicodeScalars.first, unicodeScalars.count == 1, scalar.value <= 0x7F else {
            return nil
        }
        return UInt8(scalar.value)
    }
}

private struct CodexStreamEvent: Decodable {
    let type: String
    let item: CodexStreamItem?
}

private struct CodexStreamItem: Decodable {
    let type: String
    let text: String?
}
