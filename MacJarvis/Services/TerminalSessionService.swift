import Foundation
import SwiftTerm

@Observable
@MainActor
class TerminalSessionService {
    private var terminals: [ActiveTab: LocalProcessTerminalView] = [:]

    func getOrCreateTerminal(for tab: ActiveTab) -> LocalProcessTerminalView {
        if let existing = terminals[tab] {
            return existing
        }

        let termView = LocalProcessTerminalView(frame: .zero)

        // Find the CLI binary path
        guard let command = tab.command else { return termView }

        // Set up environment
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        // Ensure common paths are in PATH
        let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin"]
        if let path = env["PATH"] {
            env["PATH"] = (extraPaths + [path]).joined(separator: ":")
        }

        // Find the binary
        let shellPath = findExecutable(command, in: env["PATH"] ?? "")

        if let shellPath {
            let args = [shellPath] + tab.arguments
            termView.startProcess(executable: shellPath, args: args, environment: env.map { "\($0.key)=\($0.value)" }, execName: command)
        } else {
            // CLI not found — show error in terminal
            termView.startProcess(executable: "/bin/echo", args: ["/bin/echo", "Error: '\(command)' not found in PATH"], environment: nil, execName: "echo")
        }

        terminals[tab] = termView
        return termView
    }

    func stopAll() {
        for (_, termView) in terminals {
            // LocalProcessTerminalView terminates its process when deallocated
            // Force terminate by sending SIGTERM
            if let pid = termView.shellPid {
                kill(pid, SIGTERM)
            }
        }
        terminals.removeAll()
    }

    private nonisolated func findExecutable(_ name: String, in pathString: String) -> String? {
        let paths = pathString.split(separator: ":").map(String.init)
        for dir in paths {
            let fullPath = (dir as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }
}
