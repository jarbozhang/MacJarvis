import SwiftUI

struct SettingsView: View {
    @Environment(SettingsService.self) private var settings
    @Environment(OpenClawService.self) private var clawService
    @Binding var isPresented: Bool

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("SETTINGS")
                    .font(CyberTheme.headlineFont(size: 12))
                    .tracking(3)
                    .foregroundColor(CyberTheme.primary)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(CyberTheme.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }

            sectionHeader("OPENCLAW CONNECTION")

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HOST").font(CyberTheme.labelFont(size: 7)).foregroundColor(CyberTheme.onSurfaceVariant)
                    TextField("127.0.0.1", text: $settings.openClawHost)
                        .textFieldStyle(.plain)
                        .font(CyberTheme.monoFont(size: 10))
                        .foregroundColor(CyberTheme.onSurface)
                        .padding(6)
                        .background(CyberTheme.surfaceContainerLowest)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("PORT").font(CyberTheme.labelFont(size: 7)).foregroundColor(CyberTheme.onSurfaceVariant)
                    TextField("18789", value: $settings.openClawPort, format: .number)
                        .textFieldStyle(.plain)
                        .font(CyberTheme.monoFont(size: 10))
                        .foregroundColor(CyberTheme.onSurface)
                        .padding(6)
                        .background(CyberTheme.surfaceContainerLowest)
                        .frame(width: 80)
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOKEN").font(CyberTheme.labelFont(size: 7)).foregroundColor(CyberTheme.onSurfaceVariant)
                    SecureField("optional", text: $settings.openClawToken)
                        .textFieldStyle(.plain)
                        .font(CyberTheme.monoFont(size: 10))
                        .foregroundColor(CyberTheme.onSurface)
                        .padding(6)
                        .background(CyberTheme.surfaceContainerLowest)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("AGENT").font(CyberTheme.labelFont(size: 7)).foregroundColor(CyberTheme.onSurfaceVariant)
                    TextField("main", text: $settings.openClawAgent)
                        .textFieldStyle(.plain)
                        .font(CyberTheme.monoFont(size: 10))
                        .foregroundColor(CyberTheme.onSurface)
                        .padding(6)
                        .background(CyberTheme.surfaceContainerLowest)
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
                    .font(CyberTheme.headlineFont(size: 9))
                    .tracking(2)
                    .foregroundColor(CyberTheme.surface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(clawService.status == .running ? CyberTheme.primary.opacity(0.5) : CyberTheme.primary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

        }
        .padding(16)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .background(CyberTheme.surfaceContainer)
        .contentShape(Rectangle())
        .overlay(Rectangle().stroke(CyberTheme.outlineVariant.opacity(0.3), lineWidth: 1))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(CyberTheme.headlineFont(size: 8))
            .tracking(2)
            .foregroundColor(CyberTheme.onSurfaceVariant.opacity(0.6))
    }
}
