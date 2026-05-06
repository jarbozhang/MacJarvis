import Foundation
import AppKit

@Observable
@MainActor
class TerminalSessionService {
    private var terminals: [ActiveTab: PseudoTerminalView] = [:]

    func getOrCreateTerminal(for tab: ActiveTab) -> PseudoTerminalView {
        if let existing = terminals[tab] {
            return existing
        }

        let terminal = PseudoTerminalView(frame: .zero)
        terminal.translatesAutoresizingMaskIntoConstraints = false
        if let command = tab.command {
            terminal.start(command: command, arguments: tab.arguments, environment: terminalEnvironment())
        }

        terminals[tab] = terminal
        return terminal
    }

    func stopAll() {
        for (_, terminal) in terminals {
            terminal.stop()
        }
        terminals.removeAll()
    }

    private nonisolated func terminalEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["CLICOLOR"] = "1"
        env["HOME"] = NSHomeDirectory()

        let commonPaths = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]
        if let currentPath = env["PATH"] {
            env["PATH"] = (commonPaths + [currentPath]).joined(separator: ":")
        } else {
            env["PATH"] = commonPaths.joined(separator: ":")
        }
        return env
    }
}
