import Foundation

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

    init() {
        if let raw = UserDefaults.standard.string(forKey: "currentTheme"),
           let theme = AppTheme(rawValue: raw) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .redact
        }
        self.openClawHost = UserDefaults.standard.string(forKey: "openClawHost") ?? "127.0.0.1"
        let storedPort = UserDefaults.standard.integer(forKey: "openClawPort")
        self.openClawPort = storedPort > 0 ? storedPort : 18789
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
    }
}
