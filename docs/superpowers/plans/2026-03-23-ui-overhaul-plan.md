# MacJarvis UI Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the MacJarvis dashboard from a top-cards+chat layout to a 3-column terminal-style layout (Core Status | Token Cards | Terminal Log) with new cyberpunk theme, real hardware monitoring, and configurable token budgets.

**Architecture:** Delete all existing Views, rewrite from scratch. Modify theme system (CyberTheme/CRTEffect) for new color palette and Space Grotesk font. Add SystemMonitorService for CPU/Temp. Extend SettingsService with token budget config. Add `connectedAt` to OpenClawService. All views consume existing services via @Environment.

**Tech Stack:** SwiftUI (macOS 14+), @Observable macro, Mach APIs (CPU), IOKit/SMC (temperature), Space Grotesk font (OFL), UserDefaults

**Spec:** `docs/superpowers/specs/2026-03-23-ui-overhaul-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Rewrite | `MacJarvis/Theme/CyberTheme.swift` | New color palette, Space Grotesk font, 0-radius modifiers, pixel progress bar |
| Modify | `MacJarvis/Theme/CRTEffect.swift` | Keep scanlines, add pixel-grid background modifier |
| Create | `MacJarvis/Services/SystemMonitorService.swift` | CPU usage (Mach API) + CPU temperature (SMC/IOKit) |
| Modify | `MacJarvis/Services/SettingsService.swift` | Add codex/claude/gemini daily budget properties |
| Modify | `MacJarvis/Services/OpenClawService.swift` | Add `connectedAt: Date?` property |
| Delete | `MacJarvis/Views/DashboardView.swift` | Old layout |
| Delete | `MacJarvis/Views/TokenCardView.swift` | Old token card |
| Delete | `MacJarvis/Views/ClawStatusCardView.swift` | Old status card |
| Delete | `MacJarvis/Views/ClockCardView.swift` | Old clock card |
| Delete | `MacJarvis/Views/ChatView.swift` | Old chat view |
| Delete | `MacJarvis/Views/PTTButton.swift` | Old PTT button |
| Delete | `MacJarvis/Views/SettingsView.swift` | Old settings |
| Create | `MacJarvis/Views/LobsterShape.swift` | SVG-to-Path lobster icon |
| Create | `MacJarvis/Views/HeaderView.swift` | Top bar with title, clock, settings |
| Create | `MacJarvis/Views/CoreStatusView.swift` | Left column: lobster + OpenClaw status + signal bar |
| Create | `MacJarvis/Views/HardwareStatsView.swift` | Left column bottom: CPU + Temp |
| Create | `MacJarvis/Views/TokenCard.swift` | Single token card with pixel progress bar |
| Create | `MacJarvis/Views/TokenColumnView.swift` | Middle column: 3 TokenCards stacked |
| Create | `MacJarvis/Views/TerminalLogView.swift` | Right column: terminal log + NEW COMMAND button + PTT |
| Create | `MacJarvis/Views/BottomNavBar.swift` | Decorative bottom nav |
| Create | `MacJarvis/Views/DashboardView.swift` | New main layout container |
| Create | `MacJarvis/Views/SettingsView.swift` | Settings with OpenClaw + budget config |
| Modify | `MacJarvis/MacJarvisApp.swift` | Inject SystemMonitorService |
| Add | `MacJarvis/Resources/Fonts/SpaceGrotesk-*.ttf` | Font files (3 weights) |
| Modify | `MacJarvis/Info.plist` | Register new fonts, remove PressStart2P |
| Modify | `project.yml` | Ensure font resources included |

---

## Task 1: Download Space Grotesk Font Files

**Files:**
- Create: `MacJarvis/Resources/Fonts/SpaceGrotesk-Regular.ttf`
- Create: `MacJarvis/Resources/Fonts/SpaceGrotesk-Bold.ttf`
- Create: `MacJarvis/Resources/Fonts/SpaceGrotesk-Medium.ttf`
- Delete: `MacJarvis/Resources/Fonts/PressStart2P-Regular.ttf`
- Modify: `MacJarvis/Info.plist`

- [ ] **Step 1: Download Space Grotesk static font files from Google Fonts**

Use static font builds only (not variable font) to ensure PostScript name matches `SpaceGrotesk-Regular` / `SpaceGrotesk-Bold` / `SpaceGrotesk-Medium`.

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/MacJarvis
curl -L "https://fonts.google.com/download?family=Space+Grotesk" -o /tmp/SpaceGrotesk.zip
cd /tmp && unzip -o SpaceGrotesk.zip -d SpaceGrotesk
cp /tmp/SpaceGrotesk/static/SpaceGrotesk-Regular.ttf /Users/jiabozhang/Documents/Develop/vibecoding/MacJarvis/MacJarvis/Resources/Fonts/
cp /tmp/SpaceGrotesk/static/SpaceGrotesk-Medium.ttf /Users/jiabozhang/Documents/Develop/vibecoding/MacJarvis/MacJarvis/Resources/Fonts/
cp /tmp/SpaceGrotesk/static/SpaceGrotesk-Bold.ttf /Users/jiabozhang/Documents/Develop/vibecoding/MacJarvis/MacJarvis/Resources/Fonts/
```

If the Google Fonts download URL changes, search for "Space Grotesk" at https://github.com/google/fonts/tree/main/ofl/spacegrotesk/static and download the 3 static TTF files manually.

- [ ] **Step 2: Remove old pixel font**

```bash
rm MacJarvis/Resources/Fonts/PressStart2P-Regular.ttf
```

- [ ] **Step 3: Update Info.plist to register new fonts**

In `MacJarvis/Info.plist`, the `ATSApplicationFontsPath` is already set to `"Fonts"` which means macOS will auto-discover all .ttf files in that directory. No plist changes needed for font registration — just having the files in Resources/Fonts/ is sufficient.

Verify:
```bash
ls -la MacJarvis/Resources/Fonts/*.ttf
```
Expected: SpaceGrotesk-Regular.ttf, SpaceGrotesk-Medium.ttf, SpaceGrotesk-Bold.ttf

- [ ] **Step 4: Commit**

```bash
git add MacJarvis/Resources/Fonts/
git commit -m "chore: replace PressStart2P with Space Grotesk font files"
```

---

## Task 2: Rewrite CyberTheme.swift

**Files:**
- Rewrite: `MacJarvis/Theme/CyberTheme.swift`

- [ ] **Step 1: Rewrite CyberTheme.swift with new color palette, font system, and modifiers**

Replace the entire file. New contents:

```swift
import SwiftUI

// MARK: - Color Palette
struct CyberTheme {
    // Primary accent colors
    static let primary = Color(hex: 0x00FFC2)       // mint green
    static let secondary = Color(hex: 0xFFABF3)     // pink
    static let tertiary = Color(hex: 0xC3F400)      // yellow-green

    // Surface colors
    static let surface = Color(hex: 0x131318)
    static let surfaceContainer = Color(hex: 0x1F1F24)
    static let surfaceContainerHigh = Color(hex: 0x2A292F)
    static let surfaceContainerLow = Color(hex: 0x1B1B20)
    static let surfaceContainerLowest = Color(hex: 0x0E0E13)

    // Text colors
    static let onSurface = Color(hex: 0xE4E1E9)
    static let onSurfaceVariant = Color(hex: 0xB9CBC1)

    // Border colors
    static let outlineVariant = Color(hex: 0x3A4A43)

    // Legacy compat (used by existing services/tests)
    static let red = Color(hex: 0xFF0040)

    // Font names
    static let headlineFontName = "SpaceGrotesk-Bold"
    static let bodyFontName = "SpaceGrotesk-Regular"
    static let labelFontName = "SpaceGrotesk-Medium"

    // Spacing
    static let cardSpacing: CGFloat = 8

    static func headlineFont(size: CGFloat) -> Font {
        .custom(headlineFontName, size: size)
    }

    static func bodyFont(size: CGFloat) -> Font {
        .custom(bodyFontName, size: size)
    }

    static func labelFont(size: CGFloat) -> Font {
        .custom(labelFontName, size: size)
    }

    static func monoFont(size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - View Modifiers
struct NeonGlow: ViewModifier {
    var color: Color = CyberTheme.primary

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: 4, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 0)
    }
}

extension View {
    func neonGlow(color: Color = CyberTheme.primary) -> some View {
        modifier(NeonGlow(color: color))
    }
}

// MARK: - Pixel Progress Bar
struct PixelProgressBar: View {
    let value: Double  // 0.0 - 1.0
    let color: Color
    var segments: Int = 10

    var body: some View {
        HStack(spacing: 1) {
            let filledCount = Int(value * Double(segments))
            ForEach(0..<segments, id: \.self) { i in
                Rectangle()
                    .fill(i < filledCount ? color : CyberTheme.surfaceContainerLowest.opacity(0.2))
                    .overlay(
                        i < filledCount
                            ? Rectangle().fill(Color.black.opacity(0.3)).frame(width: 1).frame(maxWidth: .infinity, alignment: .trailing)
                            : nil
                    )
            }
        }
        .frame(height: 8)
        .padding(2)
        .background(CyberTheme.surfaceContainerLowest)
        .overlay(
            Rectangle().stroke(CyberTheme.outlineVariant.opacity(0.2), lineWidth: 1)
        )
    }
}
```

- [ ] **Step 2: Verify the file compiles (build will fail due to removed views, but theme should parse)**

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/MacJarvis
# Just check syntax — full build will fail until views are replaced
swift -typecheck MacJarvis/Theme/CyberTheme.swift 2>&1 || echo "Expected: may fail without SwiftUI context, check errors"
```

- [ ] **Step 3: Commit**

```bash
git add MacJarvis/Theme/CyberTheme.swift
git commit -m "feat: rewrite CyberTheme with new color palette and Space Grotesk fonts"
```

---

## Task 3: Update CRTEffect.swift — Add Pixel Grid

**Files:**
- Modify: `MacJarvis/Theme/CRTEffect.swift`

- [ ] **Step 1: Add PixelGrid modifier alongside existing CRT scanline effect**

Add at the end of the file (after line 32):

```swift
// MARK: - Pixel Grid Background
struct PixelGridBackground: View {
    var dotColor: Color = CyberTheme.outlineVariant
    var spacing: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            let dotRadius: CGFloat = 0.5
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func pixelGrid() -> some View {
        self.background(PixelGridBackground())
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add MacJarvis/Theme/CRTEffect.swift
git commit -m "feat: add pixel grid background modifier to CRTEffect"
```

---

## Task 4: Extend SettingsService with Token Budget Properties

**Files:**
- Modify: `MacJarvis/Services/SettingsService.swift:1-24`

- [ ] **Step 1: Add budget properties to SettingsService**

After the existing `openClawPort` property (line 10), add:

```swift
    var codexDailyBudget: Int = 100_000 {
        didSet { UserDefaults.standard.set(codexDailyBudget, forKey: "codexDailyBudget") }
    }
    var claudeDailyBudget: Int = 500_000 {
        didSet { UserDefaults.standard.set(claudeDailyBudget, forKey: "claudeDailyBudget") }
    }
    var geminiDailyBudget: Int = 1_000_000 {
        didSet { UserDefaults.standard.set(geminiDailyBudget, forKey: "geminiDailyBudget") }
    }
```

In the `init()` method, after the existing UserDefaults loads, add:

```swift
        if UserDefaults.standard.object(forKey: "codexDailyBudget") != nil {
            codexDailyBudget = UserDefaults.standard.integer(forKey: "codexDailyBudget")
        }
        if UserDefaults.standard.object(forKey: "claudeDailyBudget") != nil {
            claudeDailyBudget = UserDefaults.standard.integer(forKey: "claudeDailyBudget")
        }
        if UserDefaults.standard.object(forKey: "geminiDailyBudget") != nil {
            geminiDailyBudget = UserDefaults.standard.integer(forKey: "geminiDailyBudget")
        }
```

- [ ] **Step 2: Commit**

```bash
git add MacJarvis/Services/SettingsService.swift
git commit -m "feat: add configurable daily token budgets to SettingsService"
```

---

## Task 5: Add connectedAt to OpenClawService

**Files:**
- Modify: `MacJarvis/Services/OpenClawService.swift`

- [ ] **Step 1: Add `connectedAt` property**

After line 7 (the `status` property), add:

```swift
    var connectedAt: Date?
```

- [ ] **Step 2: Set connectedAt when connection succeeds**

In the `establishConnection()` method, find where `status = .running` is set (inside the ping success handler). Right after that line, add:

```swift
            self.connectedAt = Date.now
```

- [ ] **Step 3: Clear connectedAt on disconnect and error**

In `disconnect()`, after `status = .stopped`, add:

```swift
        connectedAt = nil
```

In `attemptReconnect()`, when status is set to error/stopped on max retries exceeded, ensure `connectedAt = nil` is also set.

Also in `handleError()` (around line 168), where `status = .stopped` is set, add `connectedAt = nil` to ensure uptime counter stops on any connection failure path.

- [ ] **Step 4: Run existing tests to verify no regressions**

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/MacJarvis
xcodegen generate
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug clean build-for-testing 2>&1 | tail -5
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug test-without-building 2>&1 | tail -20
```

Expected: All existing OpenClawService tests pass.

- [ ] **Step 5: Commit**

```bash
git add MacJarvis/Services/OpenClawService.swift
git commit -m "feat: add connectedAt timestamp to OpenClawService for uptime tracking"
```

---

## Task 6: Create SystemMonitorService

**Files:**
- Create: `MacJarvis/Services/SystemMonitorService.swift`

- [ ] **Step 1: Create SystemMonitorService with CPU usage and temperature reading**

```swift
import Foundation
import IOKit

@Observable @MainActor
final class SystemMonitorService {
    var cpuUsage: Double = 0.0
    var cpuTemperature: Double? = nil

    private var timer: Timer?
    private var previousCPUInfo: host_cpu_load_info?

    func startMonitoring() {
        fetchCPUUsage()
        fetchCPUTemperature()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchCPUUsage()
                self?.fetchCPUTemperature()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - CPU Usage via Mach API
    private func fetchCPUUsage() {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let host = mach_host_self()

        let result = withUnsafeMutablePointer(to: &cpuLoad) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(host, HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        if let prev = previousCPUInfo {
            let userDiff = Double(cpuLoad.cpu_ticks.0 - prev.cpu_ticks.0)
            let sysDiff = Double(cpuLoad.cpu_ticks.1 - prev.cpu_ticks.1)
            let idleDiff = Double(cpuLoad.cpu_ticks.2 - prev.cpu_ticks.2)
            let niceDiff = Double(cpuLoad.cpu_ticks.3 - prev.cpu_ticks.3)
            let totalDiff = userDiff + sysDiff + idleDiff + niceDiff
            if totalDiff > 0 {
                cpuUsage = ((userDiff + sysDiff + niceDiff) / totalDiff) * 100.0
            }
        }
        previousCPUInfo = cpuLoad
    }

    // MARK: - CPU Temperature via SMC
    private func fetchCPUTemperature() {
        Task.detached { [weak self] in
            let temp = Self.readSMCTemperature()
            await MainActor.run { [weak self] in
                self?.cpuTemperature = temp
            }
        }
    }

    private nonisolated static func readSMCTemperature() -> Double? {
        let serviceName = "AppleSMC"
        var conn: io_connect_t = 0

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(serviceName))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        let openResult = IOServiceOpen(service, mach_task_self_, 0, &conn)
        guard openResult == kIOReturnSuccess else { return nil }
        defer { IOServiceClose(conn) }

        // SMC key "TC0P" = CPU proximity temperature
        // Encoded as 4 bytes: 'T','C','0','P'
        var inputStruct = SMCKeyData()
        inputStruct.key = fourCharCode("TC0P")
        inputStruct.data8 = 5 // kSMCReadKey

        var outputStruct = SMCKeyData()
        var outputSize = MemoryLayout<SMCKeyData>.stride

        let callResult = IOConnectCallStructMethod(
            conn, 2, // kSMCHandleYPCEvent
            &inputStruct, MemoryLayout<SMCKeyData>.stride,
            &outputStruct, &outputSize
        )

        guard callResult == kIOReturnSuccess else { return nil }

        // fpe2 format: first byte is integer part, second byte is fractional * 256
        let intPart = Double(outputStruct.bytes.0)
        let fracPart = Double(outputStruct.bytes.1) / 256.0
        let temperature = intPart + fracPart

        return temperature > 0 && temperature < 150 ? temperature : nil
    }

    private nonisolated static func fourCharCode(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for char in str.utf8.prefix(4) {
            result = (result << 8) | UInt32(char)
        }
        return result
    }
}

// MARK: - SMC Data Structures
private struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

private struct SMCVersion {
    var major: CUnsignedChar = 0
    var minor: CUnsignedChar = 0
    var build: CUnsignedChar = 0
    var reserved: CUnsignedChar = 0
    var release: CUnsignedShort = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: IOByteCount = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}
```

Note: The SMC struct layout must match the kernel driver's expectations exactly. If temperature reading fails on this machine, the `cpuTemperature` will be `nil` and the UI shows "--°C". This is acceptable per spec.

- [ ] **Step 2: Commit**

```bash
git add MacJarvis/Services/SystemMonitorService.swift
git commit -m "feat: add SystemMonitorService for CPU usage and temperature monitoring"
```

---

## Task 7: Delete Old Views & Create LobsterShape

**Files:**
- Delete: `MacJarvis/Views/DashboardView.swift`
- Delete: `MacJarvis/Views/TokenCardView.swift`
- Delete: `MacJarvis/Views/ClawStatusCardView.swift`
- Delete: `MacJarvis/Views/ClockCardView.swift`
- Delete: `MacJarvis/Views/ChatView.swift`
- Delete: `MacJarvis/Views/PTTButton.swift`
- Delete: `MacJarvis/Views/SettingsView.swift`
- Create: `MacJarvis/Views/LobsterShape.swift`

- [ ] **Step 1: Delete all old view files**

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/MacJarvis
rm MacJarvis/Views/DashboardView.swift
rm MacJarvis/Views/TokenCardView.swift
rm MacJarvis/Views/ClawStatusCardView.swift
rm MacJarvis/Views/ClockCardView.swift
rm MacJarvis/Views/ChatView.swift
rm MacJarvis/Views/PTTButton.swift
rm MacJarvis/Views/SettingsView.swift
```

- [ ] **Step 2: Create LobsterShape.swift — SVG path converted to SwiftUI**

```swift
import SwiftUI

struct LobsterShape: View {
    var bodyColor: Color = CyberTheme.primary
    var antennaColor: Color = Color(hex: 0xFF6B6B)
    var eyeHighlightColor: Color = Color(hex: 0x00E5CC)

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / 120
            let scaleY = size.height / 120

            // Body
            var bodyPath = Path()
            bodyPath.move(to: CGPoint(x: 60 * scaleX, y: 10 * scaleY))
            bodyPath.addCurve(
                to: CGPoint(x: 15 * scaleX, y: 55 * scaleY),
                control1: CGPoint(x: 30 * scaleX, y: 10 * scaleY),
                control2: CGPoint(x: 15 * scaleX, y: 35 * scaleY)
            )
            bodyPath.addCurve(
                to: CGPoint(x: 45 * scaleX, y: 100 * scaleY),
                control1: CGPoint(x: 15 * scaleX, y: 75 * scaleY),
                control2: CGPoint(x: 30 * scaleX, y: 95 * scaleY)
            )
            bodyPath.addLine(to: CGPoint(x: 45 * scaleX, y: 110 * scaleY))
            bodyPath.addLine(to: CGPoint(x: 55 * scaleX, y: 110 * scaleY))
            bodyPath.addLine(to: CGPoint(x: 55 * scaleX, y: 100 * scaleY))
            bodyPath.addCurve(
                to: CGPoint(x: 65 * scaleX, y: 100 * scaleY),
                control1: CGPoint(x: 60 * scaleX, y: 102 * scaleY),
                control2: CGPoint(x: 65 * scaleX, y: 100 * scaleY)
            )
            bodyPath.addLine(to: CGPoint(x: 65 * scaleX, y: 110 * scaleY))
            bodyPath.addLine(to: CGPoint(x: 75 * scaleX, y: 110 * scaleY))
            bodyPath.addLine(to: CGPoint(x: 75 * scaleX, y: 100 * scaleY))
            bodyPath.addCurve(
                to: CGPoint(x: 105 * scaleX, y: 55 * scaleY),
                control1: CGPoint(x: 90 * scaleX, y: 95 * scaleY),
                control2: CGPoint(x: 105 * scaleX, y: 75 * scaleY)
            )
            bodyPath.addCurve(
                to: CGPoint(x: 60 * scaleX, y: 10 * scaleY),
                control1: CGPoint(x: 105 * scaleX, y: 35 * scaleY),
                control2: CGPoint(x: 90 * scaleX, y: 10 * scaleY)
            )
            bodyPath.closeSubpath()
            context.fill(bodyPath, with: .color(bodyColor))

            // Left claw
            var leftClaw = Path()
            leftClaw.move(to: CGPoint(x: 20 * scaleX, y: 45 * scaleY))
            leftClaw.addCurve(
                to: CGPoint(x: 5 * scaleX, y: 60 * scaleY),
                control1: CGPoint(x: 5 * scaleX, y: 40 * scaleY),
                control2: CGPoint(x: 0 * scaleX, y: 50 * scaleY)
            )
            leftClaw.addCurve(
                to: CGPoint(x: 25 * scaleX, y: 55 * scaleY),
                control1: CGPoint(x: 10 * scaleX, y: 70 * scaleY),
                control2: CGPoint(x: 20 * scaleX, y: 65 * scaleY)
            )
            leftClaw.addCurve(
                to: CGPoint(x: 20 * scaleX, y: 45 * scaleY),
                control1: CGPoint(x: 28 * scaleX, y: 48 * scaleY),
                control2: CGPoint(x: 25 * scaleX, y: 45 * scaleY)
            )
            leftClaw.closeSubpath()
            context.fill(leftClaw, with: .color(bodyColor))

            // Right claw
            var rightClaw = Path()
            rightClaw.move(to: CGPoint(x: 100 * scaleX, y: 45 * scaleY))
            rightClaw.addCurve(
                to: CGPoint(x: 115 * scaleX, y: 60 * scaleY),
                control1: CGPoint(x: 115 * scaleX, y: 40 * scaleY),
                control2: CGPoint(x: 120 * scaleX, y: 50 * scaleY)
            )
            rightClaw.addCurve(
                to: CGPoint(x: 95 * scaleX, y: 55 * scaleY),
                control1: CGPoint(x: 110 * scaleX, y: 70 * scaleY),
                control2: CGPoint(x: 100 * scaleX, y: 65 * scaleY)
            )
            rightClaw.addCurve(
                to: CGPoint(x: 100 * scaleX, y: 45 * scaleY),
                control1: CGPoint(x: 92 * scaleX, y: 48 * scaleY),
                control2: CGPoint(x: 95 * scaleX, y: 45 * scaleY)
            )
            rightClaw.closeSubpath()
            context.fill(rightClaw, with: .color(bodyColor))

            // Left antenna
            var leftAntenna = Path()
            leftAntenna.move(to: CGPoint(x: 45 * scaleX, y: 15 * scaleY))
            leftAntenna.addQuadCurve(
                to: CGPoint(x: 30 * scaleX, y: 8 * scaleY),
                control: CGPoint(x: 35 * scaleX, y: 5 * scaleY)
            )
            context.stroke(leftAntenna, with: .color(antennaColor), style: StrokeStyle(lineWidth: 2 * min(scaleX, scaleY), lineCap: .round))

            // Right antenna
            var rightAntenna = Path()
            rightAntenna.move(to: CGPoint(x: 75 * scaleX, y: 15 * scaleY))
            rightAntenna.addQuadCurve(
                to: CGPoint(x: 90 * scaleX, y: 8 * scaleY),
                control: CGPoint(x: 85 * scaleX, y: 5 * scaleY)
            )
            context.stroke(rightAntenna, with: .color(antennaColor), style: StrokeStyle(lineWidth: 2 * min(scaleX, scaleY), lineCap: .round))

            // Eyes (dark circles)
            let leftEye = CGRect(x: (45 - 6) * scaleX, y: (35 - 6) * scaleY, width: 12 * scaleX, height: 12 * scaleY)
            let rightEye = CGRect(x: (75 - 6) * scaleX, y: (35 - 6) * scaleY, width: 12 * scaleX, height: 12 * scaleY)
            context.fill(Path(ellipseIn: leftEye), with: .color(Color(hex: 0x050810)))
            context.fill(Path(ellipseIn: rightEye), with: .color(Color(hex: 0x050810)))

            // Eye highlights
            let leftHighlight = CGRect(x: (46 - 2) * scaleX, y: (34 - 2) * scaleY, width: 4 * scaleX, height: 4 * scaleY)
            let rightHighlight = CGRect(x: (76 - 2) * scaleX, y: (34 - 2) * scaleY, width: 4 * scaleX, height: 4 * scaleY)
            context.fill(Path(ellipseIn: leftHighlight), with: .color(eyeHighlightColor))
            context.fill(Path(ellipseIn: rightHighlight), with: .color(eyeHighlightColor))
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add -A MacJarvis/Views/
git commit -m "feat: delete old views, create LobsterShape SVG-to-SwiftUI Path"
```

---

## Task 8: Create HeaderView

**Files:**
- Create: `MacJarvis/Views/HeaderView.swift`

- [ ] **Step 1: Create HeaderView with title, clock, and settings button**

```swift
import SwiftUI

struct HeaderView: View {
    @State private var currentTime = Date()
    @Binding var showSettings: Bool

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .foregroundColor(CyberTheme.primary)
                    .font(.system(size: 14))
                Text("[SYS.MONITOR.v4.LND]")
                    .font(CyberTheme.headlineFont(size: 10))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundColor(CyberTheme.primary)
            }

            Spacer()

            HStack(spacing: 16) {
                Text("Neo-Tokyo-01")
                    .font(CyberTheme.labelFont(size: 8))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(CyberTheme.onSurfaceVariant)

                Text(timeFormatter.string(from: currentTime))
                    .font(CyberTheme.labelFont(size: 8))
                    .tracking(2)
                    .foregroundColor(CyberTheme.primary)
                    .onReceive(timer) { currentTime = $0 }

                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(CyberTheme.primary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(CyberTheme.surfaceContainerHigh.opacity(0.8))
        .overlay(alignment: .bottom) {
            Rectangle().fill(CyberTheme.primary.opacity(0.2)).frame(height: 1)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add MacJarvis/Views/HeaderView.swift
git commit -m "feat: create HeaderView with title, clock, and settings toggle"
```

---

## Task 9: Create CoreStatusView

**Files:**
- Create: `MacJarvis/Views/CoreStatusView.swift`

- [ ] **Step 1: Create CoreStatusView with lobster icon, OpenClaw status, uptime, and signal bar**

```swift
import SwiftUI

struct CoreStatusView: View {
    @Environment(OpenClawService.self) private var clawService

    @State private var now = Date()
    private let uptimeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var statusText: String {
        clawService.status == .running ? "OPENCLAW ACTIVE" : "OPENCLAW \(clawService.status.label)"
    }

    private var uptimeText: String {
        guard let connectedAt = clawService.connectedAt else { return "---:--:--:--" }
        let interval = now.timeIntervalSince(connectedAt)
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%03d:%02d:%02d:%02d", days, hours, minutes, seconds)
    }

    private var signalValue: Double {
        switch clawService.status {
        case .running: return 0.98
        case .error: return 0.15
        case .stopped, .unknown: return 0.0
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main status area
            VStack(spacing: 8) {
                Spacer()

                // Lobster with glow
                ZStack {
                    Circle()
                        .fill(CyberTheme.primary.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .blur(radius: 16)
                        .opacity(clawService.status == .running ? 1 : 0.3)

                    LobsterShape()
                        .frame(width: 64, height: 64)
                        .neonGlow()
                        .opacity(clawService.status == .running ? 1 : 0.4)
                }

                // Status text
                Text(statusText)
                    .font(CyberTheme.headlineFont(size: 10))
                    .tracking(1)
                    .foregroundColor(CyberTheme.primary)

                // Uptime
                Text(uptimeText)
                    .font(CyberTheme.monoFont(size: 8))
                    .tracking(2)
                    .foregroundColor(CyberTheme.onSurfaceVariant.opacity(0.7))
                    .onReceive(uptimeTimer) { now = $0 }

                Spacer()

                // Signal bar
                VStack(spacing: 4) {
                    HStack {
                        Text("Signal")
                            .font(CyberTheme.headlineFont(size: 7))
                            .textCase(.uppercase)
                            .foregroundColor(CyberTheme.tertiary)
                        Spacer()
                        Text(signalValue > 0 ? "\(Int(signalValue * 100))%" : "--")
                            .font(CyberTheme.headlineFont(size: 7))
                            .foregroundColor(CyberTheme.tertiary)
                    }
                    PixelProgressBar(value: signalValue, color: CyberTheme.tertiary)
                        .frame(height: 4)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CyberTheme.surfaceContainerHigh.opacity(0.5))
            .overlay(
                Rectangle().stroke(CyberTheme.outlineVariant.opacity(0.3), lineWidth: 1)
            )
            // Corner dots
            .overlay(alignment: .topLeading) { cornerDot }
            .overlay(alignment: .topTrailing) { cornerDot }
            .overlay(alignment: .bottomLeading) { cornerDot }
            .overlay(alignment: .bottomTrailing) { cornerDot }
            // "Core Status" label
            .overlay(alignment: .topLeading) {
                Text("Core Status")
                    .font(CyberTheme.headlineFont(size: 7))
                    .tracking(3)
                    .textCase(.uppercase)
                    .foregroundColor(CyberTheme.onSurfaceVariant.opacity(0.6))
                    .padding(.top, 8)
                    .padding(.leading, 12)
            }
        }
    }

    private var cornerDot: some View {
        Rectangle()
            .fill(CyberTheme.primary)
            .frame(width: 4, height: 4)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add MacJarvis/Views/CoreStatusView.swift
git commit -m "feat: create CoreStatusView with lobster, status, uptime, signal bar"
```

---

## Task 10: Create HardwareStatsView

**Files:**
- Create: `MacJarvis/Views/HardwareStatsView.swift`

- [ ] **Step 1: Create HardwareStatsView showing CPU load and temperature**

```swift
import SwiftUI

struct HardwareStatsView: View {
    @Environment(SystemMonitorService.self) private var monitor

    var body: some View {
        HStack(spacing: CyberTheme.cardSpacing) {
            // CPU Load
            VStack(alignment: .leading, spacing: 4) {
                Text("CPU Load")
                    .font(CyberTheme.headlineFont(size: 7))
                    .textCase(.uppercase)
                    .foregroundColor(CyberTheme.onSurfaceVariant)
                Text(String(format: "%.1f%%", monitor.cpuUsage))
                    .font(CyberTheme.headlineFont(size: 12))
                    .foregroundColor(CyberTheme.onSurface)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(CyberTheme.surfaceContainer)
            .overlay(alignment: .top) {
                Rectangle().fill(CyberTheme.primary.opacity(0.4)).frame(height: 1)
            }

            // Temperature
            VStack(alignment: .leading, spacing: 4) {
                Text("Temp")
                    .font(CyberTheme.headlineFont(size: 7))
                    .textCase(.uppercase)
                    .foregroundColor(CyberTheme.onSurfaceVariant)
                Text(monitor.cpuTemperature.map { String(format: "%.0f°C", $0) } ?? "--°C")
                    .font(CyberTheme.headlineFont(size: 12))
                    .foregroundColor(CyberTheme.onSurface)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(CyberTheme.surfaceContainer)
            .overlay(alignment: .top) {
                Rectangle().fill(CyberTheme.secondary.opacity(0.4)).frame(height: 1)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add MacJarvis/Views/HardwareStatsView.swift
git commit -m "feat: create HardwareStatsView for CPU load and temperature display"
```

---

## Task 11: Create TokenCard and TokenColumnView

**Files:**
- Create: `MacJarvis/Views/TokenCard.swift`
- Create: `MacJarvis/Views/TokenColumnView.swift`

- [ ] **Step 1: Create TokenCard.swift**

```swift
import SwiftUI

struct TokenCard: View {
    let usage: ToolUsage
    let accentColor: Color
    let subtitle: String
    let iconName: String
    let budget: Int

    private var percentage: Double? {
        guard budget > 0, let tokens = usage.totalTokens else { return nil }
        return min(Double(tokens) / Double(budget), 1.0)
    }

    private var usageText: String {
        if let tokens = usage.totalTokens {
            let formatted = usage.formattedTokens
            let budgetFormatted = formatNumber(budget)
            return "\(formatted)/\(budgetFormatted)"
        } else if let msgs = usage.messageCount {
            return "\(msgs) msg"
        }
        return "--"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(usage.name.uppercased())
                        .font(CyberTheme.headlineFont(size: 9))
                        .foregroundColor(accentColor)
                    Text(subtitle)
                        .font(CyberTheme.labelFont(size: 7))
                        .foregroundColor(CyberTheme.onSurfaceVariant)
                }
                Spacer()
                Image(systemName: iconName)
                    .foregroundColor(accentColor)
                    .font(.system(size: 14))
            }

            Spacer()

            // Value row
            HStack(alignment: .bottom) {
                if let pct = percentage {
                    Text("\(Int(pct * 100))%")
                        .font(CyberTheme.headlineFont(size: 18))
                        .foregroundColor(CyberTheme.onSurface)
                } else if usage.totalTokens == nil, let msgs = usage.messageCount {
                    Text("\(msgs)")
                        .font(CyberTheme.headlineFont(size: 18))
                        .foregroundColor(CyberTheme.onSurface)
                    Text("msg")
                        .font(CyberTheme.labelFont(size: 8))
                        .foregroundColor(CyberTheme.onSurfaceVariant)
                } else {
                    Text("--")
                        .font(CyberTheme.headlineFont(size: 18))
                        .foregroundColor(CyberTheme.onSurface)
                }
                Spacer()
                Text(usageText)
                    .font(CyberTheme.labelFont(size: 7))
                    .textCase(.uppercase)
                    .foregroundColor(CyberTheme.onSurfaceVariant)
            }

            // Progress bar
            if let pct = percentage {
                PixelProgressBar(value: pct, color: accentColor)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(CyberTheme.surfaceContainerLow.opacity(0.6))
        .overlay(alignment: .leading) {
            Rectangle().fill(accentColor).frame(width: 2)
        }
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.0fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
```

- [ ] **Step 2: Create TokenColumnView.swift**

```swift
import SwiftUI

struct TokenColumnView: View {
    @Environment(TokenService.self) private var tokenService
    @Environment(SettingsService.self) private var settings

    var body: some View {
        VStack(spacing: CyberTheme.cardSpacing) {
            if let codex = tokenService.tools.first(where: { $0.id == "codex" }) {
                TokenCard(
                    usage: codex,
                    accentColor: CyberTheme.primary,
                    subtitle: "v4.2-STABLE",
                    iconName: "chevron.left.forwardslash.chevron.right",
                    budget: settings.codexDailyBudget
                )
            }
            if let gemini = tokenService.tools.first(where: { $0.id == "gemini" }) {
                TokenCard(
                    usage: gemini,
                    accentColor: CyberTheme.secondary,
                    subtitle: "FLASH-ULTRA",
                    iconName: "memorychip",
                    budget: settings.geminiDailyBudget
                )
            }
            if let claude = tokenService.tools.first(where: { $0.id == "claude" }) {
                TokenCard(
                    usage: claude,
                    accentColor: CyberTheme.tertiary,
                    subtitle: "OPUS-DIRECT",
                    iconName: "brain.head.profile",
                    budget: settings.claudeDailyBudget
                )
            }
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add MacJarvis/Views/TokenCard.swift MacJarvis/Views/TokenColumnView.swift
git commit -m "feat: create TokenCard and TokenColumnView with budget-based progress bars"
```

---

## Task 12: Create TerminalLogView

**Files:**
- Create: `MacJarvis/Views/TerminalLogView.swift`

- [ ] **Step 1: Create TerminalLogView with terminal-style message rendering and NEW COMMAND button**

```swift
import SwiftUI

struct TerminalLogView: View {
    @Environment(OpenClawService.self) private var clawService
    @Environment(VoiceService.self) private var voiceService

    @State private var isInputMode = false
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Terminal header
            HStack(spacing: 6) {
                Circle()
                    .fill(CyberTheme.primary)
                    .frame(width: 6, height: 6)
                    .opacity(clawService.status == .running ? 1 : 0.3)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: clawService.status == .running)

                Text("Logs_Live :: Extended_Readout_v4")
                    .font(CyberTheme.monoFont(size: 8))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(CyberTheme.onSurfaceVariant)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle().fill(CyberTheme.outlineVariant.opacity(0.1)).frame(height: 1)
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(clawService.messages) { msg in
                            terminalLine(for: msg)
                                .id(msg.id)
                        }
                    }
                }
                .onChange(of: clawService.messages.count) {
                    if let last = clawService.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // Command area
            if isInputMode {
                HStack(spacing: 8) {
                    TextField("Enter command...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(CyberTheme.monoFont(size: 10))
                        .foregroundColor(CyberTheme.primary)
                        .padding(8)
                        .background(CyberTheme.surfaceContainer)
                        .onSubmit { sendMessage() }

                    Button("SEND") { sendMessage() }
                        .font(CyberTheme.headlineFont(size: 9))
                        .foregroundColor(CyberTheme.surface)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(CyberTheme.primary)
                        .buttonStyle(.plain)

                    Button("ESC") {
                        isInputMode = false
                        inputText = ""
                    }
                    .font(CyberTheme.labelFont(size: 8))
                    .foregroundColor(CyberTheme.onSurfaceVariant)
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            } else {
                // NEW COMMAND button with PTT support
                Button {
                    isInputMode = true
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "plus")
                            .font(.system(size: 14))
                        Text("NEW COMMAND")
                            .font(CyberTheme.headlineFont(size: 10))
                            .tracking(3)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundColor(CyberTheme.surface)
                    .background(commandButtonColor)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !voiceService.isRecording && !voiceService.isTranscribing {
                                voiceService.startRecording()
                            }
                        }
                        .onEnded { _ in
                            if voiceService.isRecording {
                                voiceService.stopAndTranscribe()
                            }
                        }
                )
                .onChange(of: voiceService.isTranscribing) { _, isTranscribing in
                    if !isTranscribing && !voiceService.transcript.isEmpty {
                        inputText = voiceService.transcript
                        isInputMode = true
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(CyberTheme.surfaceContainerLowest)
        .overlay(
            Rectangle().stroke(CyberTheme.outlineVariant.opacity(0.2), lineWidth: 1)
        )
    }

    private var commandButtonColor: Color {
        if voiceService.isRecording { return CyberTheme.red }
        if voiceService.isTranscribing { return CyberTheme.secondary }
        return CyberTheme.primary
    }

    private func terminalLine(for msg: ChatMessage) -> some View {
        let timestamp = timeFormatter.string(from: msg.timestamp)
        let prefix = msg.role == .user ? "USER" : "CLAW"
        let color = msg.role == .assistant ? CyberTheme.primary : CyberTheme.onSurface

        return HStack(alignment: .top, spacing: 0) {
            Text("[\(timestamp)] ")
                .foregroundColor(CyberTheme.onSurfaceVariant)
            Text(">> \(prefix): ")
                .foregroundColor(color)
            Text(msg.content)
                .foregroundColor(color.opacity(0.7))
        }
        .font(CyberTheme.monoFont(size: 9))
        .lineLimit(nil)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // sendMessage() internally calls addUserMessage(), so don't call it separately
        clawService.sendMessage(text)
        inputText = ""
        isInputMode = false
    }

    private func startRecording() {
        voiceService.startRecording()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add MacJarvis/Views/TerminalLogView.swift
git commit -m "feat: create TerminalLogView with terminal log rendering and PTT command input"
```

---

## Task 13: Create BottomNavBar

**Files:**
- Create: `MacJarvis/Views/BottomNavBar.swift`

- [ ] **Step 1: Create decorative bottom navigation bar**

```swift
import SwiftUI

struct BottomNavBar: View {
    var body: some View {
        HStack(spacing: 0) {
            // OpenClaw tab (active/highlighted)
            navItem(
                icon: { LobsterShape(bodyColor: CyberTheme.surface).frame(width: 20, height: 20) },
                label: "OPENCLAW",
                isActive: true
            )

            // Codex tab
            navItem(
                icon: { Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 16)) },
                label: "CODEX",
                isActive: false
            )

            // Gemini tab
            navItem(
                icon: { Image(systemName: "memorychip").font(.system(size: 16)) },
                label: "GEMINI",
                isActive: false
            )

            // Claude tab
            navItem(
                icon: { Image(systemName: "brain.head.profile").font(.system(size: 16)) },
                label: "CLAUDE",
                isActive: false
            )
        }
        .frame(height: 48)
        .background(CyberTheme.surface)
        .pixelGrid()
        .overlay(alignment: .top) {
            Rectangle().fill(CyberTheme.surfaceContainerHigh).frame(height: 1)
        }
    }

    private func navItem<Icon: View>(
        @ViewBuilder icon: () -> Icon,
        label: String,
        isActive: Bool
    ) -> some View {
        VStack(spacing: 2) {
            icon()
            Text(label)
                .font(CyberTheme.headlineFont(size: 8))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .foregroundColor(isActive ? CyberTheme.surface : CyberTheme.onSurface.opacity(0.5))
        .background(isActive ? CyberTheme.primary : Color.clear)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add MacJarvis/Views/BottomNavBar.swift
git commit -m "feat: create decorative BottomNavBar with 4 tabs"
```

---

## Task 14: Create SettingsView

**Files:**
- Create: `MacJarvis/Views/SettingsView.swift`

- [ ] **Step 1: Create SettingsView with OpenClaw config and token budget settings**

```swift
import SwiftUI

struct SettingsView: View {
    @Environment(SettingsService.self) private var settings
    @Environment(OpenClawService.self) private var clawService
    @Binding var isPresented: Bool

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("SETTINGS")
                    .font(CyberTheme.headlineFont(size: 12))
                    .tracking(3)
                    .foregroundColor(CyberTheme.primary)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(CyberTheme.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }

            // OpenClaw section
            sectionHeader("OPENCLAW CONNECTION")

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HOST").font(CyberTheme.labelFont(size: 7)).foregroundColor(CyberTheme.onSurfaceVariant)
                    TextField("127.0.0.1", text: $settings.openClawHost)
                        .textFieldStyle(.plain)
                        .font(CyberTheme.monoFont(size: 10))
                        .foregroundColor(CyberTheme.onSurface)
                        .padding(6)
                        .background(CyberTheme.surfaceContainerLowest)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("PORT").font(CyberTheme.labelFont(size: 7)).foregroundColor(CyberTheme.onSurfaceVariant)
                    TextField("18789", value: $settings.openClawPort, format: .number)
                        .textFieldStyle(.plain)
                        .font(CyberTheme.monoFont(size: 10))
                        .foregroundColor(CyberTheme.onSurface)
                        .padding(6)
                        .background(CyberTheme.surfaceContainerLowest)
                        .frame(width: 80)
                }
            }

            Button("RECONNECT") {
                Task { await clawService.connect(to: settings.openClawWebSocketURL) }
            }
            .font(CyberTheme.headlineFont(size: 9))
            .tracking(2)
            .foregroundColor(CyberTheme.surface)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(CyberTheme.primary)
            .buttonStyle(.plain)

            Divider().background(CyberTheme.outlineVariant)

            // Token budgets section
            sectionHeader("DAILY TOKEN BUDGETS")

            budgetRow(label: "CODEX", value: $settings.codexDailyBudget, color: CyberTheme.primary)
            budgetRow(label: "CLAUDE", value: $settings.claudeDailyBudget, color: CyberTheme.tertiary)
            budgetRow(label: "GEMINI", value: $settings.geminiDailyBudget, color: CyberTheme.secondary)

            Text("Set to 0 to hide percentage. Values are daily token limits for progress bar display.")
                .font(CyberTheme.labelFont(size: 7))
                .foregroundColor(CyberTheme.onSurfaceVariant.opacity(0.6))

            Spacer()
        }
        .padding(16)
        .frame(width: 320, height: 420)
        .background(CyberTheme.surfaceContainer)
        .overlay(
            Rectangle().stroke(CyberTheme.outlineVariant.opacity(0.3), lineWidth: 1)
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(CyberTheme.headlineFont(size: 8))
            .tracking(2)
            .foregroundColor(CyberTheme.onSurfaceVariant.opacity(0.6))
    }

    private func budgetRow(label: String, value: Binding<Int>, color: Color) -> some View {
        HStack {
            Rectangle().fill(color).frame(width: 2, height: 20)
            Text(label)
                .font(CyberTheme.labelFont(size: 8))
                .foregroundColor(color)
                .frame(width: 60, alignment: .leading)
            TextField("0", value: value, format: .number)
                .textFieldStyle(.plain)
                .font(CyberTheme.monoFont(size: 10))
                .foregroundColor(CyberTheme.onSurface)
                .padding(6)
                .background(CyberTheme.surfaceContainerLowest)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add MacJarvis/Views/SettingsView.swift
git commit -m "feat: create SettingsView with OpenClaw config and token budget settings"
```

---

## Task 15: Create DashboardView — Main Layout Container

**Files:**
- Create: `MacJarvis/Views/DashboardView.swift`

- [ ] **Step 1: Create new DashboardView with 3-column layout**

```swift
import SwiftUI

struct DashboardView: View {
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Main layout
            VStack(spacing: 0) {
                // Header
                HeaderView(showSettings: $showSettings)

                // 3-column grid
                HStack(spacing: 8) {
                    // Left column (3/12 ≈ 25%)
                    VStack(spacing: 8) {
                        CoreStatusView()
                        HardwareStatsView()
                    }
                    .frame(width: 175)

                    // Middle column (3/12 ≈ 25%)
                    TokenColumnView()
                        .frame(width: 175)

                    // Right column (6/12 ≈ 50%)
                    TerminalLogView()
                }
                .padding(8)

                // Bottom nav
                BottomNavBar()
            }
            .background(CyberTheme.surface)
            .pixelGrid()
            // CRT scanline effect (single layer, not doubled)
            .crtEffect()

            // Settings popover
            if showSettings {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { showSettings = false }

                SettingsView(isPresented: $showSettings)
            }
        }
        .frame(width: 800, height: 480)
        .clipped()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add MacJarvis/Views/DashboardView.swift
git commit -m "feat: create DashboardView with 3-column terminal layout"
```

---

## Task 16: Update MacJarvisApp.swift

**Files:**
- Modify: `MacJarvis/MacJarvisApp.swift:1-38`

- [ ] **Step 1: Add SystemMonitorService injection**

Add after line 10 (the voiceService declaration):

```swift
    @State private var systemMonitor = SystemMonitorService()
```

Add to the `.environment()` chain in the body (after `.environment(voiceService)`):

```swift
                .environment(systemMonitor)
```

In the `.onAppear` block, after `voiceService.loadModel()`, add:

```swift
                    systemMonitor.startMonitoring()
```

- [ ] **Step 2: Regenerate Xcode project and build**

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/MacJarvis
xcodegen generate
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Fix any compilation errors**

Address any issues from the build output. Common issues:
- Missing imports
- Property access mismatches between VoiceService API and TerminalLogView usage
- Font name mismatches if static TTF files have different PostScript names

- [ ] **Step 4: Commit**

```bash
git add MacJarvis/MacJarvisApp.swift
git commit -m "feat: inject SystemMonitorService into app environment"
```

---

## Task 17: Build Verification & Fix

**Files:**
- All files from previous tasks

- [ ] **Step 1: Regenerate project and full build**

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/MacJarvis
xcodegen generate
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED with 0 errors.

- [ ] **Step 2: Run existing tests**

```bash
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug clean build-for-testing 2>&1 | tail -5
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug test-without-building 2>&1 | tail -20
```

Expected: All existing tests pass. UI tests may need updates if they reference old view elements.

- [ ] **Step 3: Fix any issues found**

Iterate on compilation errors or test failures until clean.

- [ ] **Step 4: Commit final fixes**

```bash
git add -A
git commit -m "fix: resolve build and test issues from UI overhaul"
```

---

## Task 18: Visual Verification

- [ ] **Step 1: Launch the app and visually verify**

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/MacJarvis
xcodegen generate
open MacJarvis.xcodeproj
```

Run the app (Cmd+R in Xcode) and verify:
1. Header shows title, clock ticking, settings gear works
2. Left column: lobster icon visible, OpenClaw status shows correctly, CPU/Temp values update
3. Middle column: 3 token cards with real data from local sources
4. Right column: terminal log area works, NEW COMMAND button opens input
5. Bottom nav bar visible with 4 tabs, OpenClaw highlighted
6. CRT scanline effect and pixel grid visible
7. 800×480 window size correct

- [ ] **Step 2: Fix any visual issues**

Adjust spacing, colors, font sizes to match the HTML mockup.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "polish: visual adjustments for UI overhaul completion"
```
