import SwiftUI

struct DashboardView: View {
    @Environment(\.theme) var theme
    @Environment(DisplayManager.self) private var displayManager
    @Environment(SettingsService.self) private var settings
    @Environment(TokenService.self) private var tokenService
    @Environment(LargeAgentStatusService.self) private var largeAgentStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSettings = false
    @State private var activePage: DashboardPage = .status
    @State private var lastPageChange = Date()
    @State private var lastFaultClearedAt: Date?
    @State private var wasFaulting = false

    private let rotationTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let scale = max(size.width / 800.0, 0.5)

            ZStack {
                VStack(spacing: 0) {
                    HeaderView(showSettings: $showSettings)

                    pageView(width: size.width)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background { StarfieldBackground() }
                .pixelGrid()
                .modifier(ConditionalCRT(enabled: !reduceMotion))

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
            activePage = Self.launchPage() ?? (largeAgentStatus.globalHealth.interruptsRotation ? .fault : .status)
            lastPageChange = Date()
        }
        .onReceive(rotationTimer) { now in
            rotateIfNeeded(now: now)
        }
        .onChange(of: largeAgentStatus.globalHealth) { _, newHealth in
            if newHealth.interruptsRotation {
                wasFaulting = true
                activePage = .fault
                lastPageChange = Date()
                return
            }

            if wasFaulting {
                wasFaulting = false
                lastFaultClearedAt = Date()
                activePage = .status
                lastPageChange = Date()
            }
        }
    }

    @ViewBuilder
    private func pageView(width: CGFloat) -> some View {
        let currentPage = DashboardRotation.effectivePage(
            current: activePage,
            health: largeAgentStatus.globalHealth
        )

        switch currentPage {
        case .status:
            AgentStatusWallView(now: Date(), viewportWidth: width)
                .fadeInUp(delay: 0)
        case .consumption:
            ConsumptionDetailView()
                .fadeInUp(delay: 0)
        case .system:
            SystemDetailView()
                .fadeInUp(delay: 0)
        case .fault:
            AgentFaultInterruptView(now: Date())
                .fadeInUp(delay: 0)
        }
    }

    private func rotateIfNeeded(now: Date) {
        guard !isUITesting else { return }
        let health = largeAgentStatus.globalHealth
        let elapsed = now.timeIntervalSince(lastPageChange)
        let recoveryElapsed = lastFaultClearedAt.map { now.timeIntervalSince($0) }
        let next = DashboardRotation.nextPage(
            current: activePage,
            elapsed: elapsed,
            health: health,
            hasConsumptionData: hasConsumptionData,
            settingsPresented: showSettings,
            recoveryElapsed: recoveryElapsed
        )

        guard next != activePage else { return }
        activePage = next
        lastPageChange = now
        if recoveryElapsed != nil, next != .status {
            lastFaultClearedAt = nil
        }
    }

    private var hasConsumptionData: Bool {
        if largeAgentStatus.installedAgents.contains(where: { $0.tokenSummary?.hasData == true }) {
            return true
        }
        return tokenService.tools.contains(where: \.hasConsumptionData)
    }

    private static func launchPage() -> DashboardPage? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--page"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return DashboardPage(rawValue: arguments[index + 1])
    }
}

private struct ConditionalCRT: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.crtEffect()
        } else {
            content
        }
    }
}
