---
date: 2026-04-08
topic: responsive-display-layout
---

# 自适应显示器布局

## Problem Frame

MacJarvis 当前仅支持 800x480 和 1280x720 两种分辨率匹配，在其他尺寸的显示器上窗口固定为 800x480 居中显示。字体和按钮大小全部硬编码，高分屏上显得过小。

## Requirements

**全屏模式**
- R1. 所有宽度 ≤1024 的外接显示器自动进入全屏模式（无边框、隐藏 dock/菜单栏）
- R2. 全屏模式下内容自动适配实际屏幕分辨率

**标准窗口模式**
- R3. 宽度 >1024 的显示器使用标准窗口模式（有标题栏，不全屏）
- R4. 窗口大小自动适配屏幕分辨率（按比例放大，不再固定 800x480）

**缩放与字体**
- R5. 字体大小根据窗口宽度比例缩放（基准 800px 宽度对应当前字体大小）
- R6. 按钮和交互元素同步缩放，保持可用性

## Success Criteria

- 在 800x480 外接屏上全屏显示（现有行为保持）
- 在 1024x600 外接屏上全屏显示
- 在 1440p/2K 显示器上窗口模式运行，字体按钮明显大于当前
- 在 MacBook 内置屏上正常窗口运行

## Scope Boundaries

- 不做用户手动缩放控件
- 不改变布局结构（三栏布局保持不变）
- 不做响应式断点切换（不会隐藏/重排列）

## Key Decisions

- **≤1024 全屏，>1024 窗口**: 以 1024 为分界点，小屏全屏大屏窗口
- **比例缩放而非断点**: 字体/间距用缩放因子统一处理，不做多套尺寸

## Outstanding Questions

### Deferred to Planning
- [Affects R4][Technical] 窗口模式下的具体窗口大小算法（屏幕宽度的百分比？固定比例？）
- [Affects R5][Technical] 缩放因子的具体实现方式（Environment 注入 vs AppTheme 静态方法参数）

## Next Steps

→ `/ce:plan` for structured implementation planning
