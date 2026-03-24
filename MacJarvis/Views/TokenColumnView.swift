import SwiftUI

struct TokenColumnView: View {
    @Environment(TokenService.self) private var tokenService
    @Environment(SettingsService.self) private var settings

    var body: some View {
        VStack(spacing: CyberTheme.cardSpacing) {
            if let codex = tokenService.tools.first(where: { $0.id == "codex" }) {
                TokenCard(usage: codex, accentColor: CyberTheme.primary,
                    subtitle: "v4.2-STABLE", iconName: "chevron.left.forwardslash.chevron.right",
                    budget: settings.codexDailyBudget)
            }
            if let gemini = tokenService.tools.first(where: { $0.id == "gemini" }) {
                TokenCard(usage: gemini, accentColor: CyberTheme.secondary,
                    subtitle: "FLASH-ULTRA", iconName: "memorychip",
                    budget: settings.geminiDailyBudget)
            }
            if let claude = tokenService.tools.first(where: { $0.id == "claude" }) {
                TokenCard(usage: claude, accentColor: CyberTheme.tertiary,
                    subtitle: "OPUS-DIRECT", iconName: "brain.head.profile",
                    budget: settings.claudeDailyBudget)
            }
        }
    }
}
