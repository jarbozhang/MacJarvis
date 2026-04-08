import SwiftUI

struct BottomNavBar: View {
    @Environment(\.theme) var theme
    @Environment(\.scaleFactor) var scale

    var body: some View {
        HStack(spacing: 0) {
            navItem(
                icon: { LobsterShape(bodyColor: theme.surface).frame(width: 20 * scale, height: 20 * scale) },
                label: "OPENCLAW", isActive: true)
            navItem(
                icon: { Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 16 * scale)) },
                label: "CODEX", isActive: false)
            navItem(
                icon: { Image(systemName: "memorychip").font(.system(size: 16 * scale)) },
                label: "GEMINI", isActive: false)
            navItem(
                icon: { Image(systemName: "brain.head.profile").font(.system(size: 16 * scale)) },
                label: "CLAUDE", isActive: false)
        }
        .frame(height: 48 * scale)
        .background(theme.surface.opacity(0.7))
        .pixelGrid()
        .overlay(alignment: .top) {
            Rectangle().fill(theme.surfaceContainerHigh).frame(height: 1)
        }
    }

    private func navItem<Icon: View>(@ViewBuilder icon: () -> Icon, label: String, isActive: Bool) -> some View {
        VStack(spacing: 2 * scale) {
            icon()
            Text(label)
                .font(AppTheme.headlineFont(size: 8 * scale))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4 * scale)
        .foregroundColor(isActive ? theme.surface : theme.onSurface.opacity(0.5))
        .background(isActive ? theme.primary : Color.clear)
    }
}
