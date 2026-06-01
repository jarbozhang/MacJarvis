import SwiftUI

struct SystemDetailView: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale
    @Environment(SystemMonitorService.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * scale) {
            PageTitle(title: "LOCAL SYSTEM", subtitle: "CPU / MEMORY / DISK")

            HStack(spacing: 10 * scale) {
                SystemMetricPanel(
                    title: "CPU",
                    value: monitor.cpuUsage,
                    detail: "processor load",
                    color: loadColor(monitor.cpuUsage)
                )
                SystemMetricPanel(
                    title: "MEMORY",
                    value: monitor.memoryUsage,
                    detail: memoryDetail,
                    color: loadColor(monitor.memoryUsage)
                )
                SystemMetricPanel(
                    title: "DISK",
                    value: monitor.diskUsage,
                    detail: diskDetail,
                    color: loadColor(monitor.diskUsage)
                )
            }

            Text("LOCAL WARNINGS DO NOT OVERRIDE LARGE AGENT FAULTS")
                .font(AppTheme.monoFont(size: 9 * scale))
                .tracking(1 * scale)
                .foregroundColor(theme.onSurfaceVariant)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)
        }
        .padding(18 * scale)
        .accessibilityIdentifier("systemDetail")
    }

    private var memoryDetail: String {
        guard monitor.totalMemoryGB > 0 else { return "--" }
        return String(format: "%.1f / %.0f GB", monitor.usedMemoryGB, monitor.totalMemoryGB)
    }

    private var diskDetail: String {
        guard monitor.totalDiskGB > 0 else { return "--" }
        return String(format: "%.0f / %.0f GB", monitor.usedDiskGB, monitor.totalDiskGB)
    }

    private func loadColor(_ value: Double) -> Color {
        if value >= 90 { return theme.error }
        if value >= 75 { return Color(hex: 0xFFB020) }
        return theme.primary
    }
}

struct SystemMetricPanel: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale

    let title: String
    let value: Double
    let detail: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            Text(title)
                .font(AppTheme.labelFont(size: 11 * scale))
                .tracking(2 * scale)
                .foregroundColor(theme.onSurfaceVariant)

            Text(String(format: "%.0f%%", value))
                .font(AppTheme.headlineFont(size: 38 * scale))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            PixelProgressBar(value: min(max(value / 100, 0), 1), color: color, segments: 18)

            Text(detail)
                .font(AppTheme.bodyFont(size: 10 * scale))
                .foregroundColor(theme.onSurfaceVariant)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14 * scale)
        .background(theme.surfaceContainer.opacity(0.58))
        .overlay(alignment: .top) {
            Rectangle().fill(color.opacity(0.45)).frame(height: 2 * scale)
        }
    }
}
