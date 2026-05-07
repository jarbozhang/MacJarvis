import Foundation

enum ActiveTab: String, CaseIterable {
    case openclaw
    case codex
    case gemini
    case claude

    var command: String? {
        switch self {
        case .openclaw: return nil
        case .codex: return "codex"
        case .gemini: return "gemini"
        case .claude: return "claude"
        }
    }

    var arguments: [String] {
        switch self {
        case .openclaw: return []
        case .codex:
            return [
                "exec",
                "--dangerously-bypass-approvals-and-sandbox",
                "--color",
                "never",
                "--json",
            ]
        case .gemini:
            return [
                "--yolo",
                "--output-format",
                "text",
                "--prompt",
            ]
        case .claude:
            return [
                "--print",
                "--dangerously-skip-permissions",
                "--output-format",
                "text",
            ]
        }
    }

    var isTerminalTab: Bool {
        self != .openclaw
    }
}
