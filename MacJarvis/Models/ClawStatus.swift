import Foundation

enum ClawStatus: Equatable {
    case running
    case stopped
    case error
    case unknown

    var label: String {
        switch self {
        case .running: "ONLINE"
        case .stopped: "OFFLINE"
        case .error: "ERROR"
        case .unknown: "UNKNOWN"
        }
    }

    var isConnected: Bool {
        self == .running
    }
}
