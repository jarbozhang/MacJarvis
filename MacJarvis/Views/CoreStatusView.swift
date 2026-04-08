import SwiftUI

struct CoreStatusView: View {
    @Environment(\.theme) var theme
    @Environment(\.scaleFactor) var scale
    @Environment(OpenClawService.self) private var clawService
    @Environment(SettingsService.self) private var settings
    @Environment(SystemMonitorService.self) private var monitor
    @State private var now = Date()
    @State private var isBlinking = false
    private let uptimeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let blinkTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    private var statusText: String {
        if clawService.status == .running && settings.needsTokenSetup {
            return "NO TOKEN SET"
        }
        return clawService.status == .running ? "OPENCLAW ACTIVE" : "OPENCLAW \(clawService.status.label)"
    }

    private var uptimeText: String {
        guard let connectedAt = clawService.connectedAt else { return "---:--:--:--" }
        let interval = now.timeIntervalSince(connectedAt)
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%03d:%02d:%02d:%02d", days, hours, minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 8 * scale) {
            Spacer()

            LobsterShape(isBlinking: isBlinking)
                .frame(width: 64 * scale, height: 64 * scale)
                .neonGlow(color: theme.primary)
                .opacity(clawService.status == .running && !settings.needsTokenSetup ? 1 : 0.4)
                .floating(amplitude: 4, duration: 1.5)
            .onReceive(blinkTimer) { _ in
                guard clawService.status == .running else { return }
                isBlinking = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isBlinking = false
                }
            }

            Text(statusText)
                .font(AppTheme.headlineFont(size: 10 * scale))
                .tracking(1 * scale)
                .foregroundColor(clawService.status == .running && settings.needsTokenSetup ? theme.error : theme.primary)

            Text(uptimeText)
                .font(AppTheme.monoFont(size: 8 * scale))
                .tracking(2 * scale)
                .foregroundColor(theme.onSurfaceVariant.opacity(0.7))
                .onReceive(uptimeTimer) { now = $0 }

            Spacer()

            VStack(spacing: 4 * scale) {
                HStack {
                    Text("Disk")
                        .font(AppTheme.headlineFont(size: 7 * scale))
                        .textCase(.uppercase)
                        .foregroundColor(theme.tertiary)
                    Spacer()
                    Text(String(format: "%.0f/%.0fG", monitor.usedDiskGB, monitor.totalDiskGB))
                        .font(AppTheme.headlineFont(size: 7 * scale))
                        .foregroundColor(theme.tertiary)
                }
                PixelProgressBar(value: monitor.diskUsage / 100.0, color: theme.tertiary)
                    .frame(height: 4 * scale)
            }
            .padding(.horizontal, 8 * scale)
            .padding(.bottom, 8 * scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surfaceContainerHigh.opacity(0.5))
        .overlay(Rectangle().stroke(theme.outlineVariant.opacity(0.3), lineWidth: 1))
        .overlay(alignment: .topLeading) { cornerDot }
        .overlay(alignment: .topTrailing) { cornerDot }
        .overlay(alignment: .bottomLeading) { cornerDot }
        .overlay(alignment: .bottomTrailing) { cornerDot }
        .overlay(alignment: .topLeading) {
            Text("Core Status")
                .font(AppTheme.headlineFont(size: 7 * scale))
                .tracking(3 * scale)
                .textCase(.uppercase)
                .foregroundColor(theme.onSurfaceVariant.opacity(0.6))
                .padding(.top, 8 * scale)
                .padding(.leading, 12 * scale)
        }
    }

    private var cornerDot: some View {
        Rectangle().fill(theme.primary).frame(width: 4 * scale, height: 4 * scale)
    }
}
