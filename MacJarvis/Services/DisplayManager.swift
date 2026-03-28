import SwiftUI
import AppKit

@Observable
@MainActor
class DisplayManager {
    var isExternalScreenConnected: Bool = false
    var targetScreen: NSScreen?

    private var observer: NSObjectProtocol?

    // Detected content size for the matched screen
    var contentSize: CGSize = CGSize(width: 800, height: 480)

    // Supported target resolutions
    nonisolated static let supportedResolutions: [(width: CGFloat, height: CGFloat)] = [
        (800, 480),
        (1280, 720)
    ]
    nonisolated static let tolerance: CGFloat = 0.10

    nonisolated static func matchedResolution(width: CGFloat, height: CGFloat) -> (width: CGFloat, height: CGFloat)? {
        for res in supportedResolutions {
            let wMin = res.width * (1 - tolerance)
            let wMax = res.width * (1 + tolerance)
            let hMin = res.height * (1 - tolerance)
            let hMax = res.height * (1 + tolerance)
            if width >= wMin && width <= wMax && height >= hMin && height <= hMax {
                return res
            }
        }
        return nil
    }

    // Keep backward compatibility for tests
    nonisolated static let targetWidth: CGFloat = 800
    nonisolated static let targetHeight: CGFloat = 480
    nonisolated static func matchesTargetResolution(width: CGFloat, height: CGFloat) -> Bool {
        matchedResolution(width: width, height: height) != nil
    }

    func startMonitoring() {
        checkScreens()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkScreens()
            }
        }
    }

    func stopMonitoring() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    private func checkScreens() {
        for screen in NSScreen.screens {
            guard let deviceSize = screen.deviceDescription[.size] as? NSSize else { continue }
            let pixelWidth = deviceSize.width * screen.backingScaleFactor
            let pixelHeight = deviceSize.height * screen.backingScaleFactor

            if let res = Self.matchedResolution(width: pixelWidth, height: pixelHeight)
                ?? Self.matchedResolution(width: deviceSize.width, height: deviceSize.height) {
                targetScreen = screen
                contentSize = CGSize(width: res.width, height: res.height)
                isExternalScreenConnected = true
                moveWindowToTarget()
                return
            }
        }
        targetScreen = nil
        isExternalScreenConnected = false
    }

    func moveWindowToTarget() {
        guard let targetScreen else { return }
        guard let window = NSApplication.shared.windows.first else { return }

        // Hide menu bar and dock on the target screen
        NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]

        window.styleMask = [.borderless]
        // Use the full screen frame (not visibleFrame which excludes dock/menubar)
        window.setFrame(targetScreen.frame, display: true)
        window.level = .normal
    }

    func restoreWindow() {
        guard let window = NSApplication.shared.windows.first else { return }
        NSApp.presentationOptions = []
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setFrame(CGRect(x: 100, y: 100, width: contentSize.width, height: contentSize.height), display: true)
    }
}
