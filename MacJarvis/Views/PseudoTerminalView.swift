import AppKit
import Darwin

final class PseudoTerminalView: NSView {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private var process: Process?
    private var readSource: DispatchSourceRead?
    private var masterFileDescriptor: Int32 = -1
    private var slaveFileHandle: FileHandle?
    private var hasStarted = false

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
        scrollView.frame = bounds
        textView.minSize = NSSize(width: bounds.width, height: 0)
        textView.maxSize = NSSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
        resizePTY()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    func start(command: String, arguments: [String], environment: [String: String]) {
        guard !hasStarted else { return }
        hasStarted = true

        guard let execPath = Self.findExecutable(command, in: environment["PATH"] ?? "") else {
            append("Error: '\(command)' not found in PATH\n")
            return
        }

        var master: Int32 = -1
        var slave: Int32 = -1
        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            append("Error: failed to allocate pseudo terminal\n")
            return
        }

        masterFileDescriptor = master
        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: true)
        slaveFileHandle = slaveHandle

        let process = Process()
        process.executableURL = URL(fileURLWithPath: execPath)
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.append("\n[process exited: \(process.terminationStatus)]\n")
            }
        }

        do {
            startReader(on: master)
            try process.run()
            self.process = process
            resizePTY()
        } catch {
            append("Error: failed to start \(command): \(error.localizedDescription)\n")
            cleanupPTY()
        }
    }

    func stop() {
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
        cleanupPTY()
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            super.keyDown(with: event)
            return
        }

        if event.modifierFlags.contains(.control),
           let chars = event.charactersIgnoringModifiers?.lowercased(),
           chars == "c" {
            write(bytes: [3])
            return
        }

        switch event.keyCode {
        case 36, 76:
            write(string: "\r")
        case 48:
            write(string: "\t")
        case 51, 117:
            write(bytes: [127])
        case 123:
            write(string: "\u{1B}[D")
        case 124:
            write(string: "\u{1B}[C")
        case 125:
            write(string: "\u{1B}[B")
        case 126:
            write(string: "\u{1B}[A")
        default:
            if let text = event.characters {
                write(string: text)
            }
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "v",
           let text = NSPasteboard.general.string(forType: .string) {
            write(string: text)
            return true
        }
        return super.performKeyEquivalent(with: event)
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
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        addSubview(scrollView)
    }

    private func startReader(on fileDescriptor: Int32) {
        let source = DispatchSource.makeReadSource(fileDescriptor: fileDescriptor, queue: DispatchQueue.global(qos: .userInitiated))
        source.setEventHandler { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 4096)
            let count = read(fileDescriptor, &buffer, buffer.count)
            guard count > 0 else {
                self?.readSource?.cancel()
                return
            }

            let data = Data(buffer.prefix(count))
            let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async {
                self?.append(text)
            }
        }
        source.setCancelHandler { close(fileDescriptor) }
        readSource = source
        source.resume()
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

    private func write(string: String) {
        write(bytes: Array(string.utf8))
    }

    private func write(bytes: [UInt8]) {
        guard masterFileDescriptor >= 0 else { return }
        bytes.withUnsafeBytes { pointer in
            guard let baseAddress = pointer.baseAddress else { return }
            _ = Darwin.write(masterFileDescriptor, baseAddress, bytes.count)
        }
    }

    private func resizePTY() {
        guard masterFileDescriptor >= 0 else { return }

        let charSize = "M".size(withAttributes: [.font: Self.terminalFont])
        let columns = max(20, Int((bounds.width - 16) / max(charSize.width, 1)))
        let rows = max(8, Int((bounds.height - 16) / max(charSize.height, 1)))
        var size = winsize(
            ws_row: UInt16(rows),
            ws_col: UInt16(columns),
            ws_xpixel: UInt16(max(bounds.width, 0)),
            ws_ypixel: UInt16(max(bounds.height, 0))
        )
        _ = ioctl(masterFileDescriptor, TIOCSWINSZ, &size)
    }

    private func cleanupPTY() {
        readSource?.cancel()
        readSource = nil
        slaveFileHandle = nil
        masterFileDescriptor = -1
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

    private static let terminalFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
}
