import SwiftUI

struct DashboardView: View {
    @Environment(\.theme) var theme
    @Environment(DisplayManager.self) private var displayManager
    @Environment(SettingsService.self) private var settings
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let scale = max(size.width / 800.0, 0.5)
            let sideColumnWidth = size.width * 0.22

            ZStack {
                VStack(spacing: 0) {
                    HeaderView(showSettings: $showSettings)

                    HStack(spacing: 8 * scale) {
                        // Left column
                        VStack(spacing: 8 * scale) {
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
                    .padding(8 * scale)

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
            .environment(\.scaleFactor, scale)
        }
        .clipped()
        .onAppear {
            if settings.needsTokenSetup {
                showSettings = true
            }
        }
    }
}
