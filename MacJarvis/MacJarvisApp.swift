import SwiftUI

@main
struct MacJarvisApp: App {
    @State private var displayManager = DisplayManager()
    @State private var tokenService = TokenService()
    @State private var settingsService = SettingsService()
    @State private var openClawService = OpenClawService()
    @State private var hermesService = HermesService()
    @State private var largeAgentStatusService = LargeAgentStatusService()
    @State private var voiceService = VoiceService()
    @State private var systemMonitor = SystemMonitorService()
    @State private var terminalSessionService = TerminalSessionService()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(displayManager)
                .environment(tokenService)
                .environment(settingsService)
                .environment(openClawService)
                .environment(hermesService)
                .environment(largeAgentStatusService)
                .environment(voiceService)
                .environment(systemMonitor)
                .environment(terminalSessionService)
                .environment(\.theme, settingsService.currentTheme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(settingsService.currentTheme.surface)
                .onDisappear {
                    voiceService.cleanup()
                    terminalSessionService.stopAll()
                }
                .onAppear {
                    let arguments = ProcessInfo.processInfo.arguments
                    let isUITest = arguments.contains("--uitesting")
                    if isUITest || Self.explicitFixtureName(from: arguments) != nil {
                        applyUITestFixture(named: Self.fixtureName(from: arguments))
                        voiceService.isModelLoaded = true
                    } else {
                        displayManager.startMonitoring()
                        tokenService.startAutoRefresh(settings: settingsService)
                        systemMonitor.startMonitoring()
                        largeAgentStatusService.startMonitoring(
                            openClawService: openClawService,
                            hermesService: hermesService,
                            settings: settingsService
                        )

                        // Auto-connect to OpenClaw using saved settings
                        Task {
                            await openClawService.connect(
                                host: settingsService.openClawHost,
                                port: settingsService.openClawPort,
                                token: settingsService.openClawToken,
                                agent: settingsService.openClawAgent
                            )
                        }
                    }
                }
        }
        .defaultSize(width: displayManager.contentSize.width, height: displayManager.contentSize.height)
    }

    private func applyUITestFixture(named fixtureName: String) {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        largeAgentStatusService.applyFixture(named: fixtureName, now: now)

        if fixtureName == "missing-small-token" {
            tokenService.tools = [
                ToolUsage(id: "codex", name: "Codex"),
                ToolUsage(id: "claude", name: "Claude"),
                ToolUsage(id: "gemini", name: "Gemini"),
            ]
        } else {
            tokenService.tools = [
                ToolUsage(id: "codex", name: "Codex", totalTokens: 125_000, cost: 0.78, sessionCount: 3, lastUpdated: now, isAPIMode: true),
                ToolUsage(id: "claude", name: "Claude", totalTokens: 88_000, cost: 1.42, sessionCount: 5, lastUpdated: now, isAPIMode: true),
                ToolUsage(id: "gemini", name: "Gemini", totalTokens: 32_000, sessionCount: 2, lastUpdated: now),
            ]
        }

        systemMonitor.cpuUsage = 21
        systemMonitor.memoryUsage = 46
        systemMonitor.diskUsage = 58
        systemMonitor.totalMemoryGB = 16
        systemMonitor.usedMemoryGB = 7.4
        systemMonitor.totalDiskGB = 512
        systemMonitor.usedDiskGB = 298
    }

    private static func fixtureName(from arguments: [String]) -> String {
        explicitFixtureName(from: arguments) ?? "healthy-openclaw"
    }

    private static func explicitFixtureName(from arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: "--fixture"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}
