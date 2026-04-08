import SwiftUI
import AppKit

@Observable
@MainActor
class DisplayManager {
    var isExternalScreenConnected: Bool = false
    var isFullscreen: Bool = false
    var targetScreen: NSScreen?

    private var observer: NSObjectProtocol?

    // Detected content size — adapts to screen
    var contentSize: CGSize = CGSize(width: 800, height: 480)

    // Threshold: screens ≤ this width (logical points) trigger fullscreen
    nonisolated static let fullscreenMaxWidth: CGFloat = 1024

    // Aspect ratio for windowed mode (5:3 matches 800:480)
    nonisolated static let aspectRatio: CGFloat = 5.0 / 3.0

    // Window fills this fraction of screen in windowed mode
    nonisolated static let windowFillFraction: CGFloat = 0.8

    // Keep backward compatibility for tests
    nonisolated static let targetWidth: CGFloat = 800
    nonisolated static let targetHeight: CGFloat = 480
    nonisolated static func matchesTargetResolution(width: CGFloat, height: CGFloat) -> Bool {
        // Legacy: treat as fullscreen candidate if ≤1024
        width <= fullscreenMaxWidth + fullscreenMaxWidth * 0.10
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
        // Prefer external screen (non-built-in)
        let externalScreen = NSScreen.screens.first { screen in
            let name = screen.localizedName
            return !name.contains("Built-in") && !name.contains("内建")
        }

        if let external = externalScreen {
            targetScreen = external
            isExternalScreenConnected = true
            let width = external.frame.width  // logical points

            if width <= Self.fullscreenMaxWidth {
                // Small external display → fullscreen
                isFullscreen = true
                contentSize = CGSize(width: external.frame.width, height: external.frame.height)
                moveWindowToTarget()
            } else {
                // Large external display → windowed, sized to 80% with 5:3 ratio
                isFullscreen = false
                let windowWidth = external.visibleFrame.width * Self.windowFillFraction
                let windowHeight = windowWidth / Self.aspectRatio
                contentSize = CGSize(width: windowWidth, height: windowHeight)
                restoreWindow(on: external)
            }
        } else {
            // No external screen — use main screen in windowed mode
            targetScreen = nil
            isExternalScreenConnected = false
            isFullscreen = false

            if let main = NSScreen.main {
                let windowWidth = min(main.visibleFrame.width * Self.windowFillFraction, 1600)
                let windowHeight = windowWidth / Self.aspectRatio
                contentSize = CGSize(width: windowWidth, height: windowHeight)
            }
            restoreWindowDefault()
        }
    }

    func moveWindowToTarget() {
        guard let targetScreen else { return }
        guard let window = NSApplication.shared.windows.first else { return }

        NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]
        window.styleMask = [.borderless]
        window.setFrame(targetScreen.frame, display: true)
        window.level = .normal
    }

    private func restoreWindow(on screen: NSScreen) {
        guard let window = NSApplication.shared.windows.first else { return }
        NSApp.presentationOptions = []
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]

        // Center window on the target screen
        let x = screen.visibleFrame.origin.x + (screen.visibleFrame.width - contentSize.width) / 2
        let y = screen.visibleFrame.origin.y + (screen.visibleFrame.height - contentSize.height) / 2
        window.setFrame(CGRect(x: x, y: y, width: contentSize.width, height: contentSize.height), display: true)
    }

    func restoreWindow() {
        restoreWindowDefault()
    }

    private func restoreWindowDefault() {
        guard let window = NSApplication.shared.windows.first else { return }
        NSApp.presentationOptions = []
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setFrame(CGRect(x: 100, y: 100, width: contentSize.width, height: contentSize.height), display: true)
    }
}
