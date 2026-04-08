---
date: 2026-04-08
topic: embedded-terminal-tabs
---

# 嵌入式终端 Tab — Codex / Gemini / Claude

## Problem Frame

MacJarvis 底部导航栏的 Codex、Gemini、Claude 三个 tab 当前只是占位，无法交互。用户希望点击这些 tab 后能直接在 app 内使用对应 AI 工具的 TUI（命令行界面），无需切换到外部终端。

## Requirements

**Tab 切换**
- R1. 点击 Codex/Gemini/Claude tab 时，右侧内容区域（当前 TerminalLog 位置）切换为对应的嵌入终端
- R2. 左侧卡片区（CoreStatus + HardwareStats）和中间 Token 列始终保持可见
- R3. 点击 OPENCLAW tab 切换回当前的 TerminalLog 聊天界面

**终端进程**
- R4. 各 tab 的终端进程在首次点击时懒启动
- R5. 启动后进程持续运行，tab 切换只是显示/隐藏，不重启进程
- R6. app 退出时终止所有终端进程

**启动命令**
- R7. Codex tab 启动 `codex --full-auto`（或等效的自动确认参数）
- R8. Gemini tab 启动 `gemini`（带自动确认参数）
- R9. Claude tab 启动 `claude --dangerously-skip-permissions`

**终端渲染**
- R10. 终端支持完整的 ANSI 颜色和 TUI 渲染（各工具的 TUI 都有复杂的界面）
- R11. 终端外观使用默认样式，不强制匹配 MacJarvis 主题
- R12. 支持键盘输入和基本交互（输入文字、回车、Ctrl+C 等）

## Success Criteria

- 点击 Codex tab 后，右侧区域展示一个可交互的终端，其中 `codex --full-auto` 已在运行
- 可以在嵌入终端中正常与 AI 工具对话
- 切换到其他 tab 再切回来，终端会话完整保留
- 所有三个 AI 工具的 TUI 能正确渲染（颜色、布局、滚动）

## Scope Boundaries

- 不做终端主题定制（不匹配赛博朋克风格）
- 不做命令可配置（硬编码三个工具的启动命令）
- 不做终端分屏/多窗口
- 不做终端内的文件传输或剪贴板高级集成
- 不自己实现终端模拟器——使用开源库

## Key Decisions

- **使用 SwiftTerm 库**: 成熟的 Swift 终端模拟器，支持 PTY + ANSI，可通过 NSViewRepresentable 嵌入 SwiftUI
- **懒启动 + 持续运行**: 避免启动开销和上下文丢失
- **替换右侧区域而非全屏**: 保持 dashboard 监控功能始终可见
- **默认终端样式**: TUI 工具自身的配色方案通常已经很好，强制覆盖反而会冲突

## Dependencies / Assumptions

- SwiftTerm 作为 SPM 依赖引入（需要确认新增外部依赖）
- `codex`、`gemini`、`claude` CLI 工具已安装在用户 PATH 中
- 各工具的自动确认参数需要在实现时确认具体 flag

## Outstanding Questions

### Deferred to Planning
- [Affects R7-R9][Needs research] Codex 和 Gemini 的具体自动确认参数是什么
- [Affects R10][Needs research] SwiftTerm 的 SwiftUI 集成方式和 API
- [Affects R4][Technical] 终端进程管理的最佳实践（Process + PTY 生命周期）
- [Affects R12][Technical] 键盘焦点管理——当嵌入终端激活时，如何确保键盘输入到达终端而非 SwiftUI

## Next Steps

→ `/ce:plan` for structured implementation planning
