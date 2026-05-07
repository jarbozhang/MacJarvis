import SwiftUI

struct BottomNavBar: View {
    @Environment(\.theme) var theme
    @Environment(\.scaleFactor) var scale
    @Binding var activeTab: ActiveTab

    var body: some View {
        HStack(spacing: 0) {
            navItem(
                tab: .openclaw,
                icon: {
                    let isActive = activeTab == .openclaw
                    LobsterShape(
                        bodyColor: isActive ? theme.surface : theme.onSurface.opacity(0.5),
                        antennaColor: isActive ? theme.surface : theme.onSurface.opacity(0.5),
                        eyeHighlightColor: isActive ? theme.primary : theme.secondary
                    )
                    .frame(width: 20 * scale, height: 20 * scale)
                },
                label: "OPENCLAW")
            navItem(
                tab: .codex,
                icon: { Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 16 * scale)) },
                label: "CODEX")
            navItem(
                tab: .gemini,
                icon: { Image(systemName: "memorychip").font(.system(size: 16 * scale)) },
                label: "GEMINI")
            navItem(
                tab: .claude,
                icon: { Image(systemName: "brain.head.profile").font(.system(size: 16 * scale)) },
                label: "CLAUDE")
        }
        .frame(height: 48 * scale)
        .background(theme.surface.opacity(0.7))
        .pixelGrid()
        .clipped()
        .overlay(alignment: .top) {
            Rectangle().fill(theme.primary.opacity(0.25)).frame(height: 1)
        }
    }

    private func navItem<Icon: View>(tab: ActiveTab, @ViewBuilder icon: () -> Icon, label: String) -> some View {
        Button {
            activeTab = tab
        } label: {
            VStack(spacing: 2 * scale) {
                icon()
                Text(label)
                    .font(AppTheme.headlineFont(size: 8 * scale))
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundColor(activeTab == tab ? theme.surface : theme.onSurface.opacity(0.5))
            .background(activeTab == tab ? theme.primary : Color.clear)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48 * scale)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
}
