---
title: "feat: Fill OpenClaw/Hermes status strip center with logo + detail"
type: feat
status: completed
date: 2026-06-02
deepened: 2026-06-02
---

# feat: Fill OpenClaw/Hermes status strip center with logo + detail

## Overview

`LargeAgentStatusStrip` 当前左侧是 4px 状态色竖条 + 名称/徽章/detail，右侧是 SIGNAL/tokens/cost，由一个大 `Spacer` 拉出中间空白。该长条横跨主屏黄金视线区，中部空旷使用户第一眼无法快速读取「Agent 在干什么」。

本次改造采用**三段式**布局：

- **左端**：32px Logo（OpenClaw 复用 `LobsterShape`，Hermes 新增 `HermesWingShape`）+ 保留 4px 状态色竖条；Logo 不参与动画，仅静态 `neonGlow` 渲染状态色。
- **中部**：状态色脉冲点 ● + 大字 `snapshot.statusLine`（label 字体 14pt × scale），RUNNING 时脉冲点动画，其余状态静态
- **右端**：原 SIGNAL / tokens / cost 区块不动

数据沿用现有字段：上游字段是 `snapshot.detail`，显示走已存在的 `snapshot.statusLine` 计算属性（`detail` 为空时自动回退 `status.accessibilityPhrase`）。无 model、service 改动。

## Problem Frame

`AgentStatusWallView`（800-1280px 横屏视图）把 OpenClaw / Hermes 长条放在屏幕中央高度，每条约 60-70px 高。当前 `LargeAgentStatusStrip` 视觉重心偏左右两侧，中段大片黑色，违反"agent 状态是 dashboard 主信号"的设计前提（参见 R2、R10 自 `2026-05-29-001-feat-agent-status-wall-plan.md`）。

## Requirements Trace

- R-CENTER-1. 长条中部不再为空白，必须承载状态色脉冲点 + 大字 `statusLine` 文本
- R-LOGO-2. 左端展示对应 agent 的图形 logo，与现有 4px 状态色竖条并存
- R-HERMES-3. 新增 Hermes 的手绘翅膀/羽毛 Shape，风格与 `LobsterShape` 一致（Canvas + Path，赛博朋克像素感）
- R-A11Y-4. 改造后保留并增强可访问性：
  - 父容器 `accessibilityIdentifier("largeAgentStatus-<kind>")` 不变
  - 父容器 `accessibilityLabel` 顺序：displayName, status, statusLine, signal age
  - Logo 标记 `accessibilityHidden(true)`（装饰性）
  - 新增 `accessibilityIdentifier("agentLogo-<kind>")` 与 `accessibilityIdentifier("agentDetail-<kind>")` 供 XCUITest 选择
- R-MIN-5. 不新增 Service、不修改 Model、不引入新依赖
- R-NONINT-6. Strip 在本迭代保持非交互：不加 tap/hover/focus 手势与可点击 affordance

## Scope Boundaries

非目标：
- 不改动 `snapshot.detail` / `statusLine` 内容来源（OpenClawService / HermesService / LargeAgentStatusService 文本不变）
- 不在中部加最近消息预览 / token 进度条 / 二级图表（YAGNI；后续若需要再单开 plan）
- 不动 `AgentStatusWallView` 顶部 headline 与底部 `CompactConsumptionStrip` / `CompactSystemStrip`
- 不调整 dashboard rotation / fault interrupt 逻辑
- 不把 strip 改为可点击/可悬停/可聚焦交互组件（R-NONINT-6）
- 不为 `HermesWingShape`/`LargeAgentStatusStrip` 引入 ViewInspector 等第三方视图反射依赖（XCUI 已能覆盖）

## Context & Research

### Relevant Code and Patterns

- `MacJarvis/Views/LargeAgentStatusStrip.swift` — 当前长条实现，HStack(色条 / 左 VStack / Spacer / 右 VStack)
- `MacJarvis/Views/LobsterShape.swift` — 现成 Canvas Shape，参考其 `bodyColor / antennaColor / eyeHighlightColor` 注入颜色的接口
- `MacJarvis/Views/CoreStatusView.swift:32` — `LobsterShape(isBlinking:)` 用法 + `floating` 修饰器 + `neonGlow` 用法
- `MacJarvis/Theme/CyberTheme.swift` — `NeonGlow`、`FloatingModifier`、`FadeInUpModifier` 已可复用
- `MacJarvis/Views/AgentStatusVisuals.swift` — `LargeAgentSeverity.color(theme:)`、`LargeAgentSnapshot.statusLine` / `ageText` 已存在
- `MacJarvis/Models/LargeAgentStatus.swift` — `LargeAgentKind { case openClaw, hermes }` 给 logo 分派提供枚举

### Institutional Learnings

- `docs/plans/2026-05-29-001-feat-agent-status-wall-plan.md`：本组件最近一次大改造已建立 scale / theme / accessibility 约定，本次延续即可

## Key Technical Decisions

- **Logo 分派用 switch over `LargeAgentKind`，不抽 protocol**。两种 agent，写法直接，YAGNI。新增 view `AgentLogoView(kind:color:)` 内部 `switch` 渲染对应 shape。
- **保留 4px 色条**。Logo 是身份标识，色条仍是状态色的冗余通道，颜色变化（neutral/normal/active/warning/error 5 档）通过竖条比 logo 辉光更精确。
- **只让 PulseDot 动画，Logo 静态**。脉冲动画仅集中在中部的 PulseDot，使用 SwiftUI `phaseAnimator` 让 opacity 在 0.4↔1.0 之间走 1.2s easeInOut。Logo 用静态 `neonGlow(color: severityColor)` 表达状态色，**不**做 opacity 脉冲、不做 floating——避免两个动画节奏在小屏上竞争。
- **`accessibilityReduceMotion` 时关闭脉冲**。`PulseDot` 在 reduceMotion 开时直接走静态 fill 分支，不调用 phaseAnimator。
- **Detail 在中部显示，左侧不再重复**。把 `statusLine` 节点从左 VStack 移走，左端只放 name + status badge，避免视觉重复。
- **三段式居中靠对称 Spacer**。左右两侧用对称的 `Spacer(minLength: 8 * scale)`，中部 HStack 自带 `.layoutPriority(1)` 确保抢占空间；右端 VStack 维持现有 `minWidth: 110 * scale`。最小 800px viewport 下若仍挤，靠 `minimumScaleFactor(0.6)` 缩字。
- **HermesWingShape 用 Canvas + Path 绘制简化双翅 + 中心圆点**。和 `LobsterShape` 同样规格：参数化 `bodyColor`、`accentColor`。不接 `isPulsing` 参数（YAGNI，Logo 本次不动画）。

## Open Questions

### Resolved During Planning

- Logo 在 RUNNING 时是否需要动画？— 决策：**不动画**。Logo 仅用静态 `neonGlow(severityColor)` 表达状态色；脉冲集中由中部 PulseDot 承担，避免节奏冲突。
- Hermes 图形要包含双蛇杖 (caduceus) 吗？— 决策：不要。仅画一对极简翅膀 + 中心宝石/圆点。视觉密度对齐 LobsterShape。
- `snapshot.detail` 还是 `snapshot.statusLine`？— 决策：上游字段是 `detail`，显示用 `statusLine`（已有的 nil 回退 wrapper）。Approach 与测试统一引用 `statusLine`。
- 中部脉冲在 warning / error 状态要不要继续脉？— 决策：**不脉冲**。仅 `.running` 状态 PulseDot 动画；warning / error / stuck / offline / idle / unknown 均走静态 fill（颜色按 severity 切换）。
- 长 statusLine（如长 tool 调用名）如何处理？— 决策：`lineLimit(1)` + `minimumScaleFactor(0.6)` + `.truncationMode(.tail)`。第一版接受 800px 下偶发缩字。
- accessibilityLabel 是否包含 statusLine？— 决策：**包含**。顺序：displayName, status, statusLine, signal age。Logo 标 `accessibilityHidden(true)` 避免重复读出。

### Deferred to Implementation

- HermesWingShape 的 Path 曲线控制点：写时凭眼校准
- 中部 statusLine 字号在 800 / 1024 / 1280 viewport 下的最终 scale 系数：先用 14 * scale + `minimumScaleFactor(0.6)`，构建后视觉调整；若 800px 屏严重过窄再降级到 12 * scale

## High-Level Technical Design

> *以下是方向性示意，不是实现规范。实现 agent 应作为上下文参考，不必逐字复刻。*

```
HStack(spacing: 10) {
  AgentLogoView(kind: snapshot.kind, color: severityColor)
    .frame(width: 32, height: 32)
    .neonGlow(color: severityColor)
    .accessibilityHidden(true)

  Rectangle().fill(severityColor).frame(width: 4).neonGlow(color: severityColor)

  VStack(alignment: .leading) {
    Text(snapshot.displayName.uppercased())
    StatusBadge(snapshot.status.label, color: severityColor)
  }

  Spacer(minLength: 8)

  HStack(spacing: 8) {
    PulseDot(color: severityColor, isPulsing: snapshot.status == .running)
      .accessibilityIdentifier("agentPulse-\(snapshot.kind.rawValue)")
    Text(snapshot.statusLine.uppercased())
      .font(.label(size: 14 * scale))
      .lineLimit(1)
      .truncationMode(.tail)
      .minimumScaleFactor(0.6)
      .accessibilityIdentifier("agentDetail-\(snapshot.kind.rawValue)")
  }
  .layoutPriority(1)

  Spacer(minLength: 8)

  VStack(alignment: .trailing) { /* SIGNAL / tokens / cost — 不变 */ }
    .frame(minWidth: 110)
}
.accessibilityElement(children: .combine)
.accessibilityLabel("\(displayName), \(status.accessibilityPhrase), \(statusLine), signal age \(ageText)")
.accessibilityIdentifier("largeAgentStatus-\(snapshot.kind.rawValue)")
```

## Implementation Units

- [ ] **Unit 1: 新增 HermesWingShape**

**Goal:** 提供 Hermes 用的 Canvas 绘制 logo Shape，风格对齐 `LobsterShape`。

**Requirements:** R-LOGO-2, R-HERMES-3

**Dependencies:** 无

**Files:**
- Create: `MacJarvis/Views/HermesWingShape.swift`
- Regenerate: 文件创建后需运行 `cd MacJarvis && xcodegen generate` 让 Xcode 看到新文件

**Approach:**
- View struct `HermesWingShape`，参数：`bodyColor`、`accentColor`（默认值参照 `LobsterShape` 的颜色风格）
- 内部 `Canvas` 绘制：中心一颗小宝石（菱形或圆点）+ 左右各一只极简翅膀（2-3 段 Path Curve 模拟羽片），用 `.fill` + `.stroke`
- 风格关键：硬边、极少曲线、单色填充，与 `LobsterShape` 一致
- 不接入动画；外部用 `neonGlow` 控制状态色

**Patterns to follow:**
- `MacJarvis/Views/LobsterShape.swift` 的 Canvas + Path 结构、参数化颜色接口
- `LobsterShape` 本身没有单元测试 — 视图层级保持相同模式，不为 Shape 单独写 XCTest 文件

**Test scenarios:**
- Test expectation: none — 与 `LobsterShape` 对齐，纯视觉 Shape 不写 XCTest，仅靠 Unit 2 的 XCUI 测试通过 `agentLogo-hermes` accessibility id 间接覆盖

**Verification:**
- 编译通过；Xcode 预览中可见左右双翅 + 中心元素

- [ ] **Unit 2: 重构 LargeAgentStatusStrip 三段式布局**

**Goal:** 将 Logo + 色条放左端、`statusLine` 大字搬到中部、保持右端不变。

**Requirements:** R-CENTER-1, R-LOGO-2, R-A11Y-4, R-MIN-5, R-NONINT-6

**Dependencies:** Unit 1（logo 分派需要 HermesWingShape）

**Files:**
- Modify: `MacJarvis/Views/LargeAgentStatusStrip.swift`
- Modify: `MacJarvisUITests/DashboardUITests.swift`（追加 XCUI 断言）

**Approach:**
- 在 `LargeAgentStatusStrip.swift` 同文件新增 private subview `AgentLogoView(kind:color:)`：
  - `switch kind` 渲染 `LobsterShape` 或 `HermesWingShape`
  - `frame(width: 32 * scale, height: 32 * scale)`
  - `.neonGlow(color: severityColor)` 静态光晕（不做 opacity 脉冲、不做 floating）
  - `.accessibilityHidden(true)`
  - `.accessibilityIdentifier("agentLogo-<kind>")`（供 XCUI 定位即可，与 a11y hidden 不冲突）
- 新增 private subview `PulseDot(color:isPulsing:)`：
  - 8 * scale 圆点 `Circle().fill(color)`
  - 通过 `@Environment(\.accessibilityReduceMotion)` 读取偏好；reduceMotion 或 `!isPulsing` 时走静态分支（`opacity(1.0)`）
  - 否则用 `phaseAnimator` 让 opacity 在 0.4 ↔ 1.0 之间走 1.2s easeInOut
  - `.accessibilityIdentifier("agentPulse-<kind>")`
- HStack 结构：
  ```
  [Logo 32] [4px 色条] [左 VStack: name + badge]
    Spacer(minLength: 8 * scale)
  [中部 HStack(PulseDot, Text statusLine).layoutPriority(1)]
    Spacer(minLength: 8 * scale)
  [右 VStack: SIGNAL + tokens cost, minWidth 110 * scale]
  ```
- 左 VStack 移除原 `Text(snapshot.statusLine)` 节点（detail 已搬中部）
- 中部 statusLine 字号：`AppTheme.labelFont(size: 14 * scale)` + `.lineLimit(1)` + `.truncationMode(.tail)` + `.minimumScaleFactor(0.6)` + `.accessibilityIdentifier("agentDetail-<kind>")`
- 整个 strip 保持 `.accessibilityElement(children: .combine)`；`accessibilityLabel` 更新为 "displayName, status.accessibilityPhrase, statusLine, signal age N"
- 不增加 `.onTapGesture` / `.button` / hover 修饰器（R-NONINT-6）

**Patterns to follow:**
- `CoreStatusView.swift:32` 的 LobsterShape 调用范式
- `CyberTheme.swift` 的 `NeonGlow`、`phaseAnimator` 用法
- `DashboardUITests.swift` 现有的 `largeAgentStatus-<kind>` 选择器模式

**Test scenarios:**
- 单元层（Swift 不能反射 SwiftUI 视图树；统一交给 XCUITest）：无新增 XCTest 文件
- XCUITest（在 `DashboardUITests.swift` 中追加，使用现有 fixture 机制）：
  - Happy path：默认 fixture 启动后，`statusWall` 存在 → `agentLogo-openclaw` 与 `agentDetail-openclaw` 都存在
  - Edge case：用 `mixed-openclaw-hermes` fixture，`agentLogo-hermes` 与 `agentDetail-hermes` 同时存在（验证 Hermes 分支渲染）
  - Edge case：`stuck-openclaw` fixture 下 `agentDetail-openclaw` 文本仍可见且非空（验证 statusLine 在非 RUNNING 时也展示）
  - A11y：父元素 `largeAgentStatus-openclaw` 的 `accessibilityLabel`（通过 `XCUIElement.label`）包含 displayName、status 短语、statusLine、`SIGNAL` 字样

**Verification:**
- xcodebuild build-for-testing 通过
- 现有 `LargeAgentStatusTests` / `DashboardUITests` 全部继续 pass
- 新增 4 个 XCUI 用例通过

- [ ] **Unit 3: 视觉自测 + 跑测试套件**

**Goal:** 验证三段式视觉真实呈现，且全测试套件绿色。

**Requirements:** 全部

**Dependencies:** Unit 1, Unit 2

**Files:**
- 无新增；运行已有 xcodebuild 命令

**Approach:**
- `cd MacJarvis && xcodegen generate`（**必须**，因为 Unit 1/2 新增了 `HermesWingShape.swift` 与对 `DashboardUITests.swift` 的扩展）
- `xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug clean build-for-testing`
- `xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug test-without-building`
- 视觉自测：用现有 fixture 启动 dashboard（无参或 `--page status`），人眼比对 `docs/images/status-wall.png` 与改造后效果：
  - logo 在左端 32px、色条紧贴其右
  - 中部脉冲点 + 大字 statusLine 居中可读
  - 右端 SIGNAL / tokens / cost 与改造前一致

**Test scenarios:**
- Test expectation: none — Unit 3 是验证步骤，不引入新测试代码

**Verification:**
- 全部测试通过（含 Unit 2 新增的 XCUI 用例）
- 视觉上长条中部不再为空，logo 在左、statusLine 大字在中

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| HermesWingShape 视觉与 LobsterShape 风格不协调 | 第一版完成后人眼比对，必要时再迭代曲线点位（boss 接受手动校准） |
| 中部 statusLine 字号在 800px 屏过大遮挡左右块 | `minimumScaleFactor(0.6)` + `truncationMode(.tail)` + 14 * scale 已留余量；如仍有问题，在 viewportWidth < 900 时降到 12 * scale |
| PulseDot 动画与 RUNNING 状态切换瞬间出现闪烁 | 用 `phaseAnimator` + 平滑 opacity 过渡；非 RUNNING 直接走静态 view 分支 |
| 现有 LargeAgentStatusTests 因为 view 结构变化失败 | 这些测试只测 model，不会受影响；新增 XCUI 断言用 accessibilityIdentifier，与现有选择器约定一致 |
| 长 statusLine（含 tool/path 名）截断后语义丢失 | `truncationMode(.tail)` 优先保留前缀；accessibilityLabel 仍包含全文，VoiceOver 可读完整内容 |

## Documentation / Operational Notes

- 改动仅影响 `AgentStatusWallView` 主视图组件，无 service 行为变化
- 不需要更新 README / CLAUDE.md（视觉细节微调，非架构变化）
- 若 boss 后续想换 Hermes logo 风格，只需替换 `HermesWingShape` 内部 Path 即可

## Sources & References

- Related code: `MacJarvis/Views/LargeAgentStatusStrip.swift`, `MacJarvis/Views/LobsterShape.swift`, `MacJarvis/Views/AgentStatusWallView.swift`, `MacJarvis/Theme/CyberTheme.swift`
- Related plan: `docs/plans/2026-05-29-001-feat-agent-status-wall-plan.md`
- Visual reference: `docs/images/status-wall.png`
