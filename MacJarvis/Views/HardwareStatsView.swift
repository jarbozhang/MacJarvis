import SwiftUI

struct HardwareStatsView: View {
    @Environment(\.theme) var theme
    @Environment(\.scaleFactor) var scale
    @Environment(SystemMonitorService.self) private var monitor

    var body: some View {
        HStack(spacing: AppTheme.cardSpacing * scale) {
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text("CPU Load")
                    .font(AppTheme.headlineFont(size: 7 * scale))
                    .textCase(.uppercase)
                    .foregroundColor(theme.onSurfaceVariant)
                Text(String(format: "%.1f%%", monitor.cpuUsage))
                    .font(AppTheme.headlineFont(size: 12 * scale))
                    .foregroundColor(theme.onSurface)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8 * scale)
            .background(theme.surfaceContainer.opacity(0.6))
            .overlay(alignment: .top) {
                Rectangle().fill(theme.primary.opacity(0.4)).frame(height: 1)
            }

            VStack(alignment: .leading, spacing: 4 * scale) {
                Text("Mem")
                    .font(AppTheme.headlineFont(size: 7 * scale))
                    .textCase(.uppercase)
                    .foregroundColor(theme.onSurfaceVariant)
                Text(String(format: "%.1f%%", monitor.memoryUsage))
                    .font(AppTheme.headlineFont(size: 12 * scale))
                    .foregroundColor(theme.onSurface)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8 * scale)
            .background(theme.surfaceContainer.opacity(0.6))
            .overlay(alignment: .top) {
                Rectangle().fill(theme.secondary.opacity(0.4)).frame(height: 1)
            }
        }
    }
}
