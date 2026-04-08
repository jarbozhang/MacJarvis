---
title: "feat: 嵌入式终端 Tab — Codex / Gemini / Claude"
type: feat
status: active
date: 2026-04-08
origin: docs/brainstorms/2026-04-08-embedded-terminal-tabs-requirements.md
---

# feat: 嵌入式终端 Tab — Codex / Gemini / Claude

## Overview

将底部导航栏的 Codex、Gemini、Claude tab 从纯占位改为可交互的嵌入终端。每个 tab 在首次点击时启动对应的 CLI 工具（带自动确认参数），通过 SwiftTerm 库渲染完整的 TUI 界面，终端替换右侧 TerminalLog 区域。

## Problem Frame

MacJarvis 底部三个 AI 工具 tab 当前无功能。用户需要在 dashboard 内直接使用 Codex/Gemini/Claude 的 TUI，无需切换到外部终端。(see origin: docs/brainstorms/2026-04-08-embedded-terminal-tabs-requirements.md)

## Requirements Trace

- R1. 点击 tab 时右侧内容区切换为嵌入终端
- R2. 左侧卡片区和中间 Token 列始终可见
- R3. OPENCLAW tab 切回 TerminalLog
- R4. 终端进程首次点击时懒启动
- R5. 进程持续运行，tab 切换只显示/隐藏
- R6. app 退出时终止所有进程
- R7. Codex: `codex --full-auto`
- R8. Gemini: `gemini --yolo`
- R9. Claude: `claude --dangerously-skip-permissions`
- R10. 支持完整 ANSI 颜色和 TUI 渲染
- R11. 默认终端样式
- R12. 支持键盘输入和交互

## Scope Boundaries

- 不做终端主题定制
- 不做命令可配置
- 不做终端分屏
- 不自己实现终端模拟器

## Context & Research

### Relevant Code and Patterns

- `project.yml`: WhisperKit 依赖配置模式可复用于 SwiftTerm
- `BottomNavBar.swift`: tab 当前硬编码 `isActive: true/false`，需改为状态驱动
- `DashboardView.swift`: GeometryReader 布局，右侧区域需条件渲染
- `MacJarvisApp.swift`: Environment 注入所有 Service 的模式
- 所有 Service 使用 `@Observable @MainActor` 模式

### CLI Auto-Approve Flags

| Tool | Command | Flag |
|------|---------|------|
| Codex | `codex` | `--full-auto` |
| Gemini | `gemini` | `--yolo` |
| Claude | `claude` | `--dangerously-skip-permissions` |

## Key Technical Decisions

- **SwiftTerm 库**: 成熟的 Swift 终端模拟器，支持 PTY + ANSI + 完整 TUI。通过 NSViewRepresentable 嵌入 SwiftUI。GitHub: migueldeicaza/SwiftTerm
- **每个 tab 独立的 Process + PTY**: 三个终端各自持有一个 Foundation.Process 和 PTY 文件描述符，生命周期独立
- **Tab 状态用 enum**: 新增 `ActiveTab` enum（.openclaw / .codex / .gemini / .claude），由 DashboardView 持有 @State
- **右侧区域条件渲染**: 根据 activeTab 在 TerminalLogView 和 EmbeddedTerminalView 之间切换，用 opacity+allowsHitTesting 而非 if/else 以保持进程存活
- **TerminalSessionService**: 新 Service 管理三个终端的进程生命周期，遵循现有 @Observable @MainActor 模式

## Open Questions

### Resolved During Planning

- **SwiftTerm 的 SwiftUI 集成**: SwiftTerm 提供 `TerminalView`（NSView 子类），通过 `NSViewRepresentable` 包装为 SwiftUI View
- **键盘焦点**: SwiftTerm 的 TerminalView 本身是 NSView，接受 firstResponder，SwiftUI 中需在 tab 激活时调用 `makeFirstResponder`

### Deferred to Implementation

- **SwiftTerm 的确切版本号**: 需在 SPM 添加后确认可用的最新版本
- **Process 环境变量继承**: 可能需要传递 PATH 和 TERM 环境变量确保 CLI 能找到
- **终端尺寸同步**: SwiftTerm TerminalView 的 resize 需与 GeometryReader 联动

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification.*

```
Tab 切换流程:

BottomNavBar (tap) → @Binding activeTab → DashboardView 条件渲染

右侧内容区:
  .openclaw → TerminalLogView (现有)
  .codex    → EmbeddedTerminalView(session: codexSession)
  .gemini   → EmbeddedTerminalView(session: geminiSession)
  .claude   → EmbeddedTerminalView(session: claudeSession)

进程生命周期:
  TerminalSessionService
    ├─ sessions: [TabId: TerminalSession]
    ├─ startSession(tab) → Process + PTY → SwiftTerm
    └─ stopAll() → terminate all processes

EmbeddedTerminalView (NSViewRepresentable)
    ├─ wraps SwiftTerm.LocalProcessTerminalView
    ├─ on appear: start process if not running
    └─ on tab active: becomeFirstResponder
```

## Implementation Units

- [ ] **Unit 1: 添加 SwiftTerm 依赖**

**Goal:** 将 SwiftTerm 加入项目依赖

**Requirements:** R10

**Dependencies:** None

**Files:**
- Modify: `project.yml`

**Approach:**
- 在 `packages` 节添加 SwiftTerm URL 和版本
- 在 MacJarvis target 的 `dependencies` 中添加 `- package: SwiftTerm`
- 运行 `xcodegen generate` 验证

**Patterns to follow:**
- WhisperKit 的依赖配置模式

**Test scenarios:**
Test expectation: none -- 纯依赖配置，通过构建验证

**Verification:**
- `xcodegen generate && xcodebuild build` 成功，SwiftTerm 可 import

---

- [ ] **Unit 2: Tab 状态管理**

**Goal:** 底部导航栏支持真实的 tab 切换状态

**Requirements:** R1, R3

**Dependencies:** None

**Files:**
- Create: `MacJarvis/Models/ActiveTab.swift`
- Modify: `MacJarvis/Views/BottomNavBar.swift`
- Modify: `MacJarvis/Views/DashboardView.swift`

**Approach:**
- 新增 `ActiveTab` enum: `.openclaw` / `.codex` / `.gemini` / `.claude`
- DashboardView 持有 `@State private var activeTab: ActiveTab = .openclaw`
- BottomNavBar 接受 `@Binding var activeTab: ActiveTab`，点击时更新
- 右侧区域根据 activeTab 切换显示内容（暂用占位 Text）

**Patterns to follow:**
- SettingsView 的 `@Binding var isPresented` 传值模式

**Test scenarios:**
- Happy path: 点击 CODEX tab → activeTab 变为 .codex，右侧显示变化
- Happy path: 点击 OPENCLAW → 回到 TerminalLogView
- Edge case: 快速连续点击多个 tab → 状态稳定无崩溃

**Verification:**
- 四个 tab 可点击切换，右侧内容区对应变化

---

- [ ] **Unit 3: TerminalSessionService 进程管理**

**Goal:** 管理终端进程的创建、运行和销毁

**Requirements:** R4, R5, R6, R7, R8, R9

**Dependencies:** Unit 1

**Files:**
- Create: `MacJarvis/Services/TerminalSessionService.swift`
- Modify: `MacJarvis/MacJarvisApp.swift`

**Approach:**
- `@Observable @MainActor` class，遵循现有 Service 模式
- 内部维护 `[ActiveTab: LocalProcessTerminalView]` 字典（SwiftTerm 的 LocalProcessTerminalView 自带进程管理）
- `getOrCreateTerminal(for tab:) -> LocalProcessTerminalView`：懒创建，首次调用时启动进程
- 启动参数: 根据 tab 类型选择命令和参数
- `stopAll()`：遍历终止所有进程，app 退出时调用
- 进程启动时设置环境变量 PATH（从 ProcessInfo 继承）和 TERM=xterm-256color

**Patterns to follow:**
- OpenClawService 的 @Observable @MainActor 模式
- MacJarvisApp 中 Environment 注入 Service 的模式

**Test scenarios:**
- Happy path: getOrCreateTerminal(.codex) 首次调用 → 创建新终端并启动 `codex --full-auto`
- Happy path: 再次调用 getOrCreateTerminal(.codex) → 返回同一个终端实例
- Happy path: stopAll() → 所有进程被终止
- Error path: CLI 不存在（PATH 找不到）→ 终端显示错误信息，不崩溃

**Verification:**
- 三个工具可各自启动进程，进程持续运行

---

- [ ] **Unit 4: EmbeddedTerminalView SwiftUI 包装**

**Goal:** 将 SwiftTerm 的 NSView 包装为可嵌入 SwiftUI 的 View

**Requirements:** R10, R11, R12

**Dependencies:** Unit 1, Unit 3

**Files:**
- Create: `MacJarvis/Views/EmbeddedTerminalView.swift`

**Approach:**
- NSViewRepresentable 包装 SwiftTerm 的 `LocalProcessTerminalView`
- `makeNSView`: 从 TerminalSessionService 获取或创建终端 view
- 终端 view 配置: 默认字体（Menlo 或系统等宽）、默认配色
- `updateNSView`: 当 isActive 变化时，激活的终端 `becomeFirstResponder`
- 尺寸跟随父容器自动调整（SwiftTerm 内置支持 resize）

**Patterns to follow:**
- SwiftUI NSViewRepresentable 标准模式

**Test scenarios:**
- Happy path: 嵌入 EmbeddedTerminalView → SwiftTerm 渲染正常，显示 CLI 输出
- Happy path: 键盘输入 → 字符到达终端进程
- Happy path: Ctrl+C → 发送 SIGINT
- Integration: tab 激活时终端获得键盘焦点，切走后不再接收输入

**Verification:**
- 终端可见、可输入、TUI 界面正确渲染

---

- [ ] **Unit 5: DashboardView 集成**

**Goal:** 将 tab 切换与嵌入终端完整串联

**Requirements:** R1, R2, R3, R4, R5

**Dependencies:** Unit 2, Unit 3, Unit 4

**Files:**
- Modify: `MacJarvis/Views/DashboardView.swift`
- Modify: `MacJarvis/MacJarvisApp.swift`

**Approach:**
- DashboardView 右侧区域使用 ZStack + opacity 切换（而非 if/else），保持所有终端进程存活
- `.openclaw` 时 TerminalLogView opacity=1，其他 opacity=0 + allowsHitTesting(false)
- `.codex/.gemini/.claude` 时对应 EmbeddedTerminalView opacity=1
- MacJarvisApp 的 onDisappear 调用 `terminalSessionService.stopAll()`

**Patterns to follow:**
- 现有 SettingsView overlay 的 ZStack 模式
- GeometryReader 内的缩放逻辑

**Test scenarios:**
- Happy path: 启动 app → OPENCLAW 默认，右侧显示 TerminalLog
- Happy path: 点击 CLAUDE → 右侧切换为 Claude 终端，进程启动
- Happy path: 切回 OPENCLAW → TerminalLog 恢复，Claude 终端隐藏但进程继续
- Happy path: 再切回 CLAUDE → 会话完整保留
- Integration: app 退出 → 所有终端进程被终止

**Verification:**
- 四个 tab 完整可用，终端 TUI 正常渲染和交互

## System-Wide Impact

- **Interaction graph:** BottomNavBar → DashboardView (activeTab binding) → EmbeddedTerminalView → TerminalSessionService → Process/PTY
- **Error propagation:** CLI 不存在或崩溃时，终端 view 显示错误输出，不影响 app 其他部分
- **State lifecycle risks:** 进程在 tab 隐藏时继续运行，占用内存和 CPU。可接受——TUI 空闲时开销极低
- **Unchanged invariants:** OPENCLAW tab 的 TerminalLogView 和 OpenClawService 完全不变；Token 数据采集不受影响

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| SwiftTerm 与 macOS 14+ 兼容性 | SwiftTerm 活跃维护，macOS 支持良好 |
| CLI 工具未安装或不在 PATH | 进程启动失败时在终端内显示错误提示 |
| TUI 渲染异常（颜色/布局） | SwiftTerm 支持 xterm-256color，三个工具的 TUI 均基于标准终端协议 |
| 键盘焦点冲突 | 仅激活 tab 的终端获得 firstResponder |
| 新增 SPM 依赖 SwiftTerm | 需要确认版本，构建时间可能增加 |

## Sources & References

- **Origin document:** [docs/brainstorms/2026-04-08-embedded-terminal-tabs-requirements.md](../brainstorms/2026-04-08-embedded-terminal-tabs-requirements.md)
- SwiftTerm GitHub: https://github.com/migueldeicaza/SwiftTerm
- BottomNavBar: `MacJarvis/Views/BottomNavBar.swift`
- DashboardView: `MacJarvis/Views/DashboardView.swift`
- project.yml: `project.yml`（WhisperKit 依赖配置模式）
