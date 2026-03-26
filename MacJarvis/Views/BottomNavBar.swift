import SwiftUI

struct BottomNavBar: View {
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 0) {
            navItem(
                icon: { LobsterShape(bodyColor: theme.surface).frame(width: 20, height: 20) },
                label: "OPENCLAW", isActive: true)
            navItem(
                icon: { Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 16)) },
                label: "CODEX", isActive: false)
            navItem(
                icon: { Image(systemName: "memorychip").font(.system(size: 16)) },
                label: "GEMINI", isActive: false)
            navItem(
                icon: { Image(systemName: "brain.head.profile").font(.system(size: 16)) },
                label: "CLAUDE", isActive: false)
        }
        .frame(height: 48)
        .background(theme.surface)
        .pixelGrid()
        .overlay(alignment: .top) {
            Rectangle().fill(theme.surfaceContainerHigh).frame(height: 1)
        }
    }

    private func navItem<Icon: View>(@ViewBuilder icon: () -> Icon, label: String, isActive: Bool) -> some View {
        VStack(spacing: 2) {
            icon()
            Text(label)
                .font(AppTheme.headlineFont(size: 8))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .foregroundColor(isActive ? theme.surface : theme.onSurface.opacity(0.5))
        .background(isActive ? theme.primary : Color.clear)
    }
}
