import SwiftUI

struct CompactSystemStrip: View {
    @Environment(\.theme) private var theme
    @Environment(\.scaleFactor) private var scale
    @Environment(SystemMonitorService.self) private var monitor

    var showDisk = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            StripHeader(title: "LOCAL LOAD", color: theme.primary)

            HStack(spacing: 8 * scale) {
                ReadoutCell(
                    title: "CPU",
                    value: String(format: "%.0f%%", monitor.cpuUsage),
                    detail: loadDetail(for: monitor.cpuUsage),
                    color: loadColor(monitor.cpuUsage)
                )
                ReadoutCell(
                    title: "MEM",
                    value: String(format: "%.0f%%", monitor.memoryUsage),
                    detail: memoryDetail,
                    color: loadColor(monitor.memoryUsage)
                )
                if showDisk {
                    ReadoutCell(
                        title: "DISK",
                        value: String(format: "%.0f%%", monitor.diskUsage),
                        detail: diskDetail,
                        color: loadColor(monitor.diskUsage)
                    )
                }
            }
        }
        .padding(10 * scale)
        .background(theme.surfaceContainerLow.opacity(0.76))
        .overlay(alignment: .top) {
            Rectangle().fill(theme.primary.opacity(0.35)).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Local load. CPU \(Int(monitor.cpuUsage)) percent. Memory \(Int(monitor.memoryUsage)) percent.")
        .accessibilityIdentifier("compactSystem")
    }

    private var memoryDetail: String {
        guard monitor.totalMemoryGB > 0 else { return "--" }
        return String(format: "%.1f/%.0fGB", monitor.usedMemoryGB, monitor.totalMemoryGB)
    }

    private var diskDetail: String {
        guard monitor.totalDiskGB > 0 else { return "--" }
        return String(format: "%.0f/%.0fGB", monitor.usedDiskGB, monitor.totalDiskGB)
    }

    private func loadDetail(for value: Double) -> String {
        value >= 85 ? "HIGH" : "NORMAL"
    }

    private func loadColor(_ value: Double) -> Color {
        if value >= 90 { return theme.error }
        if value >= 75 { return Color(hex: 0xFFB020) }
        return theme.primary
    }
}
