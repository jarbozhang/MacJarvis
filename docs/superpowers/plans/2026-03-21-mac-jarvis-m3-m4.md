# MacJarvis M3-M4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add OpenClaw status monitoring with configurable host, and voice interaction (WhisperKit PTT + chat UI) to MacJarvis dashboard.

**Architecture:** OpenClawService connects via WebSocket (`URLSessionWebSocketTask`) with configurable host (local or remote). SettingsService persists user preferences via UserDefaults. VoiceService uses WhisperKit for local STT and AVAudioEngine for recording. Chat UI replaces the placeholder. All Services are `@Observable @MainActor`, heavy work via `Task.detached` or `nonisolated` methods.

**Tech Stack:** SwiftUI, URLSessionWebSocketTask, WhisperKit (SPM), AVAudioEngine, AVSpeechSynthesizer, UserDefaults

**Spec:** `docs/superpowers/specs/2026-03-21-mac-jarvis-design.md` sections 5.2, 5.3, 6, 7

**Prerequisite:** M1-M2 complete (plan: `docs/superpowers/plans/2026-03-21-mac-jarvis-m1-m2.md`)

---

## File Structure

```
MacJarvis/MacJarvis/
├── Services/
│   ├── OpenClawService.swift      -- NEW: WebSocket connection, health check, message send/receive
│   ├── SettingsService.swift      -- NEW: Persists openClawHost via UserDefaults
│   ├── DisplayManager.swift       -- existing, no changes
│   └── TokenService.swift         -- existing, no changes
├── Models/
│   ├── ClawStatus.swift           -- MODIFY: add Equatable, description helpers
│   ├── ChatMessage.swift          -- NEW: chat message model (role, content, timestamp)
│   └── ToolUsage.swift            -- existing, no changes
├── Views/
│   ├── DashboardView.swift        -- MODIFY: inject OpenClawService, replace ChatPlaceholderView
│   ├── ClawStatusCardView.swift   -- MODIFY: read from OpenClawService via @Environment
│   ├── ChatView.swift             -- NEW: replaces ChatPlaceholderView, message list + PTT button
│   ├── PTTButton.swift            -- NEW: push-to-talk button with recording state animation
│   ├── SettingsView.swift         -- NEW: OpenClaw host configuration UI
│   ├── TokenCardView.swift        -- existing, no changes
│   ├── ClockCardView.swift        -- existing, no changes
│   └── ChatPlaceholderView.swift  -- DELETE after ChatView is ready
├── MacJarvisApp.swift             -- MODIFY: inject OpenClawService + SettingsService
└── Info.plist                     -- existing (already has NSMicrophoneUsageDescription)

MacJarvis/MacJarvisTests/
├── OpenClawServiceTests.swift     -- NEW: connection logic, reconnect, message parsing
├── SettingsServiceTests.swift     -- NEW: UserDefaults read/write
├── ChatMessageTests.swift         -- NEW: model tests
├── DisplayManagerTests.swift      -- existing
└── TokenServiceTests.swift        -- existing

MacJarvis/project.yml             -- MODIFY: add WhisperKit SPM dependency (Task 7)
```

**Note on VoiceService:** M4 adds WhisperKit + recording. Since WhisperKit is a new SPM dependency, `project.yml` must be updated and the Xcode project regenerated.

---

## Task 1: SettingsService — Configurable OpenClaw Host

**Files:**
- Create: `MacJarvis/MacJarvis/Services/SettingsService.swift`
- Create: `MacJarvisTests/SettingsServiceTests.swift`
- Modify: `MacJarvis/MacJarvis/MacJarvisApp.swift`

- [ ] **Step 1: Write SettingsService tests**

`MacJarvisTests/SettingsServiceTests.swift`:
```swift
import XCTest
@testable import MacJarvis

final class SettingsServiceTests: XCTestCase {

    @MainActor
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "openClawHost")
        UserDefaults.standard.removeObject(forKey: "openClawPort")
    }

    @MainActor
    func testDefaultHost() {
        let settings = SettingsService()
        XCTAssertEqual(settings.openClawHost, "127.0.0.1")
    }

    @MainActor
    func testDefaultPort() {
        let settings = SettingsService()
        XCTAssertEqual(settings.openClawPort, 18789)
    }

    @MainActor
    func testWebSocketURL_default() {
        let settings = SettingsService()
        XCTAssertEqual(settings.openClawWebSocketURL.absoluteString, "ws://127.0.0.1:18789")
    }

    @MainActor
    func testWebSocketURL_customHost() {
        UserDefaults.standard.set("100.67.1.75", forKey: "openClawHost")
        let settings = SettingsService()
        XCTAssertEqual(settings.openClawWebSocketURL.absoluteString, "ws://100.67.1.75:18789")
    }

    @MainActor
    func testPersistence() {
        let settings = SettingsService()
        settings.openClawHost = "192.168.1.100"
        settings.openClawPort = 9999

        let settings2 = SettingsService()
        XCTAssertEqual(settings2.openClawHost, "192.168.1.100")
        XCTAssertEqual(settings2.openClawPort, 9999)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/mac-jarvis/MacJarvis
xcodegen generate && xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: FAIL — `SettingsService` not found.

- [ ] **Step 3: Implement SettingsService**

`MacJarvis/MacJarvis/Services/SettingsService.swift`:
```swift
import Foundation

@Observable
@MainActor
class SettingsService {
    var openClawHost: String {
        didSet { UserDefaults.standard.set(openClawHost, forKey: "openClawHost") }
    }

    var openClawPort: Int {
        didSet { UserDefaults.standard.set(openClawPort, forKey: "openClawPort") }
    }

    var openClawWebSocketURL: URL {
        URL(string: "ws://\(openClawHost):\(openClawPort)")!
    }

    init() {
        self.openClawHost = UserDefaults.standard.string(forKey: "openClawHost") ?? "127.0.0.1"
        let storedPort = UserDefaults.standard.integer(forKey: "openClawPort")
        self.openClawPort = storedPort > 0 ? storedPort : 18789
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate && xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: All `SettingsServiceTests` PASS.

- [ ] **Step 5: Inject SettingsService into MacJarvisApp**

Update `MacJarvis/MacJarvis/MacJarvisApp.swift`:
```swift
import SwiftUI

@main
struct MacJarvisApp: App {
    @State private var displayManager = DisplayManager()
    @State private var tokenService = TokenService()
    @State private var settingsService = SettingsService()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(displayManager)
                .environment(tokenService)
                .environment(settingsService)
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

- [ ] **Step 6: Build and verify**

```bash
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add MacJarvis/MacJarvis/Services/SettingsService.swift MacJarvisTests/SettingsServiceTests.swift MacJarvis/MacJarvis/MacJarvisApp.swift
git commit -m "feat: add SettingsService with configurable OpenClaw host/port"
```

---

## Task 2: ChatMessage Model

**Files:**
- Create: `MacJarvis/MacJarvis/Models/ChatMessage.swift`
- Create: `MacJarvisTests/ChatMessageTests.swift`
- Modify: `MacJarvis/MacJarvis/Models/ClawStatus.swift`

- [ ] **Step 1: Write ChatMessage tests**

`MacJarvisTests/ChatMessageTests.swift`:
```swift
import XCTest
@testable import MacJarvis

final class ChatMessageTests: XCTestCase {

    func testUserMessage() {
        let msg = ChatMessage(role: .user, content: "Hello")
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content, "Hello")
        XCTAssertNotNil(msg.id)
    }

    func testAssistantMessage() {
        let msg = ChatMessage(role: .assistant, content: "Hi there")
        XCTAssertEqual(msg.role, .assistant)
    }

    func testClawStatusEquatable() {
        XCTAssertEqual(ClawStatus.running, ClawStatus.running)
        XCTAssertNotEqual(ClawStatus.running, ClawStatus.stopped)
    }

    func testClawStatusLabel() {
        XCTAssertEqual(ClawStatus.running.label, "ONLINE")
        XCTAssertEqual(ClawStatus.stopped.label, "OFFLINE")
        XCTAssertEqual(ClawStatus.error.label, "ERROR")
        XCTAssertEqual(ClawStatus.unknown.label, "UNKNOWN")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate && xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: FAIL — `ChatMessage` not found, `ClawStatus` missing `label`.

- [ ] **Step 3: Create ChatMessage model**

`MacJarvis/MacJarvis/Models/ChatMessage.swift`:
```swift
import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date

    enum Role: String, Equatable {
        case user
        case assistant
    }

    init(role: Role, content: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
```

- [ ] **Step 4: Update ClawStatus with Equatable and label**

Replace `MacJarvis/MacJarvis/Models/ClawStatus.swift`:
```swift
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
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: All `ChatMessageTests` PASS.

- [ ] **Step 6: Commit**

```bash
git add MacJarvis/MacJarvis/Models/ChatMessage.swift MacJarvis/MacJarvis/Models/ClawStatus.swift MacJarvisTests/ChatMessageTests.swift
git commit -m "feat: add ChatMessage model and enhance ClawStatus with labels"
```

---

## Task 3: OpenClawService — WebSocket Connection + Health Check

**Files:**
- Create: `MacJarvis/MacJarvis/Services/OpenClawService.swift`
- Create: `MacJarvisTests/OpenClawServiceTests.swift`
- Modify: `MacJarvis/MacJarvis/MacJarvisApp.swift`

- [ ] **Step 1: Write OpenClawService tests**

`MacJarvisTests/OpenClawServiceTests.swift`:
```swift
import XCTest
@testable import MacJarvis

final class OpenClawServiceTests: XCTestCase {

    @MainActor
    func testInitialStatus() {
        let service = OpenClawService()
        XCTAssertEqual(service.status, .unknown)
        XCTAssertTrue(service.messages.isEmpty)
    }

    @MainActor
    func testConnectToInvalidHost_setsStoppedStatus() async {
        let service = OpenClawService()
        // Connect to an unreachable host — should transition to .stopped
        await service.connect(to: URL(string: "ws://127.0.0.1:1")!)

        // Give URLSession time to fail
        try? await Task.sleep(for: .seconds(2))

        XCTAssertEqual(service.status, .stopped)
    }

    @MainActor
    func testAddUserMessage() {
        let service = OpenClawService()
        service.addUserMessage("Hello")
        XCTAssertEqual(service.messages.count, 1)
        XCTAssertEqual(service.messages.first?.role, .user)
        XCTAssertEqual(service.messages.first?.content, "Hello")
    }

    @MainActor
    func testReconnectCounterResets() {
        let service = OpenClawService()
        XCTAssertEqual(service.reconnectAttempts, 0)
        service.reconnectAttempts = 3
        service.resetReconnect()
        XCTAssertEqual(service.reconnectAttempts, 0)
    }

    func testReconnectDelays() {
        XCTAssertEqual(OpenClawService.reconnectDelay(attempt: 0), 1.0)
        XCTAssertEqual(OpenClawService.reconnectDelay(attempt: 1), 3.0)
        XCTAssertEqual(OpenClawService.reconnectDelay(attempt: 2), 10.0)
        XCTAssertEqual(OpenClawService.reconnectDelay(attempt: 3), 10.0) // capped
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate && xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: FAIL — `OpenClawService` not found.

- [ ] **Step 3: Implement OpenClawService**

`MacJarvis/MacJarvis/Services/OpenClawService.swift`:
```swift
import Foundation

@Observable
@MainActor
class OpenClawService {
    var status: ClawStatus = .unknown
    var messages: [ChatMessage] = []
    var reconnectAttempts: Int = 0

    private var webSocketTask: URLSessionWebSocketTask?
    private var heartbeatTimer: Timer?
    private var currentURL: URL?

    static let maxReconnectAttempts = 3

    nonisolated static func reconnectDelay(attempt: Int) -> TimeInterval {
        let delays: [TimeInterval] = [1.0, 3.0, 10.0]
        return delays[min(attempt, delays.count - 1)]
    }

    func connect(to url: URL) async {
        currentURL = url
        reconnectAttempts = 0
        await establishConnection(to: url)
    }

    func disconnect() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        status = .stopped
    }

    func sendMessage(_ text: String) {
        addUserMessage(text)

        guard let webSocketTask, status == .running else { return }

        let payload: [String: Any] = [
            "type": "chat",
            "content": text
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        webSocketTask.send(.string(jsonString)) { [weak self] error in
            if let error {
                Task { @MainActor in
                    self?.handleError(error)
                }
            }
        }
    }

    func addUserMessage(_ text: String) {
        messages.append(ChatMessage(role: .user, content: text))
    }

    func resetReconnect() {
        reconnectAttempts = 0
    }

    // MARK: - Private

    private func establishConnection(to url: URL) async {
        webSocketTask?.cancel(with: .goingAway, reason: nil)

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        // Start listening
        listenForMessages()
        startHeartbeat()

        // Send initial ping to verify connection
        do {
            try await task.sendPing()
            status = .running
            reconnectAttempts = 0
        } catch {
            status = .stopped
            attemptReconnect()
        }
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.handleWebSocketMessage(message)
                    self.listenForMessages() // continue listening
                case .failure(let error):
                    self.handleError(error)
                }
            }
        }
    }

    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseIncomingMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseIncomingMessage(text)
            }
        @unknown default:
            break
        }
    }

    private func parseIncomingMessage(_ text: String) {
        // Try JSON parse; fallback to plain text
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let content = json["content"] as? String {
            messages.append(ChatMessage(role: .assistant, content: content))
        } else {
            messages.append(ChatMessage(role: .assistant, content: text))
        }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let task = self.webSocketTask else { return }
                do {
                    try await task.sendPing()
                } catch {
                    self.handleError(error)
                }
            }
        }
    }

    private func handleError(_ error: Error) {
        status = .stopped
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        attemptReconnect()
    }

    private func attemptReconnect() {
        guard reconnectAttempts < Self.maxReconnectAttempts,
              let url = currentURL else {
            status = .stopped
            return
        }

        let attempt = reconnectAttempts
        reconnectAttempts += 1
        let delay = Self.reconnectDelay(attempt: attempt)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard self.status != .running else { return }
            await self.establishConnection(to: url)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: All `OpenClawServiceTests` PASS.

- [ ] **Step 5: Inject OpenClawService into MacJarvisApp**

Update `MacJarvis/MacJarvis/MacJarvisApp.swift`:
```swift
import SwiftUI

@main
struct MacJarvisApp: App {
    @State private var displayManager = DisplayManager()
    @State private var tokenService = TokenService()
    @State private var settingsService = SettingsService()
    @State private var openClawService = OpenClawService()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(displayManager)
                .environment(tokenService)
                .environment(settingsService)
                .environment(openClawService)
                .frame(minWidth: 400, minHeight: 240)
                .onAppear {
                    displayManager.startMonitoring()
                    tokenService.startAutoRefresh()
                    Task {
                        await openClawService.connect(to: settingsService.openClawWebSocketURL)
                    }
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

Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add MacJarvis/MacJarvis/Services/OpenClawService.swift MacJarvisTests/OpenClawServiceTests.swift MacJarvis/MacJarvis/MacJarvisApp.swift
git commit -m "feat: add OpenClawService with WebSocket connection, heartbeat, and auto-reconnect"
```

---

## Task 4: ClawStatusCardView — Live Status Display

**Files:**
- Modify: `MacJarvis/MacJarvis/Views/ClawStatusCardView.swift`
- Modify: `MacJarvis/MacJarvis/Views/DashboardView.swift`

- [ ] **Step 1: Update ClawStatusCardView to read from OpenClawService**

Replace `MacJarvis/MacJarvis/Views/ClawStatusCardView.swift`:
```swift
import SwiftUI

struct ClawStatusCardView: View {
    @Environment(OpenClawService.self) private var clawService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .neonGlow(statusColor, radius: 3)
                Text("OPENCLAW")
                    .font(CyberTheme.pixelFont(size: 8))
                    .foregroundColor(CyberTheme.green)
            }

            Text(clawService.status.label)
                .font(CyberTheme.pixelFont(size: 6))
                .foregroundColor(statusColor)

            Text("Msgs: \(clawService.messages.count)")
                .font(CyberTheme.pixelFont(size: 6))
                .foregroundColor(CyberTheme.green.opacity(0.5))

            if clawService.reconnectAttempts > 0 && !clawService.status.isConnected {
                Text("Retry: \(clawService.reconnectAttempts)/\(OpenClawService.maxReconnectAttempts)")
                    .font(CyberTheme.pixelFont(size: 5))
                    .foregroundColor(CyberTheme.red.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .pixelCard()
    }

    private var statusColor: Color {
        switch clawService.status {
        case .running: CyberTheme.green
        case .stopped: CyberTheme.red
        case .error: CyberTheme.red
        case .unknown: CyberTheme.dimGray
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build
```

Expected: BUILD SUCCEEDED. Card shows live OpenClaw connection status.

- [ ] **Step 3: Commit**

```bash
git add MacJarvis/MacJarvis/Views/ClawStatusCardView.swift
git commit -m "feat: update ClawStatusCardView with live OpenClaw status display"
```

---

## Task 5: SettingsView — OpenClaw Host Configuration UI

**Files:**
- Create: `MacJarvis/MacJarvis/Views/SettingsView.swift`
- Modify: `MacJarvis/MacJarvis/Views/DashboardView.swift`

- [ ] **Step 1: Create SettingsView**

`MacJarvis/MacJarvis/Views/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @Environment(SettingsService.self) private var settings
    @Environment(OpenClawService.self) private var clawService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 16) {
            Text("SETTINGS")
                .font(CyberTheme.pixelFont(size: 10))
                .foregroundColor(CyberTheme.cyan)
                .neonGlow(CyberTheme.cyan, radius: 2)

            VStack(alignment: .leading, spacing: 8) {
                Text("OPENCLAW HOST")
                    .font(CyberTheme.pixelFont(size: 6))
                    .foregroundColor(CyberTheme.cyan.opacity(0.7))

                HStack(spacing: 8) {
                    TextField("Host", text: $settings.openClawHost)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(CyberTheme.green)
                        .padding(6)
                        .background(CyberTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(CyberTheme.cardBorder, lineWidth: 1)
                        )

                    Text(":")
                        .foregroundColor(CyberTheme.cyan.opacity(0.5))

                    TextField("Port", value: $settings.openClawPort, format: .number)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(CyberTheme.green)
                        .padding(6)
                        .background(CyberTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(CyberTheme.cardBorder, lineWidth: 1)
                        )
                        .frame(width: 80)
                }

                HStack(spacing: 12) {
                    Button("RECONNECT") {
                        Task {
                            await clawService.connect(to: settings.openClawWebSocketURL)
                        }
                    }
                    .font(CyberTheme.pixelFont(size: 6))
                    .foregroundColor(CyberTheme.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(CyberTheme.green.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 2))

                    Button("CLOSE") {
                        dismiss()
                    }
                    .font(CyberTheme.pixelFont(size: 6))
                    .foregroundColor(CyberTheme.cyan.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }

                Text("Presets: 127.0.0.1 (local) / 100.67.1.75 (remote)")
                    .font(CyberTheme.pixelFont(size: 5))
                    .foregroundColor(CyberTheme.cyan.opacity(0.3))
            }
        }
        .padding(20)
        .frame(width: 400)
        .background(CyberTheme.background)
    }
}
```

- [ ] **Step 2: Add settings button to DashboardView**

Update `MacJarvis/MacJarvis/Views/DashboardView.swift`:
```swift
import SwiftUI

struct DashboardView: View {
    @State private var showSettings = false

    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            VStack(spacing: CyberTheme.cardSpacing) {
                HStack(spacing: CyberTheme.cardSpacing) {
                    TokenCardView()
                    ClawStatusCardView()
                    ClockCardView()
                }
                .frame(height: 150)

                ChatPlaceholderView()
            }
            .padding(CyberTheme.cardSpacing)

            // Settings gear button (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showSettings.toggle()
                    } label: {
                        Text("⚙")
                            .font(.system(size: 14))
                            .foregroundColor(CyberTheme.cyan.opacity(0.4))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSettings) {
                        SettingsView()
                    }
                }
                Spacer()
            }
            .padding(4)
        }
        .crtEffect()
    }
}
```

- [ ] **Step 3: Build and verify**

```bash
xcodegen generate && xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build
```

Expected: BUILD SUCCEEDED. Gear icon in top-right, click opens settings popover with host/port fields.

- [ ] **Step 4: Commit (M3 complete)**

```bash
git add MacJarvis/MacJarvis/Views/SettingsView.swift MacJarvis/MacJarvis/Views/DashboardView.swift
git commit -m "feat: complete M3 - OpenClaw status monitoring with configurable host settings"
```

---

## Task 6: ChatView — Message List + PTT Button Skeleton

**Files:**
- Create: `MacJarvis/MacJarvis/Views/ChatView.swift`
- Create: `MacJarvis/MacJarvis/Views/PTTButton.swift`
- Modify: `MacJarvis/MacJarvis/Views/DashboardView.swift`
- Delete: `MacJarvis/MacJarvis/Views/ChatPlaceholderView.swift`

- [ ] **Step 1: Create PTTButton**

`MacJarvis/MacJarvis/Views/PTTButton.swift`:
```swift
import SwiftUI

struct PTTButton: View {
    let isRecording: Bool
    let isTranscribing: Bool
    let isDisabled: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        let label: String = if isTranscribing {
            "TRANSCRIBING..."
        } else if isRecording {
            "LISTENING..."
        } else {
            "HOLD TO TALK"
        }

        let color: Color = if isRecording {
            CyberTheme.red
        } else if isTranscribing {
            CyberTheme.magenta
        } else {
            CyberTheme.cyan
        }

        Text(label)
            .font(CyberTheme.pixelFont(size: 8))
            .foregroundColor(isDisabled ? CyberTheme.dimGray : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                (isRecording ? CyberTheme.red : color).opacity(isDisabled ? 0.05 : 0.1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CyberTheme.cardCornerRadius)
                    .stroke(isDisabled ? CyberTheme.dimGray : color.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CyberTheme.cardCornerRadius))
            .neonGlow(isRecording ? CyberTheme.red : color, radius: isRecording ? 6 : 2)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isRecording && !isDisabled && !isTranscribing {
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        if isRecording {
                            onRelease()
                        }
                    }
            )
            .allowsHitTesting(!isDisabled && !isTranscribing)
    }
}
```

- [ ] **Step 2: Create ChatView**

`MacJarvis/MacJarvis/Views/ChatView.swift`:
```swift
import SwiftUI

struct ChatView: View {
    @Environment(OpenClawService.self) private var clawService

    // VoiceService will be added in Task 7; for now use local state
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var textInput = ""

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(clawService.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(CyberTheme.cardPadding)
                }
                .onChange(of: clawService.messages.count) {
                    if let last = clawService.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()
                .background(CyberTheme.cardBorder)

            // Input area
            VStack(spacing: 8) {
                // Text input fallback
                HStack(spacing: 8) {
                    TextField("Type message...", text: $textInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(CyberTheme.cyan)
                        .padding(6)
                        .background(CyberTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(CyberTheme.cardBorder, lineWidth: 1)
                        )
                        .onSubmit {
                            sendTextMessage()
                        }

                    Button("SEND") {
                        sendTextMessage()
                    }
                    .font(CyberTheme.pixelFont(size: 6))
                    .foregroundColor(CyberTheme.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(CyberTheme.cyan.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .disabled(textInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // PTT button (voice will be wired in Task 7)
                PTTButton(
                    isRecording: isRecording,
                    isTranscribing: isTranscribing,
                    isDisabled: !clawService.status.isConnected,
                    onPress: { /* wired in Task 7 */ },
                    onRelease: { /* wired in Task 7 */ }
                )
            }
            .padding(CyberTheme.cardPadding)
        }
        .background(CyberTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: CyberTheme.cardCornerRadius)
                .stroke(CyberTheme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: CyberTheme.cardCornerRadius))
    }

    private func sendTextMessage() {
        let text = textInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        clawService.sendMessage(text)
        textInput = ""
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                Text(message.role == .user ? "YOU" : "CLAW")
                    .font(CyberTheme.pixelFont(size: 5))
                    .foregroundColor(message.role == .user ? CyberTheme.cyan.opacity(0.5) : CyberTheme.green.opacity(0.5))

                Text(message.content)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(message.role == .user ? CyberTheme.cyan : CyberTheme.green)
                    .padding(8)
                    .background(
                        (message.role == .user ? CyberTheme.cyan : CyberTheme.green).opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}
```

- [ ] **Step 3: Replace ChatPlaceholderView in DashboardView**

Update `MacJarvis/MacJarvis/Views/DashboardView.swift` — change `ChatPlaceholderView()` to `ChatView()`:
```swift
import SwiftUI

struct DashboardView: View {
    @State private var showSettings = false

    var body: some View {
        ZStack {
            CyberTheme.background.ignoresSafeArea()

            VStack(spacing: CyberTheme.cardSpacing) {
                HStack(spacing: CyberTheme.cardSpacing) {
                    TokenCardView()
                    ClawStatusCardView()
                    ClockCardView()
                }
                .frame(height: 150)

                ChatView()
            }
            .padding(CyberTheme.cardSpacing)

            // Settings gear button (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showSettings.toggle()
                    } label: {
                        Text("⚙")
                            .font(.system(size: 14))
                            .foregroundColor(CyberTheme.cyan.opacity(0.4))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSettings) {
                        SettingsView()
                    }
                }
                Spacer()
            }
            .padding(4)
        }
        .crtEffect()
    }
}
```

- [ ] **Step 4: Delete ChatPlaceholderView**

```bash
rm MacJarvis/MacJarvis/Views/ChatPlaceholderView.swift
```

- [ ] **Step 5: Build and verify**

```bash
xcodegen generate && xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build
```

Expected: BUILD SUCCEEDED. Chat area shows message list, text input, and PTT button (PTT not yet functional for voice).

- [ ] **Step 6: Run all tests**

```bash
xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add MacJarvis/MacJarvis/Views/ChatView.swift MacJarvis/MacJarvis/Views/PTTButton.swift MacJarvis/MacJarvis/Views/DashboardView.swift
git rm MacJarvis/MacJarvis/Views/ChatPlaceholderView.swift
git commit -m "feat: add ChatView with message list, text input, and PTT button skeleton"
```

---

## Task 7: WhisperKit Integration + VoiceService

**Files:**
- Modify: `MacJarvis/project.yml` (add WhisperKit SPM)
- Create: `MacJarvis/MacJarvis/Services/VoiceService.swift`
- Create: `MacJarvisTests/VoiceServiceTests.swift`

- [ ] **Step 1: Add WhisperKit to project.yml**

Update `MacJarvis/project.yml` — add `packages` section and dependency:
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
packages:
  WhisperKit:
    url: https://github.com/argmaxinc/WhisperKit
    from: "0.9.0"
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
    dependencies:
      - sdk: libsqlite3.tbd
      - package: WhisperKit
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
        GENERATE_INFOPLIST_FILE: "YES"
```

- [ ] **Step 2: Regenerate Xcode project and resolve packages**

```bash
cd /Users/jiabozhang/Documents/Develop/vibecoding/mac-jarvis/MacJarvis
xcodegen generate
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -resolvePackageDependencies
```

Expected: Package resolution succeeds, WhisperKit downloaded.

- [ ] **Step 3: Write VoiceService tests**

`MacJarvisTests/VoiceServiceTests.swift`:
```swift
import XCTest
@testable import MacJarvis

final class VoiceServiceTests: XCTestCase {

    @MainActor
    func testInitialState() {
        let service = VoiceService()
        XCTAssertFalse(service.isRecording)
        XCTAssertFalse(service.isTranscribing)
        XCTAssertFalse(service.isSpeaking)
        XCTAssertEqual(service.transcript, "")
        XCTAssertFalse(service.isModelLoaded)
    }

    @MainActor
    func testModelStatus_notLoaded() {
        let service = VoiceService()
        XCTAssertEqual(service.modelStatusLabel, "MODEL NOT LOADED")
    }

    @MainActor
    func testCanRecord_requiresModel() {
        let service = VoiceService()
        XCTAssertFalse(service.canRecord)
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

```bash
xcodegen generate && xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: FAIL — `VoiceService` not found.

- [ ] **Step 5: Implement VoiceService**

`MacJarvis/MacJarvis/Services/VoiceService.swift`:
```swift
import Foundation
import AVFoundation
import WhisperKit

@Observable
@MainActor
class VoiceService {
    var isRecording: Bool = false
    var isTranscribing: Bool = false
    var isSpeaking: Bool = false
    var transcript: String = ""
    var isModelLoaded: Bool = false
    var modelLoadProgress: String = ""

    private var whisperKit: WhisperKit?
    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private let synthesizer = AVSpeechSynthesizer()

    var canRecord: Bool {
        isModelLoaded && !isTranscribing
    }

    var modelStatusLabel: String {
        if isModelLoaded { return "MODEL READY" }
        if !modelLoadProgress.isEmpty { return modelLoadProgress }
        return "MODEL NOT LOADED"
    }

    // MARK: - Model Loading

    func loadModel() {
        guard !isModelLoaded else { return }
        modelLoadProgress = "DOWNLOADING..."

        Task.detached {
            do {
                let kit = try await WhisperKit(model: "base")
                await MainActor.run {
                    self.whisperKit = kit
                    self.isModelLoaded = true
                    self.modelLoadProgress = ""
                }
            } catch {
                await MainActor.run {
                    self.modelLoadProgress = "LOAD FAILED"
                }
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard canRecord else { return }

        audioBuffer = []
        isRecording = true

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let channelData = buffer.floatChannelData?[0]
            let frameCount = Int(buffer.frameLength)
            if let channelData {
                let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
                Task { @MainActor in
                    self.audioBuffer.append(contentsOf: samples)
                }
            }
        }

        do {
            try engine.start()
            audioEngine = engine
        } catch {
            isRecording = false
        }
    }

    func stopAndTranscribe() async -> String? {
        guard isRecording else { return nil }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        isTranscribing = true

        guard let whisperKit, !audioBuffer.isEmpty else {
            isTranscribing = false
            return nil
        }

        let samples = audioBuffer
        audioBuffer = []

        // Run Whisper inference on background thread to avoid blocking UI
        let result: String? = await Task.detached {
            do {
                let results = try await whisperKit.transcribe(audioArray: samples)
                let text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                return text.isEmpty ? nil : text
            } catch {
                return nil
            }
        }.value

        transcript = result ?? ""
        isTranscribing = false
        return result
    }

    // MARK: - TTS

    func speak(_ text: String) {
        stopSpeaking()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        isSpeaking = true
        synthesizer.speak(utterance)

        // Monitor completion
        Task {
            // Simple polling since we don't use delegate
            while synthesizer.isSpeaking {
                try? await Task.sleep(for: .milliseconds(200))
            }
            isSpeaking = false
        }
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: All `VoiceServiceTests` PASS.

- [ ] **Step 7: Commit**

```bash
git add MacJarvis/project.yml MacJarvis/MacJarvis/Services/VoiceService.swift MacJarvisTests/VoiceServiceTests.swift
git commit -m "feat: add VoiceService with WhisperKit STT and AVSpeech TTS"
```

---

## Task 8: Wire Voice to ChatView + Inject VoiceService

**Files:**
- Modify: `MacJarvis/MacJarvis/MacJarvisApp.swift`
- Modify: `MacJarvis/MacJarvis/Views/ChatView.swift`
- Modify: `MacJarvis/MacJarvis/Views/DashboardView.swift`

- [ ] **Step 1: Inject VoiceService in MacJarvisApp**

Update `MacJarvis/MacJarvis/MacJarvisApp.swift`:
```swift
import SwiftUI

@main
struct MacJarvisApp: App {
    @State private var displayManager = DisplayManager()
    @State private var tokenService = TokenService()
    @State private var settingsService = SettingsService()
    @State private var openClawService = OpenClawService()
    @State private var voiceService = VoiceService()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(displayManager)
                .environment(tokenService)
                .environment(settingsService)
                .environment(openClawService)
                .environment(voiceService)
                .frame(minWidth: 400, minHeight: 240)
                .onAppear {
                    displayManager.startMonitoring()
                    tokenService.startAutoRefresh()
                    voiceService.loadModel()
                    Task {
                        await openClawService.connect(to: settingsService.openClawWebSocketURL)
                    }
                }
        }
        .defaultSize(width: 800, height: 480)
    }
}
```

- [ ] **Step 2: Wire VoiceService into ChatView**

Replace `MacJarvis/MacJarvis/Views/ChatView.swift` — wire PTT to VoiceService and add model status:
```swift
import SwiftUI

struct ChatView: View {
    @Environment(OpenClawService.self) private var clawService
    @Environment(VoiceService.self) private var voiceService

    @State private var textInput = ""

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(clawService.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(CyberTheme.cardPadding)
                }
                .onChange(of: clawService.messages.count) {
                    if let last = clawService.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()
                .background(CyberTheme.cardBorder)

            // Input area
            VStack(spacing: 8) {
                // Text input fallback
                HStack(spacing: 8) {
                    TextField("Type message...", text: $textInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(CyberTheme.cyan)
                        .padding(6)
                        .background(CyberTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(CyberTheme.cardBorder, lineWidth: 1)
                        )
                        .onSubmit {
                            sendTextMessage()
                        }

                    Button("SEND") {
                        sendTextMessage()
                    }
                    .font(CyberTheme.pixelFont(size: 6))
                    .foregroundColor(CyberTheme.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(CyberTheme.cyan.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .disabled(textInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // PTT button
                PTTButton(
                    isRecording: voiceService.isRecording,
                    isTranscribing: voiceService.isTranscribing,
                    isDisabled: !clawService.status.isConnected || !voiceService.canRecord,
                    onPress: {
                        voiceService.stopSpeaking() // interrupt TTS if speaking
                        voiceService.startRecording()
                    },
                    onRelease: {
                        Task {
                            if let text = await voiceService.stopAndTranscribe() {
                                clawService.sendMessage(text)
                            }
                        }
                    }
                )

                // Model status
                if !voiceService.isModelLoaded {
                    Text(voiceService.modelStatusLabel)
                        .font(CyberTheme.pixelFont(size: 5))
                        .foregroundColor(CyberTheme.magenta.opacity(0.5))
                }
            }
            .padding(CyberTheme.cardPadding)
        }
        .background(CyberTheme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: CyberTheme.cardCornerRadius)
                .stroke(CyberTheme.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: CyberTheme.cardCornerRadius))
    }

    private func sendTextMessage() {
        let text = textInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        clawService.sendMessage(text)
        textInput = ""
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                Text(message.role == .user ? "YOU" : "CLAW")
                    .font(CyberTheme.pixelFont(size: 5))
                    .foregroundColor(message.role == .user ? CyberTheme.cyan.opacity(0.5) : CyberTheme.green.opacity(0.5))

                Text(message.content)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(message.role == .user ? CyberTheme.cyan : CyberTheme.green)
                    .padding(8)
                    .background(
                        (message.role == .user ? CyberTheme.cyan : CyberTheme.green).opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}
```

- [ ] **Step 3: Build and verify**

```bash
xcodegen generate && xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build
```

Expected: BUILD SUCCEEDED. PTT button wired to VoiceService. Model auto-downloads on first launch.

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -project MacJarvis.xcodeproj -scheme MacJarvis -destination 'platform=macOS'
```

Expected: All tests PASS.

- [ ] **Step 5: Commit (M4 complete)**

```bash
git add MacJarvis/MacJarvis/MacJarvisApp.swift MacJarvis/MacJarvis/Views/ChatView.swift
git commit -m "feat: complete M4 - wire VoiceService PTT to ChatView with WhisperKit transcription"
```

---

## Summary

| Task | Milestone | What it delivers |
|------|-----------|------------------|
| 1 | M3 | SettingsService — configurable OpenClaw host/port via UserDefaults |
| 2 | M3 | ChatMessage model + ClawStatus enhancements |
| 3 | M3 | OpenClawService — WebSocket connection, heartbeat, auto-reconnect |
| 4 | M3 | ClawStatusCardView — live status from OpenClawService |
| 5 | M3 | SettingsView — host/port configuration UI with reconnect button |
| 6 | M4 | ChatView + PTTButton skeleton — message list, text input, PTT UI |
| 7 | M4 | VoiceService — WhisperKit STT + AVSpeech TTS + audio recording |
| 8 | M4 | Wire voice to chat — PTT → record → transcribe → send → display |

After M4, next plan covers M5 (TTS polish, CRT animations, error handling) and M6 (Claude/Gemini token collection).
