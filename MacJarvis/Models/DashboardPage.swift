import Foundation

enum DashboardPage: String, Equatable {
    case status
    case consumption
    case system
    case fault
}

struct DashboardRotation {
    static let statusDwell: TimeInterval = 45
    static let detailDwell: TimeInterval = 12
    static let recoveryStatusDwell: TimeInterval = 30

    static func effectivePage(
        current: DashboardPage,
        health: LargeAgentGlobalHealth
    ) -> DashboardPage {
        health.interruptsRotation ? .fault : current
    }

    static func nextPage(
        current: DashboardPage,
        elapsed: TimeInterval,
        health: LargeAgentGlobalHealth,
        hasConsumptionData: Bool,
        settingsPresented: Bool,
        recoveryElapsed: TimeInterval?
    ) -> DashboardPage {
        guard !settingsPresented else { return current }
        guard !health.interruptsRotation else { return .fault }

        if current == .fault {
            return .status
        }

        if let recoveryElapsed, recoveryElapsed < recoveryStatusDwell {
            return .status
        }

        switch current {
        case .status:
            guard elapsed >= statusDwell else { return .status }
            return hasConsumptionData ? .consumption : .system
        case .consumption:
            guard elapsed >= detailDwell else { return .consumption }
            return .system
        case .system:
            guard elapsed >= detailDwell else { return .system }
            return .status
        case .fault:
            return .status
        }
    }
}
