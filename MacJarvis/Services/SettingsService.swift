import Foundation

enum UsageMode: String, CaseIterable {
    case subscription
    case api
}

@Observable
@MainActor
class SettingsService {
    var currentTheme: AppTheme {
        didSet { UserDefaults.standard.set(currentTheme.rawValue, forKey: "currentTheme") }
    }

    var openClawHost: String {
        didSet { UserDefaults.standard.set(openClawHost, forKey: "openClawHost") }
    }

    var openClawPort: Int {
        didSet { UserDefaults.standard.set(openClawPort, forKey: "openClawPort") }
    }

    var codexDailyBudget: Int = 100_000 {
        didSet { UserDefaults.standard.set(codexDailyBudget, forKey: "codexDailyBudget") }
    }
    var claudeDailyBudget: Int = 500_000 {
        didSet { UserDefaults.standard.set(claudeDailyBudget, forKey: "claudeDailyBudget") }
    }
    var geminiDailyBudget: Int = 1_000_000 {
        didSet { UserDefaults.standard.set(geminiDailyBudget, forKey: "geminiDailyBudget") }
    }

    var openClawToken: String = "" {
        didSet { UserDefaults.standard.set(openClawToken, forKey: "openClawToken") }
    }
    var openClawAgent: String = "main" {
        didSet { UserDefaults.standard.set(openClawAgent, forKey: "openClawAgent") }
    }

    var enableTTS: Bool = true {
        didSet { UserDefaults.standard.set(enableTTS, forKey: "enableTTS") }
    }

    var claudeMode: UsageMode = .subscription {
        didSet { UserDefaults.standard.set(claudeMode.rawValue, forKey: "claudeMode") }
    }
    var codexMode: UsageMode = .subscription {
        didSet { UserDefaults.standard.set(codexMode.rawValue, forKey: "codexMode") }
    }

    /// True when token has never been configured — UI should prompt user
    var needsTokenSetup: Bool {
        openClawToken.isEmpty
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: "currentTheme"),
           let theme = AppTheme(rawValue: raw) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .redact
        }
        // Default host/port — only use stored value if it was explicitly saved
        if UserDefaults.standard.object(forKey: "openClawHost") != nil {
            self.openClawHost = UserDefaults.standard.string(forKey: "openClawHost") ?? "127.0.0.1"
        } else {
            self.openClawHost = "127.0.0.1"
        }
        if UserDefaults.standard.object(forKey: "openClawPort") != nil {
            let storedPort = UserDefaults.standard.integer(forKey: "openClawPort")
            self.openClawPort = storedPort > 0 ? storedPort : 18789
        } else {
            self.openClawPort = 18789
        }
        if UserDefaults.standard.object(forKey: "codexDailyBudget") != nil {
            codexDailyBudget = UserDefaults.standard.integer(forKey: "codexDailyBudget")
        }
        if UserDefaults.standard.object(forKey: "claudeDailyBudget") != nil {
            claudeDailyBudget = UserDefaults.standard.integer(forKey: "claudeDailyBudget")
        }
        if UserDefaults.standard.object(forKey: "geminiDailyBudget") != nil {
            geminiDailyBudget = UserDefaults.standard.integer(forKey: "geminiDailyBudget")
        }
        if let token = UserDefaults.standard.string(forKey: "openClawToken") {
            openClawToken = token
        }
        if let agent = UserDefaults.standard.string(forKey: "openClawAgent"), !agent.isEmpty {
            openClawAgent = agent
        }
        if UserDefaults.standard.object(forKey: "enableTTS") != nil {
            enableTTS = UserDefaults.standard.bool(forKey: "enableTTS")
        }
        if let raw = UserDefaults.standard.string(forKey: "claudeMode"),
           let mode = UsageMode(rawValue: raw) {
            claudeMode = mode
        }
        if let raw = UserDefaults.standard.string(forKey: "codexMode"),
           let mode = UsageMode(rawValue: raw) {
            codexMode = mode
        }
    }
}
