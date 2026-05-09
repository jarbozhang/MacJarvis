import SwiftUI
import AppKit

@Observable
@MainActor
class DisplayManager {
    var isExternalScreenConnected: Bool = false
    var isFullscreen: Bool = false
    var targetScreen: NSScreen?

    private var observer: NSObjectProtocol?
    private var windowObservers: [NSObjectProtocol] = []
    private var isSystemFullscreenActive = false

    // Detected content size — adapts to screen
    var contentSize: CGSize = CGSize(width: 800, height: 480)

    // Threshold: screens ≤ this width (logical points) use borderless immersive mode.
    nonisolated static let fullscreenMaxWidth: CGFloat = 1280

    // Preferred window width on larger displays
    nonisolated static let preferredWindowWidth: CGFloat = 1280

    // Aspect ratio for windowed mode (5:3 matches 800:480)
    nonisolated static let aspectRatio: CGFloat = 5.0 / 3.0

    // Maximum fraction of screen width used when 1280 does not fit
    nonisolated static let windowMaxFillFraction: CGFloat = 0.9

    // Keep backward compatibility for tests
    nonisolated static let targetWidth: CGFloat = 800
    nonisolated static let targetHeight: CGFloat = 480
    nonisolated static func matchesTargetResolution(width: CGFloat, height: CGFloat) -> Bool {
        shouldUseFullscreen(forWidth: width)
    }

    nonisolated static func shouldUseFullscreen(forWidth width: CGFloat) -> Bool {
        width <= fullscreenMaxWidth
    }

    func startMonitoring() {
        configureWindowMonitoring()
        checkScreens()
        scheduleStartupWindowCorrections()
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
        for windowObserver in windowObservers {
            NotificationCenter.default.removeObserver(windowObserver)
        }
        observer = nil
        windowObservers.removeAll()
    }

    private func configureWindowMonitoring() {
        guard windowObservers.isEmpty else { return }

        let center = NotificationCenter.default
        windowObservers.append(
            center.addObserver(
                forName: NSWindow.willEnterFullScreenNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isSystemFullscreenActive = true
                }
            }
        )

        windowObservers.append(
            center.addObserver(
                forName: NSWindow.didEnterFullScreenNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    self?.isSystemFullscreenActive = true
                    if let window = notification.object as? NSWindow {
                        self?.applyImmersiveChrome(to: window, useBorderlessWindow: false)
                    }
                }
            }
        )

        windowObservers.append(
            center.addObserver(
                forName: NSWindow.willExitFullScreenNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    if let window = notification.object as? NSWindow {
                        self?.applyWindowedChrome(to: window)
                    }
                }
            }
        )

        windowObservers.append(
            center.addObserver(
                forName: NSWindow.didExitFullScreenNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isSystemFullscreenActive = false
                    self?.checkScreens()
                }
            }
        )
    }

    private func scheduleStartupWindowCorrections() {
        for delayMs in [100, 400, 900, 1600] {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(delayMs))
                self.checkScreens(forceWindowedCorrection: true)
            }
        }
    }

    private func checkScreens(forceWindowedCorrection: Bool = false) {
        // Prefer external screen (non-built-in)
        let externalScreen = NSScreen.screens.first { screen in
            let name = screen.localizedName
            return !name.contains("Built-in") && !name.contains("内建")
        }

        if let external = externalScreen {
            targetScreen = external
            isExternalScreenConnected = true
            let width = external.frame.width  // logical points

            if Self.shouldUseFullscreen(forWidth: width) {
                if isSystemFullscreenActive || NSApplication.shared.windows.contains(where: { $0.styleMask.contains(.fullScreen) }) {
                    return
                }

                // Small external display → fullscreen
                isFullscreen = true
                contentSize = CGSize(width: external.frame.width, height: external.frame.height)
                moveWindowToTarget()
            } else {
                exitSystemFullscreenIfNeeded()

                // Large external display → windowed, held around 1280 with 5:3 ratio
                isFullscreen = false
                let windowWidth = Self.windowedWidth(for: external.visibleFrame)
                let windowHeight = windowWidth / Self.aspectRatio
                contentSize = CGSize(width: windowWidth, height: windowHeight)
                restoreWindow(on: external, force: forceWindowedCorrection)
            }
        } else {
            exitSystemFullscreenIfNeeded()

            // No external screen — use main screen in windowed mode
            targetScreen = nil
            isExternalScreenConnected = false
            isFullscreen = false

            if let main = NSScreen.main {
                let windowWidth = Self.windowedWidth(for: main.visibleFrame)
                let windowHeight = windowWidth / Self.aspectRatio
                contentSize = CGSize(width: windowWidth, height: windowHeight)
            }
            restoreWindowDefault(force: forceWindowedCorrection)
        }
    }

    private nonisolated static func windowedWidth(for visibleFrame: CGRect) -> CGFloat {
        min(preferredWindowWidth, visibleFrame.width * windowMaxFillFraction)
    }

    func moveWindowToTarget() {
        guard let targetScreen else { return }
        guard let window = NSApplication.shared.windows.first else { return }

        applyImmersiveChrome(to: window, useBorderlessWindow: true)
        window.setFrame(targetScreen.frame, display: true)
        window.level = .normal
    }

    private func restoreWindow(on screen: NSScreen, force: Bool = true) {
        guard let window = NSApplication.shared.windows.first else { return }
        if !force && window.frame.width <= Self.preferredWindowWidth + 24 {
            return
        }
        applyWindowedChrome(to: window)

        // Center window on the target screen
        let x = screen.visibleFrame.origin.x + (screen.visibleFrame.width - contentSize.width) / 2
        let y = screen.visibleFrame.origin.y + (screen.visibleFrame.height - contentSize.height) / 2
        window.setFrame(CGRect(x: x, y: y, width: contentSize.width, height: contentSize.height), display: true)
    }

    func restoreWindow() {
        restoreWindowDefault()
    }

    private func restoreWindowDefault(force: Bool = true) {
        guard let window = NSApplication.shared.windows.first else { return }
        if !force && window.frame.width <= Self.preferredWindowWidth + 24 {
            return
        }
        applyWindowedChrome(to: window)
        window.setFrame(CGRect(x: 100, y: 100, width: contentSize.width, height: contentSize.height), display: true)
    }

    private func exitSystemFullscreenIfNeeded() {
        guard let window = NSApplication.shared.windows.first else { return }
        if window.styleMask.contains(.fullScreen) {
            isSystemFullscreenActive = false
            window.toggleFullScreen(nil)
        }
    }

    private func applyImmersiveChrome(to window: NSWindow, useBorderlessWindow: Bool) {
        NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]
        if useBorderlessWindow {
            window.styleMask = [.borderless]
        } else {
            window.styleMask.insert(.fullSizeContentView)
        }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbar?.isVisible = false
    }

    private func applyWindowedChrome(to window: NSWindow) {
        NSApp.presentationOptions = []
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.toolbar?.isVisible = true
    }
}
