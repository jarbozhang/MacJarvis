import SwiftUI

struct TokenColumnView: View {
    @Environment(\.theme) var theme
    @Environment(TokenService.self) private var tokenService
    @Environment(SettingsService.self) private var settings

    var body: some View {
        VStack(spacing: AppTheme.cardSpacing) {
            if let codex = tokenService.tools.first(where: { $0.id == "codex" }) {
                TokenCard(usage: codex, accentColor: theme.primary,
                    subtitle: (codex.modelName ?? "--").uppercased(),
                    iconName: "chevron.left.forwardslash.chevron.right",
                    budget: 0)
            }
            if let gemini = tokenService.tools.first(where: { $0.id == "gemini" }) {
                TokenCard(usage: gemini, accentColor: theme.secondary,
                    subtitle: (gemini.modelName ?? "--").uppercased(),
                    iconName: "memorychip",
                    budget: 0)
            }
            if let claude = tokenService.tools.first(where: { $0.id == "claude" }) {
                TokenCard(usage: claude, accentColor: theme.tertiary,
                    subtitle: (claude.planName ?? "--").uppercased(),
                    iconName: "brain.head.profile",
                    budget: 0)
            }
        }
    }
}
