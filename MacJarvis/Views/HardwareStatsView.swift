import SwiftUI

struct HardwareStatsView: View {
    @Environment(\.theme) var theme
    @Environment(SystemMonitorService.self) private var monitor

    var body: some View {
        HStack(spacing: AppTheme.cardSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CPU Load")
                    .font(AppTheme.headlineFont(size: 7))
                    .textCase(.uppercase)
                    .foregroundColor(theme.onSurfaceVariant)
                Text(String(format: "%.1f%%", monitor.cpuUsage))
                    .font(AppTheme.headlineFont(size: 12))
                    .foregroundColor(theme.onSurface)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(theme.surfaceContainer)
            .overlay(alignment: .top) {
                Rectangle().fill(theme.primary.opacity(0.4)).frame(height: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Mem")
                    .font(AppTheme.headlineFont(size: 7))
                    .textCase(.uppercase)
                    .foregroundColor(theme.onSurfaceVariant)
                Text(String(format: "%.1f%%", monitor.memoryUsage))
                    .font(AppTheme.headlineFont(size: 12))
                    .foregroundColor(theme.onSurface)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(theme.surfaceContainer)
            .overlay(alignment: .top) {
                Rectangle().fill(theme.secondary.opacity(0.4)).frame(height: 1)
            }
        }
    }
}
