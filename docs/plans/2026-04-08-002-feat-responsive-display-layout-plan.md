---
title: "feat: 自适应显示器布局与缩放"
type: feat
status: active
date: 2026-04-08
origin: docs/brainstorms/2026-04-08-responsive-display-layout-requirements.md
---

# feat: 自适应显示器布局与缩放

## Overview

改造 DisplayManager 的屏幕检测逻辑：≤1024 宽度的显示器自动全屏，>1024 宽度使用标准窗口模式并自动适配大小。引入 scaleFactor 让字体和间距随窗口大小比例缩放。

## Problem Frame

MacJarvis 当前仅匹配 800x480 和 1280x720 两种分辨率，其他显示器上固定为 800x480 居中。高分屏上字体过小，按钮过小。(see origin: docs/brainstorms/2026-04-08-responsive-display-layout-requirements.md)

## Requirements Trace

- R1. ≤1024 宽度的外接显示器自动全屏
- R2. 全屏模式下内容适配实际分辨率
- R3. >1024 宽度使用标准窗口模式
- R4. 窗口大小自动适配屏幕
- R5. 字体按窗口宽度比例缩放（基准 800px）
- R6. 按钮和交互元素同步缩放

## Scope Boundaries

- 不做用户手动缩放
- 不改变三栏布局结构
- 不做响应式断点重排

## Key Technical Decisions

- **缩放因子 = contentSize.width / 800.0**: 基准 800px 对应 scaleFactor 1.0，1600px 则为 2.0。通过 Environment 注入所有 View
- **窗口大小 = 屏幕可用区域的 80%**: >1024 屏幕下，窗口宽高取 `visibleFrame * 0.8`，保持 5:3 宽高比（与 800:480 一致）
- **≤1024 阈值用逻辑点宽度判断**: 使用 `NSScreen.frame.width`（逻辑点），不乘 backingScaleFactor，避免 Retina 屏误判
- **AppTheme 字体方法加 scale 参数**: 不改现有签名，新增 `scaled()` 系列方法，保持向后兼容

## Open Questions

### Resolved During Planning

- **窗口宽高比**: 保持 5:3（800:480），高分屏用更大的 5:3 窗口
- **阈值用什么单位**: 逻辑点（NSScreen.frame.width），因为 macOS 已经对 Retina 做了抽象

### Deferred to Implementation

- **内置 MacBook 屏与外接屏同时存在时的行为**: 优先检测外接屏，无外接屏时用内置屏的窗口模式

## Implementation Units

- [ ] **Unit 1: DisplayManager 屏幕检测重构**

**Goal:** 用 ≤1024 阈值替代固定分辨率匹配，支持全屏和窗口两种模式

**Requirements:** R1, R2, R3, R4

**Dependencies:** None

**Files:**
- Modify: `MacJarvis/Services/DisplayManager.swift`
- Test: `MacJarvisTests/DisplayManagerTests.swift`

**Approach:**
- `checkScreens()` 遍历所有屏幕，优先找外接屏（排除 `localizedName` 含 "Built-in" 的屏幕）
- 外接屏宽度 ≤1024（逻辑点）→ 全屏模式，contentSize = 屏幕实际尺寸
- 无外接屏或外接屏宽度 >1024 → 窗口模式，contentSize = 可用区域 80% 宽度，保持 5:3 比例
- `moveWindowToTarget()` 仅在全屏模式下调用
- 新增 `isFullscreen` 状态变量区分两种模式

**Patterns to follow:**
- 现有 `checkScreens()` 的屏幕遍历模式
- 现有 `moveWindowToTarget()` / `restoreWindow()` 的窗口操作模式

**Test scenarios:**
- Happy path: 800x480 屏幕 → isFullscreen=true, contentSize=(800,480)
- Happy path: 1024x600 屏幕 → isFullscreen=true, contentSize=(1024,600)
- Happy path: 2560x1440 屏幕 → isFullscreen=false, contentSize=~(1152,691) (80% of visible, 5:3 ratio)
- Edge case: 1024 宽度 → isFullscreen=true（≤1024 包含等于）
- Edge case: 1025 宽度 → isFullscreen=false
- Edge case: 无外接屏 → 使用主屏窗口模式

**Verification:**
- 在不同分辨率模拟下，全屏/窗口模式正确切换，contentSize 正确计算

---

- [ ] **Unit 2: 缩放因子 Environment 注入**

**Goal:** 新增 scaleFactor Environment key，AppTheme 提供 scaled 字体方法

**Requirements:** R5, R6

**Dependencies:** Unit 1（contentSize 必须先正确）

**Files:**
- Modify: `MacJarvis/Theme/AppTheme.swift`
- Modify: `MacJarvis/MacJarvisApp.swift`

**Approach:**
- AppTheme 新增 `ScaleFactorKey: EnvironmentKey`，默认值 1.0
- `MacJarvisApp` 计算 `scaleFactor = displayManager.contentSize.width / 800.0`，注入 `.environment(\.scaleFactor, scaleFactor)`
- AppTheme 新增 `headlineFont(size:scale:)` 等方法，`size * scale` 后调用 `.custom()`
- `cardSpacing` 改为计算属性 `static func cardSpacing(scale: CGFloat) -> CGFloat`

**Patterns to follow:**
- 现有 `ThemeKey` 的 EnvironmentKey 模式
- 现有 `AppTheme.headlineFont(size:)` 的静态方法模式

**Test scenarios:**
- Happy path: scaleFactor=1.0 时，headlineFont(size:12, scale:1.0) = 12pt
- Happy path: scaleFactor=2.0 时，headlineFont(size:12, scale:2.0) = 24pt
- Edge case: scaleFactor=0.5 时字体不会小于某个最小值（如 6pt）

**Verification:**
- Environment 注入后所有 View 可读取 scaleFactor

---

- [ ] **Unit 3: 全局 View 字体/间距缩放**

**Goal:** 所有 View 使用 scaleFactor 缩放字体和关键间距

**Requirements:** R5, R6

**Dependencies:** Unit 2

**Files:**
- Modify: `MacJarvis/Views/DashboardView.swift`
- Modify: `MacJarvis/Views/TokenCard.swift`
- Modify: `MacJarvis/Views/CoreStatusView.swift`
- Modify: `MacJarvis/Views/TerminalLogView.swift`
- Modify: `MacJarvis/Views/SettingsView.swift`
- Modify: `MacJarvis/Views/HeaderView.swift`
- Modify: `MacJarvis/Views/BottomNavBar.swift`
- Modify: `MacJarvis/Views/HardwareStatsView.swift`
- Modify: `MacJarvis/Views/TokenColumnView.swift`
- Modify: `MacJarvis/Theme/CyberTheme.swift`

**Approach:**
- 每个 View 读取 `@Environment(\.scaleFactor) var scale`
- 所有 `AppTheme.xxxFont(size: N)` 调用改为 `AppTheme.xxxFont(size: N * scale)`
- 关键间距（padding, spacing）乘以 scale
- 图标 `font(.system(size: N))` 改为 `font(.system(size: N * scale))`
- 批量替换，保持现有布局逻辑不变

**Patterns to follow:**
- 现有 View 中的字体和间距使用模式

**Test scenarios:**
Test expectation: none -- 纯样式变更，通过视觉验证

**Verification:**
- 在 800px 宽度下外观与当前一致（scaleFactor=1.0）
- 在 1600px 宽度下字体和间距明显放大（scaleFactor=2.0）

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| 高分屏下某些元素溢出或重叠 | contentSize 保持 5:3 比例，布局逻辑不变，只缩放内容 |
| 内置 Retina 屏被误判为 ≤1024 | 使用逻辑点宽度，MacBook 内置屏逻辑点宽度一般 ≥1440 |

## Sources & References

- **Origin document:** [docs/brainstorms/2026-04-08-responsive-display-layout-requirements.md](../brainstorms/2026-04-08-responsive-display-layout-requirements.md)
- DisplayManager: `MacJarvis/Services/DisplayManager.swift`
- AppTheme: `MacJarvis/Theme/AppTheme.swift`
