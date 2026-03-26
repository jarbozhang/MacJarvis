import SwiftUI

struct SettingsView: View {
    @Environment(SettingsService.self) private var settings
    @Environment(OpenClawService.self) private var clawService
    @Environment(\.theme) var theme
    @Binding var isPresented: Bool

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("SETTINGS")
                    .font(AppTheme.headlineFont(size: 12))
                    .tracking(3)
                    .foregroundColor(theme.primary)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(theme.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }

            sectionHeader("THEME")

            HStack(spacing: 8) {
                ForEach(AppTheme.allCases, id: \.self) { t in
                    Button {
                        settings.currentTheme = t
                    } label: {
                        Text(t == .redact ? "REDACT" : "MATRIX")
                            .font(AppTheme.headlineFont(size: 9))
                            .tracking(2)
                            .foregroundColor(settings.currentTheme == t ? theme.surface : theme.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(settings.currentTheme == t ? theme.primary : theme.surfaceContainerLowest)
                    }
                    .buttonStyle(.plain)
                }
            }

            sectionHeader("OPENCLAW CONNECTION")

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HOST").font(AppTheme.labelFont(size: 7)).foregroundColor(theme.onSurfaceVariant)
                    TextField("127.0.0.1", text: $settings.openClawHost)
                        .textFieldStyle(.plain)
                        .font(AppTheme.monoFont(size: 10))
                        .foregroundColor(theme.onSurface)
                        .padding(6)
                        .background(theme.surfaceContainerLowest)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("PORT").font(AppTheme.labelFont(size: 7)).foregroundColor(theme.onSurfaceVariant)
                    TextField("18789", value: $settings.openClawPort, format: .number)
                        .textFieldStyle(.plain)
                        .font(AppTheme.monoFont(size: 10))
                        .foregroundColor(theme.onSurface)
                        .padding(6)
                        .background(theme.surfaceContainerLowest)
                        .frame(width: 80)
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOKEN").font(AppTheme.labelFont(size: 7)).foregroundColor(theme.onSurfaceVariant)
                    SecureField("optional", text: $settings.openClawToken)
                        .textFieldStyle(.plain)
                        .font(AppTheme.monoFont(size: 10))
                        .foregroundColor(theme.onSurface)
                        .padding(6)
                        .background(theme.surfaceContainerLowest)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("AGENT").font(AppTheme.labelFont(size: 7)).foregroundColor(theme.onSurfaceVariant)
                    TextField("main", text: $settings.openClawAgent)
                        .textFieldStyle(.plain)
                        .font(AppTheme.monoFont(size: 10))
                        .foregroundColor(theme.onSurface)
                        .padding(6)
                        .background(theme.surfaceContainerLowest)
                        .frame(width: 80)
                }
            }

            Button {
                let h = settings.openClawHost
                let p = settings.openClawPort
                let t = settings.openClawToken
                let a = settings.openClawAgent
                Task {
                    await clawService.connect(host: h, port: p, token: t, agent: a)
                }
            } label: {
                Text("CONNECT")
                    .font(AppTheme.headlineFont(size: 9))
                    .tracking(2)
                    .foregroundColor(theme.surface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(clawService.status == .running ? theme.primary.opacity(0.5) : theme.primary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

        }
        .padding(16)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .background(theme.surfaceContainer)
        .contentShape(Rectangle())
        .overlay(Rectangle().stroke(theme.outlineVariant.opacity(0.3), lineWidth: 1))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.headlineFont(size: 8))
            .tracking(2)
            .foregroundColor(theme.onSurfaceVariant.opacity(0.6))
    }
}
