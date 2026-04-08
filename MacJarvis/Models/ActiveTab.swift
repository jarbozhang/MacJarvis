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
        case .codex: return ["--full-auto"]
        case .gemini: return ["--yolo"]
        case .claude: return ["--dangerously-skip-permissions"]
        }
    }

    var isTerminalTab: Bool {
        self != .openclaw
    }
}
