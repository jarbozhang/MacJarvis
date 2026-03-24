# MacJarvis M1-M2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build MacJarvis app skeleton with cyberpunk theme, external display detection, and Codex token dashboard.

**Architecture:** Single SwiftUI app (macOS 14+) with modular @Observable Services. DisplayManager detects 800×480 screen for fullscreen mode. TokenService reads Codex SQLite database for token usage. Cyberpunk/pixel-art visual theme throughout.

**Tech Stack:** SwiftUI, Swift 5.9+, macOS 14+ (Sonoma), libsqlite3, Press Start 2P font

**Spec:** `docs/superpowers/specs/2026-03-21-mac-jarvis-design.md`

---

## File Structure

```
MacJarvis/
├── MacJarvis.xcodeproj/
├── MacJarvis/
│   ├── MacJarvisApp.swift              -- App entry point, window configuration
│   ├── Info.plist                       -- NSMicrophoneUsageDescription, font registration
│   ├── MacJarvis.entitlements           -- Sandbox disabled
│   ├── Resources/
│   │   ├── Fonts/
│   │   │   ├── PressStart2P-Regular.ttf -- Pixel font
│   │   │   └── OFL.txt                 -- Font license
│   │   └── Assets.xcassets/             -- App icon, colors
│   ├── Theme/
│   │   ├── CyberTheme.swift            -- Color palette, font helpers, spacing
│   │   └── CRTEffect.swift             -- CRT scanline overlay ViewModifier
│   ├── Services/
│   │   ├── DisplayManager.swift         -- External screen detection + window management
│   │   └── TokenService.swift           -- SQLite reader for Codex token data
│   ├── Models/
│   │   ├── ToolUsage.swift              -- Token usage data model
│   │   └── ClawStatus.swift             -- OpenClaw status enum (placeholder)
│   └── Views/
│       ├── DashboardView.swift          -- Main layout: status cards + chat area
│       ├── TokenCardView.swift          -- Token usage card with pixel progress bars
│       ├── ClawStatusCardView.swift     -- OpenClaw status card (placeholder)
│       ├── ClockCardView.swift          -- Cyberpunk clock/date display
│       └── ChatPlaceholderView.swift    -- Placeholder for future chat area
├── MacJarvisTests/
│   ├── TokenServiceTests.swift          -- SQLite reading tests
│   └── DisplayManagerTests.swift        -- Screen matching logic tests
```

---

## Task 1: Create Xcode Project Skeleton

**Files:**
- Create: `MacJarvis/MacJarvisApp.swift`
- Create: `MacJarvis/MacJarvis.entitlements`
- Create: `MacJarvis/Info.plist`

- [ ] **Step 1: Create Xcode project directory structure**

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/mac-jarvis
mkdir -p MacJarvis/MacJarvis/{Resources/Fonts,Resources/Assets.xcassets,Theme,Services,Models,Views}
mkdir -p MacJarvis/MacJarvisTests
```

- [ ] **Step 2: Create Swift Package with Xcode project**

Use `xcodegen` or create manually. Since this is a macOS app, create the Xcode project using Swift Package Manager isn't ideal. Create via command line:

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/mac-jarvis/MacJarvis
```

Create `project.yml` for XcodeGen (install via `brew install xcodegen` if needed):

```yaml
name: MacJarvis
options:
  bundleIdPrefix: com.jarvis
  deploymentTarget:
    macOS: "14.0"
  xcodeVersion: "16.0"
settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    CODE_SIGN_IDENTITY: "-"
    PRODUCT_BUNDLE_IDENTIFIER: com.jarvis.MacJarvis
targets:
  MacJarvis:
    type: application
    platform: macOS
    sources:
      - path: MacJarvis
    resources:
      - path: MacJarvis/Resources
    settings:
      base:
        INFOPLIST_FILE: MacJarvis/Info.plist
        CODE_SIGN_ENTITLEMENTS: MacJarvis/MacJarvis.entitlements
        PRODUCT_NAME: MacJarvis
    entitlements:
      path: MacJarvis/MacJarvis.entitlements
      properties:
        com.apple.security.app-sandbox: false
  MacJarvisTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: MacJarvisTests
    dependencies:
      - target: MacJarvis
    settings:
      base:
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/MacJarvis.app/Contents/MacOS/MacJarvis"
        BUNDLE_LOADER: "$(TEST_HOST)"
```

- [ ] **Step 3: Create MacJarvisApp.swift**

```swift
import SwiftUI

@main
struct MacJarvisApp: App {
    @State private var displayManager = DisplayManager()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(displayManager)
                .frame(minWidth: 400, minHeight: 240)
                .onAppear {
                    displayManager.startMonitoring()
                }
        }
        .defaultSize(width: 800, height: 480)
    }
}
```

Note: 不设 `.windowStyle(.hiddenTitleBar)`，标题栏由 DisplayManager 在检测到外接屏时动态隐藏。

- [ ] **Step 4: Create entitlements file**

`MacJarvis/MacJarvis.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

- [ ] **Step 5: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSMicrophoneUsageDescription</key>
    <string>MacJarvis needs microphone access for voice commands via Push-to-Talk.</string>
    <key>ATSApplicationFontsPath</key>
    <string>Fonts</string>
</dict>
</plist>
```

- [ ] **Step 6: Create placeholder DashboardView**

`MacJarvis/Views/DashboardView.swift`:
```swift
import SwiftUI

struct DashboardView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("MACJARVIS")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
        }
    }
}
```

- [ ] **Step 7: Build and verify app launches**

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/mac-jarvis/MacJarvis
xcodegen generate
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build
```

Expected: Build succeeds, app shows black window with cyan "MACJARVIS" text.

- [ ] **Step 8: Initialize git and commit**

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/mac-jarvis
git init
cat > .gitignore << 'EOF'
.DS_Store
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
DerivedData/
build/
*.swp
*.swo
EOF
git add .
git commit -m "feat: initialize MacJarvis Xcode project skeleton"
```

---

## Task 2: Cyberpunk Theme System

**Files:**
- Create: `MacJarvis/Theme/CyberTheme.swift`
- Create: `MacJarvis/Theme/CRTEffect.swift`
- Download: `MacJarvis/Resources/Fonts/PressStart2P-Regular.ttf`

- [ ] **Step 1: Download Press Start 2P font**

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/mac-jarvis/MacJarvis/MacJarvis/Resources/Fonts
curl -L -o PressStart2P-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/pressstart2p/PressStart2P-Regular.ttf"
curl -L -o OFL.txt "https://github.com/google/fonts/raw/main/ofl/pressstart2p/OFL.txt"
```

- [ ] **Step 2: Create CyberTheme.swift**

```swift
import SwiftUI

enum CyberTheme {
    // MARK: - Colors
    static let background = Color.black
    static let cyan = Color(hex: 0x00FFFF)
    static let magenta = Color(hex: 0xFF00FF)
    static let green = Color(hex: 0x00FF41)
    static let red = Color(hex: 0xFF0040)
    static let dimGray = Color(hex: 0x1A1A2E)
    static let cardBackground = Color(hex: 0x0D0D1A)
    static let cardBorder = Color(hex: 0x00FFFF).opacity(0.3)

    // MARK: - Fonts
    static let pixelFontName = "PressStart2P-Regular"

    static func pixelFont(size: CGFloat) -> Font {
        .custom(pixelFontName, size: size)
    }

    // Fallback if custom font not loaded
    static func monoFont(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }

    // MARK: - Spacing
    static let cardPadding: CGFloat = 12
    static let cardCornerRadius: CGFloat = 4
    static let cardSpacing: CGFloat = 8
}

// MARK: - Color Hex Init
extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Glow Modifier
struct NeonGlow: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.8), radius: radius)
            .shadow(color: color.opacity(0.4), radius: radius * 2)
    }
}

extension View {
    func neonGlow(_ color: Color = CyberTheme.cyan, radius: CGFloat = 4) -> some View {
        modifier(NeonGlow(color: color, radius: radius))
    }
}

// MARK: - Pixel Card Style
struct PixelCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(CyberTheme.cardPadding)
            .background(CyberTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: CyberTheme.cardCornerRadius)
                    .stroke(CyberTheme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CyberTheme.cardCornerRadius))
    }
}

extension View {
    func pixelCard() -> some View {
        modifier(PixelCard())
    }
}
```

- [ ] **Step 3: Create CRTEffect.swift**

```swift
import SwiftUI

struct CRTEffect: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(
            CRTScanlines()
                .allowsHitTesting(false)
        )
    }
}

struct CRTScanlines: View {
    var body: some View {
        Canvas { context, size in
            // Draw horizontal scanlines every 3 pixels
            let lineSpacing: CGFloat = 3
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.black.opacity(0.15)))
                y += lineSpacing
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    func crtEffect() -> some View {
        modifier(CRTEffect())
    }
}
```

- [ ] **Step 4: Update DashboardView to use theme**

```swift
import SwiftUI

struct DashboardView: View {
    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            VStack(spacing: CyberTheme.cardSpacing) {
                // Status cards row
                HStack(spacing: CyberTheme.cardSpacing) {
                    Text("TOKEN USAGE")
                        .font(CyberTheme.pixelFont(size: 8))
                        .foregroundColor(CyberTheme.cyan)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .pixelCard()

                    Text("OPENCLAW")
                        .font(CyberTheme.pixelFont(size: 8))
                        .foregroundColor(CyberTheme.green)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .pixelCard()

                    Text("CLOCK")
                        .font(CyberTheme.pixelFont(size: 8))
                        .foregroundColor(CyberTheme.magenta)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .pixelCard()
                }
                .frame(height: 150)

                // Chat area placeholder
                Text("CHAT AREA")
                    .font(CyberTheme.pixelFont(size: 8))
                    .foregroundColor(CyberTheme.cyan.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .pixelCard()
            }
            .padding(CyberTheme.cardSpacing)
        }
        .crtEffect()
    }
}
```

- [ ] **Step 5: Build and verify theme renders**

```bash
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build
```

Expected: Black background, three pixel-font cards in top row, chat placeholder below, CRT scanlines visible.

- [ ] **Step 6: Commit**

```bash
git add .
git commit -m "feat: add cyberpunk theme system with pixel font, neon glow, CRT effect"
```

---

## Task 3: DisplayManager — Screen Detection

**Files:**
- Create: `MacJarvis/Services/DisplayManager.swift`
- Create: `MacJarvisTests/DisplayManagerTests.swift`
- Modify: `MacJarvis/MacJarvisApp.swift`

- [ ] **Step 1: Write DisplayManager tests**

`MacJarvisTests/DisplayManagerTests.swift`:
```swift
import XCTest
@testable import MacJarvis

final class DisplayManagerTests: XCTestCase {

    func testMatchesTargetResolution_exact() {
        XCTAssertTrue(DisplayManager.matchesTargetResolution(width: 800, height: 480))
    }

    func testMatchesTargetResolution_withinTolerance() {
        // +10%: 880x528
        XCTAssertTrue(DisplayManager.matchesTargetResolution(width: 860, height: 500))
    }

    func testMatchesTargetResolution_outsideTolerance() {
        // 1920x1080 should not match
        XCTAssertFalse(DisplayManager.matchesTargetResolution(width: 1920, height: 1080))
    }

    func testMatchesTargetResolution_lowerBound() {
        // -10%: 720x432
        XCTAssertTrue(DisplayManager.matchesTargetResolution(width: 730, height: 440))
    }

    func testMatchesTargetResolution_belowLowerBound() {
        XCTAssertFalse(DisplayManager.matchesTargetResolution(width: 600, height: 400))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: FAIL — `DisplayManager` type not found.

- [ ] **Step 3: Implement DisplayManager**

`MacJarvis/Services/DisplayManager.swift`:
```swift
import SwiftUI
import AppKit

@Observable
@MainActor
class DisplayManager {
    var isExternalScreenConnected: Bool = false
    var targetScreen: NSScreen?

    private var observer: NSObjectProtocol?

    // Target resolution
    static let targetWidth: CGFloat = 800
    static let targetHeight: CGFloat = 480
    static let tolerance: CGFloat = 0.10 // ±10%

    static func matchesTargetResolution(width: CGFloat, height: CGFloat) -> Bool {
        let wMin = targetWidth * (1 - tolerance)
        let wMax = targetWidth * (1 + tolerance)
        let hMin = targetHeight * (1 - tolerance)
        let hMax = targetHeight * (1 + tolerance)
        return width >= wMin && width <= wMax && height >= hMin && height <= hMax
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

            // Also check unscaled size (some USB displays report native resolution)
            if Self.matchesTargetResolution(width: pixelWidth, height: pixelHeight)
                || Self.matchesTargetResolution(width: deviceSize.width, height: deviceSize.height) {
                targetScreen = screen
                isExternalScreenConnected = true
                moveWindowToTarget()
                return
            }
        }
        // No matching screen found
        targetScreen = nil
        isExternalScreenConnected = false
    }

    func moveWindowToTarget() {
        guard let targetScreen else { return }
        guard let window = NSApplication.shared.windows.first else { return }

        // Use borderless + setFrame for 800x480 screen (more controllable than toggleFullScreen)
        window.styleMask = [.borderless]
        window.setFrame(targetScreen.frame, display: true)
        window.level = .normal
    }

    func restoreWindow() {
        guard let window = NSApplication.shared.windows.first else { return }
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setFrame(CGRect(x: 100, y: 100, width: 800, height: 480), display: true)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: All 5 `DisplayManagerTests` PASS.

- [ ] **Step 5: Update MacJarvisApp to integrate DisplayManager**

```swift
import SwiftUI

@main
struct MacJarvisApp: App {
    @State private var displayManager = DisplayManager()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(displayManager)
                .frame(minWidth: 400, minHeight: 240)
                .onAppear {
                    displayManager.startMonitoring()
                }
        }
        .defaultSize(width: 800, height: 480)
    }
}
```

- [ ] **Step 6: Build and verify**

```bash
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build
```

Expected: Build succeeds. App opens 800x480 window. (External screen auto-detection tested manually when hardware available.)

- [ ] **Step 7: Commit**

```bash
git add .
git commit -m "feat: add DisplayManager with 800x480 external screen detection"
```

---

## Task 4: Clock Card View

**Files:**
- Create: `MacJarvis/Views/ClockCardView.swift`
- Modify: `MacJarvis/Views/DashboardView.swift`

- [ ] **Step 1: Create ClockCardView**

```swift
import SwiftUI

struct ClockCardView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            Text(timeString)
                .font(CyberTheme.pixelFont(size: 20))
                .foregroundColor(CyberTheme.magenta)
                .neonGlow(CyberTheme.magenta)

            Text(dateString)
                .font(CyberTheme.pixelFont(size: 8))
                .foregroundColor(CyberTheme.magenta.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pixelCard()
        .onReceive(timer) { self.now = $0 }
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: now)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f.string(from: now)
    }
}
```

- [ ] **Step 2: Create ClawStatusCardView placeholder**

`MacJarvis/Views/ClawStatusCardView.swift`:
```swift
import SwiftUI

struct ClawStatusCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(CyberTheme.dimGray)
                    .frame(width: 8, height: 8)
                Text("OPENCLAW")
                    .font(CyberTheme.pixelFont(size: 8))
                    .foregroundColor(CyberTheme.green)
            }

            Text("-- OFFLINE --")
                .font(CyberTheme.pixelFont(size: 6))
                .foregroundColor(CyberTheme.red)

            Text("Sessions: --")
                .font(CyberTheme.pixelFont(size: 6))
                .foregroundColor(CyberTheme.green.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .pixelCard()
    }
}
```

- [ ] **Step 3: Create ChatPlaceholderView**

`MacJarvis/Views/ChatPlaceholderView.swift`:
```swift
import SwiftUI

struct ChatPlaceholderView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("VOICE CHAT")
                .font(CyberTheme.pixelFont(size: 10))
                .foregroundColor(CyberTheme.cyan.opacity(0.3))
            Text("COMING SOON")
                .font(CyberTheme.pixelFont(size: 6))
                .foregroundColor(CyberTheme.cyan.opacity(0.2))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pixelCard()
    }
}
```

- [ ] **Step 4: Update DashboardView with all cards**

```swift
import SwiftUI

struct DashboardView: View {
    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            VStack(spacing: CyberTheme.cardSpacing) {
                // Status cards row
                HStack(spacing: CyberTheme.cardSpacing) {
                    TokenCardView()
                    ClawStatusCardView()
                    ClockCardView()
                }
                .frame(height: 150)

                // Chat area
                ChatPlaceholderView()
            }
            .padding(CyberTheme.cardSpacing)
        }
        .crtEffect()
    }
}
```

Note: `TokenCardView` will be created in Task 5. For now, create a minimal placeholder to make it compile:

`MacJarvis/Views/TokenCardView.swift` (temporary):
```swift
import SwiftUI

struct TokenCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TOKENS")
                .font(CyberTheme.pixelFont(size: 8))
                .foregroundColor(CyberTheme.cyan)
            Text("Codex: --")
                .font(CyberTheme.pixelFont(size: 6))
                .foregroundColor(CyberTheme.cyan.opacity(0.5))
            Text("Claude: --")
                .font(CyberTheme.pixelFont(size: 6))
                .foregroundColor(CyberTheme.cyan.opacity(0.5))
            Text("Gemini: --")
                .font(CyberTheme.pixelFont(size: 6))
                .foregroundColor(CyberTheme.cyan.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .pixelCard()
    }
}
```

- [ ] **Step 5: Build and verify layout**

```bash
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build
```

Expected: Three cards in top row (Token placeholder, OpenClaw offline, Clock with live time), chat placeholder below. CRT scanlines. Cyberpunk colors.

- [ ] **Step 6: Commit (M1 complete)**

```bash
git add .
git commit -m "feat: complete M1 - dashboard skeleton with cyberpunk theme and all card placeholders"
```

---

## Task 5: ToolUsage Model + SQLite Reader

**Files:**
- Create: `MacJarvis/Models/ToolUsage.swift`
- Create: `MacJarvisTests/TokenServiceTests.swift`
- Create: `MacJarvis/Services/TokenService.swift`

- [ ] **Step 1: Create ToolUsage model**

`MacJarvis/Models/ToolUsage.swift`:
```swift
import Foundation

struct ToolUsage: Identifiable {
    let id: String
    var name: String
    var inputTokens: Int?
    var outputTokens: Int?
    var totalTokens: Int?
    var cost: Double?
    var sessionCount: Int?
    var lastUpdated: Date?

    var formattedTokens: String {
        guard let tokens = totalTokens else { return "--" }
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.1fK", Double(tokens) / 1_000)
        }
        return "\(tokens)"
    }
}
```

- [ ] **Step 2: Create ClawStatus model**

`MacJarvis/Models/ClawStatus.swift`:
```swift
import Foundation

enum ClawStatus {
    case running
    case stopped
    case error
    case unknown
}
```

- [ ] **Step 3: Write TokenService tests**

`MacJarvisTests/TokenServiceTests.swift`:
```swift
import XCTest
import SQLite3
@testable import MacJarvis

final class TokenServiceTests: XCTestCase {

    var testDbPath: String!

    override func setUp() {
        super.setUp()
        // Create a temp SQLite DB mimicking Codex structure
        testDbPath = NSTemporaryDirectory() + "test_codex_\(UUID().uuidString).sqlite"
        createTestDatabase()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: testDbPath)
        super.tearDown()
    }

    private func createTestDatabase() {
        var db: OpaquePointer?
        guard sqlite3_open(testDbPath, &db) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }

        let createSQL = """
        CREATE TABLE threads (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            tokens_used INTEGER NOT NULL DEFAULT 0,
            model_provider TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
        """
        sqlite3_exec(db, createSQL, nil, nil, nil)

        // Insert test data: 3 threads, today
        let now = Int(Date().timeIntervalSince1970)
        let inserts = [
            "INSERT INTO threads VALUES ('t1', 'Test 1', 50000, 'openai', \(now), \(now));",
            "INSERT INTO threads VALUES ('t2', 'Test 2', 30000, 'openai', \(now), \(now));",
            "INSERT INTO threads VALUES ('t3', 'Test 3', 20000, 'openai', \(now), \(now));"
        ]
        for sql in inserts {
            sqlite3_exec(db, sql, nil, nil, nil)
        }
    }

    func testFetchCodexUsage_returnsCorrectTotals() {
        let usage = TokenService.queryCodexDatabase(at: testDbPath)
        XCTAssertNotNil(usage)
        // queryCodexDatabase filters by "today" using SQLite's 'now'.
        // Test data uses current timestamp, so it should always match.
        XCTAssertEqual(usage?.totalTokens, 100000)
        XCTAssertEqual(usage?.sessionCount, 3)
    }

    func testFetchCodexUsage_invalidPath() {
        let usage = TokenService.queryCodexDatabase(at: "/nonexistent/path.sqlite")
        XCTAssertNil(usage)
    }

    func testFormattedTokens_thousands() {
        let usage = ToolUsage(id: "test", name: "Test", totalTokens: 50000)
        XCTAssertEqual(usage.formattedTokens, "50.0K")
    }

    func testFormattedTokens_millions() {
        let usage = ToolUsage(id: "test", name: "Test", totalTokens: 1_500_000)
        XCTAssertEqual(usage.formattedTokens, "1.5M")
    }

    func testFormattedTokens_nil() {
        let usage = ToolUsage(id: "test", name: "Test", totalTokens: nil)
        XCTAssertEqual(usage.formattedTokens, "--")
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

```bash
xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: FAIL — `TokenService` and `queryCodexDatabase` not found.

- [ ] **Step 5: Implement TokenService**

`MacJarvis/Services/TokenService.swift`:
```swift
import Foundation
import SQLite3

@Observable
@MainActor
class TokenService {
    var tools: [ToolUsage] = [
        ToolUsage(id: "codex", name: "Codex"),
        ToolUsage(id: "claude", name: "Claude"),
        ToolUsage(id: "gemini", name: "Gemini"),
    ]

    private var refreshTimer: Timer?
    private let codexDbPath: String

    init(codexDbPath: String? = nil) {
        self.codexDbPath = codexDbPath
            ?? (NSHomeDirectory() + "/.codex/state_5.sqlite")
    }

    func startAutoRefresh() {
        fetchAll()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchAll()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func fetchAll() {
        let path = codexDbPath
        Task.detached {
            let usage = Self.queryCodexDatabase(at: path)
            await MainActor.run { [weak self] in
                guard let self, let usage else { return }
                if let idx = self.tools.firstIndex(where: { $0.id == "codex" }) {
                    self.tools[idx].totalTokens = usage.totalTokens
                    self.tools[idx].sessionCount = usage.sessionCount
                    self.tools[idx].lastUpdated = Date()
                }
            }
        }
    }

    // static for safe background execution (no self capture needed)
    static func queryCodexDatabase(at path: String) -> (totalTokens: Int, sessionCount: Int)? {
        var db: OpaquePointer?
        // Open read-only
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT COALESCE(SUM(tokens_used), 0), COUNT(*)
        FROM threads
        WHERE created_at >= strftime('%s', 'now', 'start of day');
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        let totalTokens = Int(sqlite3_column_int64(stmt, 0))
        let sessionCount = Int(sqlite3_column_int64(stmt, 1))
        return (totalTokens, sessionCount)
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: All `TokenServiceTests` PASS.

- [ ] **Step 7: Commit**

```bash
git add .
git commit -m "feat: add TokenService with Codex SQLite reader and ToolUsage model"
```

---

## Task 6: Token Card UI with Live Data

**Files:**
- Modify: `MacJarvis/Views/TokenCardView.swift`
- Modify: `MacJarvis/Views/DashboardView.swift`
- Modify: `MacJarvis/MacJarvisApp.swift`

- [ ] **Step 1: Create pixel progress bar component**

Add to `MacJarvis/Theme/CyberTheme.swift`:
```swift
// MARK: - Pixel Progress Bar
struct PixelProgressBar: View {
    let value: Double // 0.0 - 1.0
    let color: Color
    let totalBlocks: Int

    init(value: Double, color: Color = CyberTheme.cyan, totalBlocks: Int = 10) {
        self.value = min(max(value, 0), 1)
        self.color = color
        self.totalBlocks = totalBlocks
    }

    var body: some View {
        HStack(spacing: 2) {
            let filledBlocks = Int(value * Double(totalBlocks))
            ForEach(0..<totalBlocks, id: \.self) { i in
                Rectangle()
                    .fill(i < filledBlocks ? color : color.opacity(0.15))
                    .frame(width: 8, height: 10)
            }
        }
    }
}
```

- [ ] **Step 2: Update TokenCardView with live data**

> **Important:** Step 2 and Step 3 must be done together — TokenCardView uses `@Environment(TokenService.self)` which requires MacJarvisApp to inject it. Neither compiles alone.

`MacJarvis/Views/TokenCardView.swift`:
```swift
import SwiftUI

struct TokenCardView: View {
    @Environment(TokenService.self) private var tokenService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TOKENS")
                .font(CyberTheme.pixelFont(size: 8))
                .foregroundColor(CyberTheme.cyan)
                .neonGlow(CyberTheme.cyan, radius: 2)

            ForEach(tokenService.tools) { tool in
                HStack(spacing: 6) {
                    Text(tool.name.uppercased())
                        .font(CyberTheme.pixelFont(size: 6))
                        .foregroundColor(CyberTheme.cyan.opacity(0.7))
                        .frame(width: 50, alignment: .leading)

                    Text(tool.formattedTokens)
                        .font(CyberTheme.pixelFont(size: 6))
                        .foregroundColor(tool.totalTokens != nil ? CyberTheme.cyan : CyberTheme.dimGray)

                    if let sessions = tool.sessionCount {
                        Text("(\(sessions)s)")
                            .font(CyberTheme.pixelFont(size: 5))
                            .foregroundColor(CyberTheme.cyan.opacity(0.4))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .pixelCard()
    }
}
```

- [ ] **Step 3: Update MacJarvisApp to inject TokenService**

```swift
import SwiftUI

@main
struct MacJarvisApp: App {
    @State private var displayManager = DisplayManager()
    @State private var tokenService = TokenService()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(displayManager)
                .environment(tokenService)
                .frame(minWidth: 400, minHeight: 240)
                .onAppear {
                    displayManager.startMonitoring()
                    tokenService.startAutoRefresh()
                }
        }
        .defaultSize(width: 800, height: 480)
    }
}
```

- [ ] **Step 4: Build and verify token data displays**

```bash
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build
```

Expected: Build succeeds. Token card shows "Codex: XXK (Ns)" with real data from `~/.codex/state_5.sqlite`. Claude and Gemini show "--".

- [ ] **Step 5: Run all tests**

```bash
xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: All tests pass.

- [ ] **Step 6: Commit (M2 complete)**

```bash
git add .
git commit -m "feat: complete M2 - token dashboard with live Codex data and pixel progress UI"
```

---

## Summary

| Task | Milestone | What it delivers |
|------|-----------|------------------|
| 1 | M1 | Xcode project, builds and runs |
| 2 | M1 | Cyberpunk theme: pixel font, neon glow, CRT scanlines |
| 3 | M1 | DisplayManager with 800×480 screen detection |
| 4 | M1 | Dashboard layout with Clock, OpenClaw placeholder, Chat placeholder |
| 5 | M2 | TokenService + SQLite reader + ToolUsage model |
| 6 | M2 | Token card UI with live Codex data, auto-refresh |

After M2, next plan covers M3 (OpenClaw status) and M4 (voice + chat).
