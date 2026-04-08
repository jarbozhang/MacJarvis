import SwiftUI

@main
struct MacJarvisApp: App {
    @State private var displayManager = DisplayManager()
    @State private var tokenService = TokenService()
    @State private var settingsService = SettingsService()
    @State private var openClawService = OpenClawService()
    @State private var voiceService = VoiceService()
    @State private var systemMonitor = SystemMonitorService()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(displayManager)
                .environment(tokenService)
                .environment(settingsService)
                .environment(openClawService)
                .environment(voiceService)
                .environment(systemMonitor)
                .environment(\.theme, settingsService.currentTheme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(settingsService.currentTheme.surface)
                .onDisappear {
                    voiceService.cleanup()
                }
                .onAppear {
                    let isUITest = ProcessInfo.processInfo.arguments.contains("--uitesting")
                    if isUITest {
                        tokenService.tools = [
                            ToolUsage(id: "codex", name: "Codex", totalTokens: 125000, sessionCount: 3),
                            ToolUsage(id: "claude", name: "Claude", totalTokens: 88000, sessionCount: 5),
                            ToolUsage(id: "gemini", name: "Gemini", sessionCount: 2),
                        ]
                        voiceService.isModelLoaded = true
                    } else {
                        displayManager.startMonitoring()
                        tokenService.startAutoRefresh(settings: settingsService)
                        voiceService.loadModel()
                        systemMonitor.startMonitoring()

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
}
