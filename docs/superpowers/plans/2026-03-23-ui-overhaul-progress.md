# UI Overhaul 实施进度

**Plan:** `docs/superpowers/plans/2026-03-23-ui-overhaul-plan.md`
**Spec:** `docs/superpowers/specs/2026-03-23-ui-overhaul-design.md`
**更新时间:** 2026-03-23 14:30

---

## 已完成的 Tasks

### Task 1: Download Space Grotesk Font Files ✅
- SpaceGrotesk-Regular.ttf, SpaceGrotesk-Medium.ttf, SpaceGrotesk-Bold.ttf 已生成（从 variable font 用 fonttools 生成 static 实例）
- PostScript 名称已修正为正确值
- PressStart2P-Regular.ttf 已删除
- 文件位于 `MacJarvis/Resources/Fonts/`

### Task 2: Rewrite CyberTheme.swift ✅
- 完整重写：新配色（primary/secondary/tertiary + surface 层级）
- 字体切换到 SpaceGrotesk 系列
- NeonGlow modifier 和 PixelProgressBar 已更新
- 旧的 PixelCard modifier 已移除

### Task 3: Update CRTEffect.swift ✅
- 末尾追加了 PixelGridBackground 视图和 .pixelGrid() modifier

### Task 4: Extend SettingsService ✅
- 添加了 codexDailyBudget、claudeDailyBudget、geminiDailyBudget 属性
- 含 didSet 持久化 + init() 恢复逻辑

### Task 5: Add connectedAt to OpenClawService ✅
- 添加了 `var connectedAt: Date?`
- 所有 status = .running 处设置 connectedAt = Date.now
- 所有 disconnect/error/stopped 路径设置 connectedAt = nil（共 4 处）

### Task 6: Create SystemMonitorService ✅
- 新建文件，含 CPU 使用率（host_statistics）和 SMC 温度读取
- 5 秒定时刷新

### Task 7: Delete old Views & create LobsterShape ✅
- 删除了 7 个旧 View 文件
- 创建了 LobsterShape.swift（Canvas 绘制）

### Task 8: Create HeaderView ✅
### Task 9: Create CoreStatusView ✅
### Task 10: Create HardwareStatsView ✅
### Task 11: Create TokenCard & TokenColumnView ✅
### Task 12: Create TerminalLogView ✅
### Task 13: Create BottomNavBar ✅
### Task 14: Create SettingsView ✅
### Task 15: Create DashboardView ✅
### Task 16: Update MacJarvisApp.swift ✅
- 添加了 SystemMonitorService 注入和 startMonitoring() 调用

---

## 进行中的 Tasks

### Task 17: Build verification & fix 🔧
**状态：首次构建失败，已修复 1 个 error，还需重新构建验证**

已修复的问题：
1. ✅ `TerminalLogView.swift:107` — `stopAndTranscribe()` 是 async 方法，已包裹在 `Task { await ... }` 中
2. ✅ `TokenCard.swift:11` — 未使用变量 `tokens` 改名为 `total`（warning 修复）

待做：
- 重新运行 `xcodegen generate && xcodebuild build` 验证是否还有其他编译错误
- 如有错误继续修复直到 BUILD SUCCEEDED
- 运行测试验证无回归

### Task 18: Visual verification ❌
- 未开始

---

## 未提交的文件变更

所有变更均未 git commit。以下是变更文件清单：

**新建文件：**
- `MacJarvis/Resources/Fonts/SpaceGrotesk-Regular.ttf`
- `MacJarvis/Resources/Fonts/SpaceGrotesk-Medium.ttf`
- `MacJarvis/Resources/Fonts/SpaceGrotesk-Bold.ttf`
- `MacJarvis/Services/SystemMonitorService.swift`
- `MacJarvis/Views/LobsterShape.swift`
- `MacJarvis/Views/HeaderView.swift`
- `MacJarvis/Views/CoreStatusView.swift`
- `MacJarvis/Views/HardwareStatsView.swift`
- `MacJarvis/Views/TokenCard.swift`
- `MacJarvis/Views/TokenColumnView.swift`
- `MacJarvis/Views/TerminalLogView.swift`
- `MacJarvis/Views/BottomNavBar.swift`
- `MacJarvis/Views/DashboardView.swift`
- `MacJarvis/Views/SettingsView.swift`
- `docs/superpowers/specs/2026-03-23-ui-overhaul-design.md`
- `docs/superpowers/plans/2026-03-23-ui-overhaul-plan.md`

**修改文件：**
- `MacJarvis/Theme/CyberTheme.swift` (完整重写)
- `MacJarvis/Theme/CRTEffect.swift` (末尾追加)
- `MacJarvis/Services/SettingsService.swift` (添加 budget 属性)
- `MacJarvis/Services/OpenClawService.swift` (添加 connectedAt)
- `MacJarvis/MacJarvisApp.swift` (注入 SystemMonitorService)

**删除文件：**
- `MacJarvis/Resources/Fonts/PressStart2P-Regular.ttf`
- `MacJarvis/Views/ClawStatusCardView.swift`
- `MacJarvis/Views/ClockCardView.swift`
- `MacJarvis/Views/ChatView.swift` (旧版)
- `MacJarvis/Views/PTTButton.swift`
- `MacJarvis/Views/TokenCardView.swift` (旧版)

---

## 新 Session 恢复步骤

1. 读取本文件了解进度
2. 运行 `cd /Users/jiabozhang/Documents/Develop/vibecoding/MacJarvis && xcodegen generate`
3. 运行 `xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build 2>&1 | grep -E "error:|BUILD"` 检查编译
4. 修复所有编译错误直到 BUILD SUCCEEDED
5. 运行测试
6. 视觉验证
7. Git commit
