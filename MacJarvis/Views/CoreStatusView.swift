import SwiftUI

struct CoreStatusView: View {
    @Environment(OpenClawService.self) private var clawService
    @Environment(SystemMonitorService.self) private var monitor
    @State private var now = Date()
    @State private var isBreathing = false
    @State private var isBlinking = false
    private let uptimeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let blinkTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    private var statusText: String {
        clawService.status == .running ? "OPENCLAW ACTIVE" : "OPENCLAW \(clawService.status.label)"
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
        VStack(spacing: 8) {
            Spacer()

            ZStack {
                Circle()
                    .fill(CyberTheme.primary.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .blur(radius: 16)
                    .opacity(clawService.status == .running ? 1 : 0.3)
                    .scaleEffect(isBreathing ? 1.4 : 0.8)

                LobsterShape(isBlinking: isBlinking)
                    .frame(width: 64, height: 64)
                    .neonGlow()
                    .opacity(clawService.status == .running ? 1 : 0.4)
                    .scaleEffect(isBreathing ? 1.12 : 0.95)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
            .onReceive(blinkTimer) { _ in
                guard clawService.status == .running else { return }
                isBlinking = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isBlinking = false
                }
            }

            Text(statusText)
                .font(CyberTheme.headlineFont(size: 10))
                .tracking(1)
                .foregroundColor(CyberTheme.primary)

            Text(uptimeText)
                .font(CyberTheme.monoFont(size: 8))
                .tracking(2)
                .foregroundColor(CyberTheme.onSurfaceVariant.opacity(0.7))
                .onReceive(uptimeTimer) { now = $0 }

            Spacer()

            VStack(spacing: 4) {
                HStack {
                    Text("Disk")
                        .font(CyberTheme.headlineFont(size: 7))
                        .textCase(.uppercase)
                        .foregroundColor(CyberTheme.tertiary)
                    Spacer()
                    Text(String(format: "%.0f/%.0fG", monitor.usedDiskGB, monitor.totalDiskGB))
                        .font(CyberTheme.headlineFont(size: 7))
                        .foregroundColor(CyberTheme.tertiary)
                }
                PixelProgressBar(value: monitor.diskUsage / 100.0, color: CyberTheme.tertiary)
                    .frame(height: 4)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CyberTheme.surfaceContainerHigh.opacity(0.5))
        .overlay(Rectangle().stroke(CyberTheme.outlineVariant.opacity(0.3), lineWidth: 1))
        .overlay(alignment: .topLeading) { cornerDot }
        .overlay(alignment: .topTrailing) { cornerDot }
        .overlay(alignment: .bottomLeading) { cornerDot }
        .overlay(alignment: .bottomTrailing) { cornerDot }
        .overlay(alignment: .topLeading) {
            Text("Core Status")
                .font(CyberTheme.headlineFont(size: 7))
                .tracking(3)
                .textCase(.uppercase)
                .foregroundColor(CyberTheme.onSurfaceVariant.opacity(0.6))
                .padding(.top, 8)
                .padding(.leading, 12)
        }
    }

    private var cornerDot: some View {
        Rectangle().fill(CyberTheme.primary).frame(width: 4, height: 4)
    }
}
