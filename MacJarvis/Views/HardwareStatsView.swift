import SwiftUI

struct HardwareStatsView: View {
    @Environment(SystemMonitorService.self) private var monitor

    var body: some View {
        HStack(spacing: CyberTheme.cardSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CPU Load")
                    .font(CyberTheme.headlineFont(size: 7))
                    .textCase(.uppercase)
                    .foregroundColor(CyberTheme.onSurfaceVariant)
                Text(String(format: "%.1f%%", monitor.cpuUsage))
                    .font(CyberTheme.headlineFont(size: 12))
                    .foregroundColor(CyberTheme.onSurface)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(CyberTheme.surfaceContainer)
            .overlay(alignment: .top) {
                Rectangle().fill(CyberTheme.primary.opacity(0.4)).frame(height: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Mem")
                    .font(CyberTheme.headlineFont(size: 7))
                    .textCase(.uppercase)
                    .foregroundColor(CyberTheme.onSurfaceVariant)
                Text(String(format: "%.1f%%", monitor.memoryUsage))
                    .font(CyberTheme.headlineFont(size: 12))
                    .foregroundColor(CyberTheme.onSurface)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(CyberTheme.surfaceContainer)
            .overlay(alignment: .top) {
                Rectangle().fill(CyberTheme.secondary.opacity(0.4)).frame(height: 1)
            }
        }
    }
}
