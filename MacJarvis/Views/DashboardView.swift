import SwiftUI

struct DashboardView: View {
    @Environment(\.theme) var theme
    @Environment(DisplayManager.self) private var displayManager
    @Environment(SettingsService.self) private var settings
    @State private var showSettings = false
    @State private var activeTab: ActiveTab = .openclaw

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let scale = max(size.width / 800.0, 0.5)
            let sideColumnWidth = size.width * 0.22

            ZStack {
                VStack(spacing: 0) {
                    HeaderView(showSettings: $showSettings)

                    HStack(spacing: 8 * scale) {
                        if activeTab == .openclaw {
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

                            TerminalLogView()
                                .fadeInUp(delay: 0.3)
                        } else {
                            EmbeddedTerminalView(tab: activeTab, isActive: true)
                                .id(activeTab)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .fadeInUp(delay: 0.1)
                        }
                    }
                    .padding(8 * scale)

                    BottomNavBar(activeTab: $activeTab)
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
            activateTerminalIfNeeded(activeTab)
        }
        .onChange(of: activeTab) { _, newTab in
            activateTerminalIfNeeded(newTab)
        }
    }

    /// Track which terminal tabs have been activated (lazy loading)
    @State private var activatedTabs: Set<ActiveTab> = []

    private func activateTerminalIfNeeded(_ tab: ActiveTab) {
        if tab.isTerminalTab {
            activatedTabs.insert(tab)
        }
    }
}
