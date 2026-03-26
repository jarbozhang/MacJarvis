import SwiftUI

struct DashboardView: View {
    @Environment(\.theme) var theme
    @State private var showSettings = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderView(showSettings: $showSettings)

                HStack(spacing: 8) {
                    // Left column (3/12)
                    VStack(spacing: 8) {
                        CoreStatusView()
                        HardwareStatsView()
                    }
                    .frame(width: 175)

                    // Middle column (3/12)
                    TokenColumnView()
                        .frame(width: 175)

                    // Right column (6/12)
                    TerminalLogView()
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
        .frame(width: 800, height: 480)
        .clipped()
    }
}
