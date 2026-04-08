import SwiftUI

struct DashboardView: View {
    @Environment(\.theme) var theme
    @Environment(DisplayManager.self) private var displayManager
    @Environment(SettingsService.self) private var settings
    @State private var showSettings = false

    var body: some View {
        let size = displayManager.contentSize
        let sideColumnWidth = size.width * 0.22 // ~175 at 800, ~282 at 1280

        ZStack {
            VStack(spacing: 0) {
                HeaderView(showSettings: $showSettings)

                HStack(spacing: 8) {
                    // Left column
                    VStack(spacing: 8) {
                        CoreStatusView()
                        HardwareStatsView()
                    }
                    .frame(width: sideColumnWidth)
                    .fadeInUp(delay: 0)

                    // Middle column
                    TokenColumnView()
                        .frame(width: sideColumnWidth)
                        .fadeInUp(delay: 0.15)

                    // Right column (fills remaining)
                    TerminalLogView()
                        .fadeInUp(delay: 0.3)
                }
                .padding(8)

                BottomNavBar()
            }
            .background { StarfieldBackground() }
            .pixelGrid()
            .crtEffect()

            // Settings overlay
            if showSettings {
                Button {
                    showSettings = false
                } label: {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                }
                .buttonStyle(.plain)

                SettingsView(isPresented: $showSettings)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .onAppear {
            // Auto-open settings if token not configured
            if settings.needsTokenSetup {
                showSettings = true
            }
        }
    }
}
