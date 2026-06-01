import Foundation

@Observable
@MainActor
final class LargeAgentStatusService {
    var snapshots: [LargeAgentSnapshot] = []
    var globalHealth: LargeAgentGlobalHealth = .checking
    var lastRefreshedAt: Date?
    var isUsingFixture = false

    private var refreshTimer: Timer?
    private var clock: () -> Date
    private var openClawService: OpenClawService?
    private var hermesService: HermesService?
    private var settingsService: SettingsService?

    init(clock: @escaping () -> Date = Date.init) {
        self.clock = clock
    }

    var installedAgents: [LargeAgentSnapshot] {
        snapshots.installedLargeAgents
    }

    func configureClock(_ clock: @escaping () -> Date) {
        self.clock = clock
    }

    func startMonitoring(
        openClawService: OpenClawService,
        hermesService: HermesService,
        settings: SettingsService,
        interval: TimeInterval = 15
    ) {
        guard !isUsingFixture else { return }
        self.openClawService = openClawService
        self.hermesService = hermesService
        self.settingsService = settings

        Task { await refresh() }

        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() async {
        guard let openClawService, let hermesService, let settingsService else { return }
        let now = clock()
        let openClaw = await openClawSnapshot(
            service: openClawService,
            settings: settingsService,
            now: now
        )
        let hermes = await hermesService.snapshot(now: now)
        publish([openClaw, hermes], now: now)
    }

    func publish(_ newSnapshots: [LargeAgentSnapshot], now: Date = Date()) {
        snapshots = newSnapshots.map { $0.evaluatingStaleness(now: now) }
        globalHealth = LargeAgentGlobalHealth.from(snapshots)
        lastRefreshedAt = now
    }

    func applyFixture(named name: String, now: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        isUsingFixture = true
        stopMonitoring()
        configureClock { now }
        publish(Self.fixtureSnapshots(named: name, now: now), now: now)
    }

    private func openClawSnapshot(
        service: OpenClawService,
        settings: SettingsService,
        now: Date
    ) async -> LargeAgentSnapshot {
        let installed = Self.isOpenClawInstalled(settings: settings)
        guard installed else {
            return LargeAgentSnapshot(kind: .openClaw, isInstalled: false, status: .unknown)
        }

        await service.refreshHealth()

        let tokenSummary = await Self.openClawTokenSummary(now: now)
        var status: LargeAgentRuntimeStatus
        var detail: String?

        switch service.status {
        case .running:
            status = service.isStreaming || service.hasActiveMirror ? .running : .idle
        case .stopped:
            status = .offline
            detail = "Health check unreachable"
        case .error:
            status = .error
            detail = "Health check failed"
        case .unknown:
            status = .unknown
        }

        let snapshot = LargeAgentSnapshot(
            kind: .openClaw,
            isInstalled: true,
            status: status,
            lastActivityAt: service.lastActivityAt,
            lastHeartbeatAt: service.lastHealthCheckedAt,
            detail: detail,
            tokenSummary: tokenSummary
        )
        return snapshot.evaluatingStaleness(now: now)
    }

    nonisolated static func openClawTokenSummary(now: Date) async -> AgentTokenSummary? {
        await Task.detached(priority: .utility) {
            guard let records = TokenService.fetchOpenClawGatewayUsage(), !records.isEmpty else {
                return nil
            }
            return AgentTokenSummary.from(records: records, now: now)
        }.value
    }

    static func isOpenClawInstalled(settings: SettingsService, fileManager: FileManager = .default) -> Bool {
        if UserDefaults.standard.object(forKey: "openClawHost") != nil ||
            UserDefaults.standard.object(forKey: "openClawPort") != nil ||
            UserDefaults.standard.object(forKey: "openClawAgent") != nil ||
            !settings.openClawToken.isEmpty {
            return true
        }

        if TokenService.findExecutable(named: "openclaw", candidates: [
            "/opt/homebrew/bin/openclaw",
            "/usr/local/bin/openclaw",
            NSHomeDirectory() + "/.local/bin/openclaw",
        ]) != nil {
            return true
        }

        return fileManager.fileExists(atPath: NSHomeDirectory() + "/.openclaw")
    }

    nonisolated static func fixtureSnapshots(named name: String, now: Date) -> [LargeAgentSnapshot] {
        let openClawUsage = AgentTokenSummary(
            inputTokens: 420_000,
            outputTokens: 280_000,
            totalTokens: 700_000,
            cost: 4.38,
            lastUpdated: now
        )
        let hermesUsage = AgentTokenSummary(
            inputTokens: 90_000,
            outputTokens: 48_000,
            totalTokens: 138_000,
            cost: 0.78,
            lastUpdated: now
        )

        switch name {
        case "no-large-agents":
            return [
                LargeAgentSnapshot(kind: .openClaw, isInstalled: false, status: .unknown),
                LargeAgentSnapshot(kind: .hermes, isInstalled: false, status: .unknown),
            ]
        case "stuck-openclaw":
            return [
                LargeAgentSnapshot(
                    kind: .openClaw,
                    isInstalled: true,
                    status: .running,
                    lastActivityAt: now.addingTimeInterval(-240),
                    lastHeartbeatAt: now.addingTimeInterval(-240),
                    detail: "No activity for 4m",
                    tokenSummary: openClawUsage
                ),
                LargeAgentSnapshot(kind: .hermes, isInstalled: false, status: .unknown),
            ]
        case "error-openclaw":
            return [
                LargeAgentSnapshot(
                    kind: .openClaw,
                    isInstalled: true,
                    status: .error,
                    lastActivityAt: now.addingTimeInterval(-45),
                    lastHeartbeatAt: now.addingTimeInterval(-30),
                    detail: "Health endpoint returned an error",
                    tokenSummary: openClawUsage
                ),
                LargeAgentSnapshot(kind: .hermes, isInstalled: false, status: .unknown),
            ]
        case "mixed-openclaw-hermes":
            return [
                LargeAgentSnapshot(
                    kind: .openClaw,
                    isInstalled: true,
                    status: .running,
                    lastActivityAt: now.addingTimeInterval(-8),
                    lastHeartbeatAt: now.addingTimeInterval(-3),
                    detail: "Streaming active session",
                    tokenSummary: openClawUsage
                ),
                LargeAgentSnapshot(
                    kind: .hermes,
                    isInstalled: true,
                    status: .idle,
                    lastActivityAt: now.addingTimeInterval(-180),
                    lastHeartbeatAt: now.addingTimeInterval(-12),
                    detail: "Healthy local provider",
                    tokenSummary: hermesUsage
                ),
            ]
        case "missing-small-token", "healthy-openclaw":
            fallthrough
        default:
            return [
                LargeAgentSnapshot(
                    kind: .openClaw,
                    isInstalled: true,
                    status: .idle,
                    lastActivityAt: now.addingTimeInterval(-90),
                    lastHeartbeatAt: now.addingTimeInterval(-5),
                    detail: "Healthy",
                    tokenSummary: openClawUsage
                ),
                LargeAgentSnapshot(kind: .hermes, isInstalled: false, status: .unknown),
            ]
        }
    }
}
