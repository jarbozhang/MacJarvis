# MacJarvis M5-M6 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add auto-TTS for OpenClaw responses, recording waveform animation, and Claude/Gemini token collection to MacJarvis dashboard.

**Architecture:** ChatView observes new assistant messages and auto-triggers VoiceService.speak(). PTTButton gains audio-level visualization via audioBuffer sampling. TokenService gains two new static query methods for Claude (JSON file read) and Gemini (directory scan of session logs), following the same `nonisolated static` + `Task.detached` pattern as existing Codex integration.

**Tech Stack:** SwiftUI, AVFoundation, Foundation (JSONDecoder/FileManager)

**Spec:** `docs/superpowers/specs/2026-03-21-mac-jarvis-design.md` sections M5, M6

**Prerequisite:** M1-M4 complete

---

## File Structure

```
MacJarvis/MacJarvis/
├── Services/
│   ├── TokenService.swift         -- MODIFY: add Claude + Gemini query methods, wire into fetchAll()
│   └── VoiceService.swift         -- MODIFY: add audioLevel property for waveform
├── Views/
│   ├── ChatView.swift             -- MODIFY: auto-TTS on new assistant messages
│   └── PTTButton.swift            -- MODIFY: add waveform bars animation
├── Models/
│   └── ToolUsage.swift            -- existing, already has needed fields
MacJarvisTests/
├── TokenServiceClaudeTests.swift  -- CREATE: test Claude JSON parsing
├── TokenServiceGeminiTests.swift  -- CREATE: test Gemini log scanning
```

---

### Task 1: Auto-TTS for Assistant Messages

Wire ChatView to auto-speak new assistant messages via VoiceService. TTS is already interruptible (PTT onPress calls stopSpeaking).

**Files:**
- Modify: `MacJarvis/MacJarvis/Views/ChatView.swift:22-28`

- [ ] **Step 1: Add auto-TTS in ChatView onChange handler**

In `ChatView.swift`, modify the existing `.onChange(of: clawService.messages.count)` block to also call `voiceService.speak()` when the latest message is from assistant:

```swift
.onChange(of: clawService.messages.count) {
    if let last = clawService.messages.last {
        withAnimation {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
        // Auto-TTS for assistant responses
        if last.role == .assistant {
            voiceService.speak(last.content)
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add MacJarvis/MacJarvis/Views/ChatView.swift
git commit -m "feat: auto-TTS for OpenClaw assistant responses"
```

---

### Task 2: Recording Waveform Animation

Add a real-time audio level property to VoiceService and display waveform bars in PTTButton during recording.

**Files:**
- Modify: `MacJarvis/MacJarvis/Services/VoiceService.swift:8-9` (add audioLevel property)
- Modify: `MacJarvis/MacJarvis/Services/VoiceService.swift:64-74` (update tap to compute RMS level)
- Modify: `MacJarvis/MacJarvis/Views/PTTButton.swift` (add waveform bars)
- Modify: `MacJarvis/MacJarvis/Views/ChatView.swift:65-80` (pass audioLevel to PTTButton)

- [ ] **Step 1: Add audioLevel property to VoiceService**

In `VoiceService.swift`, add after line 11 (`var transcript: String = ""`):

```swift
var audioLevel: Float = 0.0
```

- [ ] **Step 2: Update audio tap to compute RMS level**

In `VoiceService.swift`, replace the `inputNode.installTap` closure (lines 64-74) with:

```swift
inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
    guard let self else { return }
    let channelData = buffer.floatChannelData?[0]
    let frameCount = Int(buffer.frameLength)
    if let channelData {
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        // Compute RMS for waveform visualization
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(max(frameCount, 1)))
        let level = min(rms * 5.0, 1.0) // amplify and clamp to 0...1
        Task { @MainActor in
            self.audioBuffer.append(contentsOf: samples)
            self.audioLevel = level
        }
    }
}
```

Also reset audioLevel in `stopAndTranscribe()`, after `isRecording = false` (line 90):

```swift
audioLevel = 0.0
```

- [ ] **Step 3: Add waveform bars to PTTButton**

Replace PTTButton entirely with this version that adds waveform bars during recording:

```swift
import SwiftUI

struct PTTButton: View {
    let isRecording: Bool
    let isTranscribing: Bool
    let isDisabled: Bool
    let audioLevel: Float
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            // Waveform bars (visible only when recording)
            if isRecording {
                WaveformBars(level: audioLevel)
                    .frame(height: 20)
                    .transition(.opacity)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .neonGlow(statusColor, radius: isRecording ? 6 : 2)

                Text(statusLabel)
                    .font(CyberTheme.pixelFont(size: 6))
                    .foregroundColor(statusColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(statusColor.opacity(isDisabled ? 0.05 : 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(statusColor.opacity(0.5), lineWidth: 1)
            )
            .allowsHitTesting(!isDisabled && !isTranscribing)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isRecording && !isTranscribing {
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        if isRecording {
                            onRelease()
                        }
                    }
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }

    private var statusColor: Color {
        if isDisabled { return CyberTheme.dimGray }
        if isRecording { return CyberTheme.red }
        if isTranscribing { return CyberTheme.magenta }
        return CyberTheme.cyan
    }

    private var statusLabel: String {
        if isRecording { return "LISTENING..." }
        if isTranscribing { return "TRANSCRIBING..." }
        return "HOLD TO TALK"
    }
}

struct WaveformBars: View {
    let level: Float
    private let barCount = 12

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                let barHeight = barHeightFor(index: i)
                RoundedRectangle(cornerRadius: 1)
                    .fill(CyberTheme.red)
                    .frame(width: 4, height: barHeight)
                    .neonGlow(CyberTheme.red, radius: 2)
            }
        }
        .animation(.easeOut(duration: 0.1), value: level)
    }

    private func barHeightFor(index: Int) -> CGFloat {
        let center = Float(barCount) / 2.0
        let distance = abs(Float(index) - center) / center
        let base = CGFloat(level) * 18.0 * (1.0 - distance * 0.6)
        return max(base, 2)
    }
}
```

- [ ] **Step 4: Update ChatView to pass audioLevel**

In `ChatView.swift`, update the PTTButton initializer (lines 65-80) to include `audioLevel`:

```swift
PTTButton(
    isRecording: voiceService.isRecording,
    isTranscribing: voiceService.isTranscribing,
    isDisabled: !clawService.status.isConnected || !voiceService.canRecord,
    audioLevel: voiceService.audioLevel,
    onPress: {
        voiceService.stopSpeaking()
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
```

- [ ] **Step 5: Build and verify**

Run: `xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build 2>&1 | tail -3`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add MacJarvis/MacJarvis/Services/VoiceService.swift MacJarvis/MacJarvis/Views/PTTButton.swift MacJarvis/MacJarvis/Views/ChatView.swift
git commit -m "feat: add recording waveform animation to PTT button"
```

---

### Task 3: Claude Token Collection

Read `~/.claude/stats-cache.json` to get today's Claude token usage and session count, update the "claude" ToolUsage entry.

**Data source:** `~/.claude/stats-cache.json` — JSON with structure:
- `dailyActivity`: array of `{date, messageCount, sessionCount}` — date format "YYYY-MM-DD"
- `dailyModelTokens`: array of `{date, tokensByModel: {model: count}}` — sum all model tokens for the day

**Files:**
- Modify: `MacJarvis/MacJarvis/Services/TokenService.swift` (add Claude query method, wire into fetchAll)
- Create: `MacJarvisTests/TokenServiceClaudeTests.swift`

- [ ] **Step 1: Write failing tests for Claude parsing**

Create `MacJarvisTests/TokenServiceClaudeTests.swift`:

```swift
import XCTest
@testable import MacJarvis

@MainActor
final class TokenServiceClaudeTests: XCTestCase {

    func testParseClaudeStats_todayData() {
        let today = Self.todayString()
        let json = """
        {
          "version": 2,
          "dailyActivity": [
            {"date": "\(today)", "messageCount": 100, "sessionCount": 3}
          ],
          "dailyModelTokens": [
            {"date": "\(today)", "tokensByModel": {"claude-opus-4-6": 5000, "claude-sonnet-4-5": 2000}}
          ]
        }
        """.data(using: .utf8)!

        let result = TokenService.parseClaudeStats(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalTokens, 7000)
        XCTAssertEqual(result?.sessionCount, 3)
    }

    func testParseClaudeStats_noTodayData() {
        let json = """
        {
          "version": 2,
          "dailyActivity": [
            {"date": "2025-01-01", "messageCount": 50, "sessionCount": 2}
          ],
          "dailyModelTokens": [
            {"date": "2025-01-01", "tokensByModel": {"claude-opus-4-6": 3000}}
          ]
        }
        """.data(using: .utf8)!

        let result = TokenService.parseClaudeStats(from: json)
        XCTAssertNil(result)
    }

    func testParseClaudeStats_invalidJSON() {
        let json = "not json".data(using: .utf8)!
        let result = TokenService.parseClaudeStats(from: json)
        XCTAssertNil(result)
    }

    func testParseClaudeStats_activityButNoTokens() {
        let today = Self.todayString()
        let json = """
        {
          "version": 2,
          "dailyActivity": [
            {"date": "\(today)", "messageCount": 10, "sessionCount": 1}
          ],
          "dailyModelTokens": []
        }
        """.data(using: .utf8)!

        let result = TokenService.parseClaudeStats(from: json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.totalTokens, 0)
        XCTAssertEqual(result?.sessionCount, 1)
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build-for-testing 2>&1 | tail -3`
Expected: FAIL — `parseClaudeStats` does not exist yet

- [ ] **Step 3: Implement Claude parsing and integrate into fetchAll**

In `TokenService.swift`, add the static method after `queryCodexDatabase`:

```swift
nonisolated static func parseClaudeStats(from data: Data) -> (totalTokens: Int, sessionCount: Int)? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let today = formatter.string(from: Date())

    // Find today's session count from dailyActivity
    let dailyActivity = json["dailyActivity"] as? [[String: Any]] ?? []
    let todayActivity = dailyActivity.first { ($0["date"] as? String) == today }
    guard let activity = todayActivity else { return nil }
    let sessionCount = activity["sessionCount"] as? Int ?? 0

    // Sum all model tokens for today from dailyModelTokens
    let dailyTokens = json["dailyModelTokens"] as? [[String: Any]] ?? []
    let todayTokens = dailyTokens.first { ($0["date"] as? String) == today }
    var totalTokens = 0
    if let tokensByModel = todayTokens?["tokensByModel"] as? [String: Any] {
        for (_, value) in tokensByModel {
            totalTokens += value as? Int ?? 0
        }
    }

    return (totalTokens, sessionCount)
}

nonisolated static func queryClaudeStats() -> (totalTokens: Int, sessionCount: Int)? {
    let path = NSHomeDirectory() + "/.claude/stats-cache.json"
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
        return nil
    }
    return parseClaudeStats(from: data)
}
```

Then update `fetchAll()` to also query Claude. Add inside the `Task.detached` block, after the Codex query:

```swift
func fetchAll() {
    let path = codexDbPath
    Task.detached {
        let codexUsage = Self.queryCodexDatabase(at: path)
        let claudeUsage = Self.queryClaudeStats()
        await MainActor.run { [weak self] in
            guard let self else { return }
            if let usage = codexUsage, let idx = self.tools.firstIndex(where: { $0.id == "codex" }) {
                self.tools[idx].totalTokens = usage.totalTokens
                self.tools[idx].sessionCount = usage.sessionCount
                self.tools[idx].lastUpdated = Date()
            }
            if let usage = claudeUsage, let idx = self.tools.firstIndex(where: { $0.id == "claude" }) {
                self.tools[idx].totalTokens = usage.totalTokens
                self.tools[idx].sessionCount = usage.sessionCount
                self.tools[idx].lastUpdated = Date()
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug clean build-for-testing 2>&1 | tail -3 && xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug test-without-building 2>&1 | grep "Executed" | tail -1`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add MacJarvis/MacJarvis/Services/TokenService.swift MacJarvisTests/TokenServiceClaudeTests.swift
git commit -m "feat: add Claude token collection from stats-cache.json"
```

---

### Task 4: Gemini Session Collection

Scan `~/.gemini/tmp/*/logs.json` files to count today's sessions and messages across all Gemini CLI projects.

**Data source:** `~/.gemini/tmp/<projectHash>/logs.json` — JSON array of session entries with structure:
- `{sessionId, messageId, type: "user"|"model", ...}`
- Session files in `chats/session-YYYY-MM-DDTHH-mm-<sessionId>.json` contain `{startTime, lastUpdated}` timestamps

Strategy: Scan all `chats/session-*.json` files across all project dirs, count files whose filename date matches today. Count unique sessionIds for session count, sum message entries for message count. Since Gemini CLI doesn't track output tokens, we show message count instead of tokens.

**Files:**
- Modify: `MacJarvis/MacJarvis/Services/TokenService.swift` (add Gemini query method, wire into fetchAll)
- Modify: `MacJarvis/MacJarvis/Models/ToolUsage.swift` (add messageCount field for Gemini display)
- Modify: `MacJarvis/MacJarvis/Views/TokenCardView.swift` (show messageCount when totalTokens is nil)
- Create: `MacJarvisTests/TokenServiceGeminiTests.swift`

- [ ] **Step 1: Add messageCount to ToolUsage**

In `ToolUsage.swift`, add after `sessionCount`:

```swift
var messageCount: Int?
```

And add a computed property after `formattedTokens`:

```swift
var formattedActivity: String {
    if let tokens = totalTokens {
        return formattedTokens
    }
    guard let msgs = messageCount else { return "--" }
    return "\(msgs)msg"
}
```

- [ ] **Step 2: Update TokenCardView to use formattedActivity**

In `TokenCardView.swift`, replace `tool.formattedTokens` (line 20) with `tool.formattedActivity`, and update the color condition (line 22) to also check `messageCount`:

```swift
Text(tool.formattedActivity)
    .font(CyberTheme.pixelFont(size: 6))
    .foregroundColor((tool.totalTokens != nil || tool.messageCount != nil) ? CyberTheme.cyan : CyberTheme.dimGray)
```

- [ ] **Step 3: Write failing tests for Gemini parsing**

Create `MacJarvisTests/TokenServiceGeminiTests.swift`:

```swift
import XCTest
@testable import MacJarvis

@MainActor
final class TokenServiceGeminiTests: XCTestCase {

    func testCountGeminiSessions_todayFiles() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("gemini-test-\(UUID())")
        let chatsDir = tmpDir.appendingPathComponent("proj1/chats")
        try FileManager.default.createDirectory(at: chatsDir, withIntermediateDirectories: true)

        let today = Self.todayPrefix()
        let todayFile = chatsDir.appendingPathComponent("session-\(today)-abc123.json")
        let oldFile = chatsDir.appendingPathComponent("session-2025-01-01T10-00-old123.json")

        let sessionJSON = """
        {"sessionId": "abc123", "startTime": "\(today):00.000Z", "lastUpdated": "\(today):01.000Z"}
        """.data(using: .utf8)!
        try sessionJSON.write(to: todayFile)
        try "{}".data(using: .utf8)!.write(to: oldFile)

        let result = TokenService.queryGeminiSessions(basePath: tmpDir.path)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sessionCount, 1)

        try FileManager.default.removeItem(at: tmpDir)
    }

    func testCountGeminiSessions_noFiles() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("gemini-test-\(UUID())")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let result = TokenService.queryGeminiSessions(basePath: tmpDir.path)
        XCTAssertNil(result)

        try FileManager.default.removeItem(at: tmpDir)
    }

    func testCountGeminiSessions_multipleProjects() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("gemini-test-\(UUID())")
        let chats1 = tmpDir.appendingPathComponent("proj1/chats")
        let chats2 = tmpDir.appendingPathComponent("proj2/chats")
        try FileManager.default.createDirectory(at: chats1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: chats2, withIntermediateDirectories: true)

        let today = Self.todayPrefix()
        try "{}".data(using: .utf8)!.write(to: chats1.appendingPathComponent("session-\(today)-s1.json"))
        try "{}".data(using: .utf8)!.write(to: chats2.appendingPathComponent("session-\(today)-s2.json"))
        try "{}".data(using: .utf8)!.write(to: chats2.appendingPathComponent("session-\(today)-s3.json"))

        let result = TokenService.queryGeminiSessions(basePath: tmpDir.path)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sessionCount, 3)

        try FileManager.default.removeItem(at: tmpDir)
    }

    private static func todayPrefix() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm"
        return formatter.string(from: Date())
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build-for-testing 2>&1 | tail -3`
Expected: FAIL — `queryGeminiSessions` does not exist yet

- [ ] **Step 5: Implement Gemini session counting**

In `TokenService.swift`, add after `queryClaudeStats`:

```swift
nonisolated static func queryGeminiSessions(basePath: String? = nil) -> (sessionCount: Int, messageCount: Int)? {
    let base = basePath ?? (NSHomeDirectory() + "/.gemini/tmp")
    let fm = FileManager.default

    guard let projectDirs = try? fm.contentsOfDirectory(atPath: base) else {
        return nil
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let todayPrefix = "session-" + formatter.string(from: Date())

    var totalSessions = 0

    for projectDir in projectDirs {
        let chatsPath = (base as NSString).appendingPathComponent("\(projectDir)/chats")
        guard let files = try? fm.contentsOfDirectory(atPath: chatsPath) else { continue }

        for file in files where file.hasPrefix(todayPrefix) && file.hasSuffix(".json") {
            totalSessions += 1
        }
    }

    guard totalSessions > 0 else { return nil }
    return (totalSessions, 0)
}
```

Then wire into `fetchAll()` — add inside the `Task.detached` block:

```swift
let geminiUsage = Self.queryGeminiSessions()
```

And in the `MainActor.run` block:

```swift
if let usage = geminiUsage, let idx = self.tools.firstIndex(where: { $0.id == "gemini" }) {
    self.tools[idx].sessionCount = usage.sessionCount
    self.tools[idx].lastUpdated = Date()
}
```

- [ ] **Step 6: Run all tests**

Run: `xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug clean build-for-testing 2>&1 | tail -3 && xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug test-without-building 2>&1 | grep "Executed" | tail -1`
Expected: All tests pass (including new Gemini tests)

- [ ] **Step 7: Commit**

```bash
git add MacJarvis/MacJarvis/Services/TokenService.swift MacJarvis/MacJarvis/Models/ToolUsage.swift MacJarvis/MacJarvis/Views/TokenCardView.swift MacJarvisTests/TokenServiceGeminiTests.swift
git commit -m "feat: add Gemini session collection from CLI logs"
```
