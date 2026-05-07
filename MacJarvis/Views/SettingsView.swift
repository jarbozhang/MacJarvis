import SwiftUI

struct SettingsView: View {
    @Environment(SettingsService.self) private var settings
    @Environment(OpenClawService.self) private var clawService
    @Environment(\.theme) var theme
    @Environment(\.scaleFactor) var scale
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

            sectionHeader("VOICE")

            HStack(spacing: 8) {
                Button {
                    settings.enableTTS.toggle()
                } label: {
                    Text(settings.enableTTS ? "ON" : "OFF")
                        .font(AppTheme.headlineFont(size: 9))
                        .tracking(2)
                        .foregroundColor(settings.enableTTS ? theme.surface : theme.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(settings.enableTTS ? theme.primary : theme.surfaceContainerLowest)
                }
                .buttonStyle(.plain)
            }

            sectionHeader("USAGE MODE")

            HStack(spacing: 8) {
                Text("CLAUDE").font(AppTheme.labelFont(size: 7)).foregroundColor(theme.onSurfaceVariant)
                    .frame(width: 50, alignment: .leading)
                ForEach(UsageMode.allCases, id: \.self) { mode in
                    Button {
                        settings.claudeMode = mode
                    } label: {
                        Text(mode == .subscription ? "SUB" : "API")
                            .font(AppTheme.headlineFont(size: 8))
                            .tracking(1)
                            .foregroundColor(settings.claudeMode == mode ? theme.surface : theme.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(settings.claudeMode == mode ? theme.primary : theme.surfaceContainerLowest)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Text("CODEX").font(AppTheme.labelFont(size: 7)).foregroundColor(theme.onSurfaceVariant)
                    .frame(width: 50, alignment: .leading)
                ForEach(UsageMode.allCases, id: \.self) { mode in
                    Button {
                        settings.codexMode = mode
                    } label: {
                        Text(mode == .subscription ? "SUB" : "API")
                            .font(AppTheme.headlineFont(size: 8))
                            .tracking(1)
                            .foregroundColor(settings.codexMode == mode ? theme.surface : theme.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(settings.codexMode == mode ? theme.primary : theme.surfaceContainerLowest)
                    }
                    .buttonStyle(.plain)
                }
            }

            sectionHeader("OPENCLAW CONNECTION")

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HOST").font(AppTheme.labelFont(size: 7)).foregroundColor(theme.onSurfaceVariant)
                    TextField(SettingsService.defaultOpenClawHost, text: $settings.openClawHost)
                        .textFieldStyle(.plain)
                        .font(AppTheme.monoFont(size: 10))
                        .foregroundColor(theme.onSurface)
                        .padding(6)
                        .background(theme.surfaceContainerLowest)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("PORT").font(AppTheme.labelFont(size: 7)).foregroundColor(theme.onSurfaceVariant)
                    TextField("\(SettingsService.defaultOpenClawPort)", value: $settings.openClawPort, format: .number)
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
                    SecureField("empty = no auth", text: $settings.openClawToken)
                        .textFieldStyle(.plain)
                        .font(AppTheme.monoFont(size: 10))
                        .foregroundColor(theme.onSurface)
                        .padding(6)
                        .background(theme.surfaceContainerLowest)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("AGENT ID").font(AppTheme.labelFont(size: 7)).foregroundColor(theme.onSurfaceVariant)
                    TextField(SettingsService.defaultOpenClawAgent, text: $settings.openClawAgent)
                        .textFieldStyle(.plain)
                        .font(AppTheme.monoFont(size: 10))
                        .foregroundColor(theme.onSurface)
                        .padding(6)
                        .background(theme.surfaceContainerLowest)
                        .frame(width: 80)
                }
            }

            Button {
                let h = settings.openClawHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? SettingsService.defaultOpenClawHost
                    : settings.openClawHost.trimmingCharacters(in: .whitespacesAndNewlines)
                let p = settings.openClawPort
                let t = settings.openClawToken.trimmingCharacters(in: .whitespacesAndNewlines)
                let agentText = settings.openClawAgent.trimmingCharacters(in: .whitespacesAndNewlines)
                let a = agentText.isEmpty ? SettingsService.defaultOpenClawAgent : agentText
                settings.openClawHost = h
                settings.openClawToken = t
                settings.openClawAgent = a
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
        .padding(16 * scale)
        .frame(width: 320 * scale)
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
