# MacJarvis UI 重写设计文档

## 概述

将 MacJarvis 的 Dashboard UI 从当前的"顶部三卡片 + 底部聊天"布局，重写为 HTML 设计稿中的三列终端风格布局，保留所有现有功能。

## 用户确认的决策

| 问题 | 决策 |
|------|------|
| 底部导航栏 Tab 切换 | 纯装饰，不切换页面 |
| 日志终端 vs ChatView | 复用 ChatView 数据，终端风格渲染；NEW COMMAND 按钮触发输入 |
| CPU/Temp 数据 | 接入真实 macOS 系统数据 |
| 时钟位置 | 合并到 Header 右侧 |
| 龙虾图标 | SwiftUI Path 代码实现 |
| 实施方案 | 方案二：删除所有现有 Views，从零重写 |
| Token 配额/百分比 | 分母为用户可配置的自定义预算值（Settings 里设置），真实数据无 quota |

## 布局结构

```
800×480 固定窗口
┌─────────────────────────────────────────────────────┐
│ Header: [LOGO] SYS.MONITOR.v4  |  位置  时钟  设置  │  40pt
├──────────┬──────────┬───────────────────────────────┤
│ 左列 3/12│ 中列 3/12│ 右列 6/12                      │
│          │          │                               │
│ Core     │ CODEX    │ Logs_Live 终端日志              │
│ Status   │ 卡片     │ (ChatView 数据, 终端风格渲染)    │
│ 龙虾图标  │          │                               │
│ OpenClaw │ GEMINI   │                               │
│ 状态     │ 卡片     │                               │
│ Signal条 │          │                               │
│          │ CLAUDE   │                               │
│──────────│ 卡片     │───────────────────────────────│
│ CPU|Temp │          │ [NEW COMMAND] 按钮             │
└──────────┴──────────┴───────────────────────────────┤
│ 底部导航栏: OpenClaw | Codex | Gemini | Claude (装饰) │  48pt
└─────────────────────────────────────────────────────┘
```

## 文件变更清单

### 删除文件
- `Views/DashboardView.swift`
- `Views/TokenCardView.swift`
- `Views/ClawStatusCardView.swift`
- `Views/ClockCardView.swift`
- `Views/ChatView.swift`
- `Views/PTTButton.swift`
- `Views/SettingsView.swift`

### 新建 Views
| 文件 | 职责 |
|------|------|
| `Views/DashboardView.swift` | 主布局容器：Header + 三列 Grid + BottomNavBar |
| `Views/HeaderView.swift` | 顶部栏：Logo/标题、位置标签、实时时钟、设置按钮 |
| `Views/CoreStatusView.swift` | 左列上部：龙虾图标 + OpenClaw 状态 + 运行时间 + Signal 进度条 |
| `Views/HardwareStatsView.swift` | 左列下部：CPU Load + Temperature 两格 |
| `Views/TokenColumnView.swift` | 中列：三个 Token 卡片垂直排列（CODEX/GEMINI/CLAUDE） |
| `Views/TokenCard.swift` | 单个 Token 卡片：名称、版本、百分比、用量、像素进度条 |
| `Views/TerminalLogView.swift` | 右列：终端风格日志渲染 + NEW COMMAND 按钮 |
| `Views/BottomNavBar.swift` | 底部固定导航栏，四个 Tab（纯装饰） |
| `Views/LobsterShape.swift` | 龙虾图标 SwiftUI Path |
| `Views/SettingsView.swift` | 设置弹窗：OpenClaw host/port + Token 每日预算配置 + 新主题风格 |

### 改造文件
| 文件 | 变更 |
|------|------|
| `Theme/CyberTheme.swift` | 新配色体系、Space Grotesk 字体、0 圆角、新修饰器 |
| `Theme/CRTEffect.swift` | 保留扫描线，新增 pixel-grid 背景 |
| `MacJarvisApp.swift` | 注入 SystemMonitorService，移除不再需要的环境 |

### 新建 Service
| 文件 | 职责 |
|------|------|
| `Services/SystemMonitorService.swift` | `@Observable @MainActor`，采集 CPU 使用率和 CPU 温度 |

## 主题系统 (CyberTheme.swift)

### 配色
```
primary    = #00FFC2  (薄荷绿，替代原 cyan #00FFFF)
secondary  = #FFABF3  (粉色，替代原 magenta #FF00FF)
tertiary   = #C3F400  (黄绿，新增)
surface    = #131318  (替代原 background #000000)
surfaceContainer      = #1F1F24
surfaceContainerHigh  = #2A292F
surfaceContainerLow   = #1B1B20
surfaceContainerLowest= #0E0E13
onSurface  = #E4E1E9  (主文字色)
onSurfaceVariant = #B9CBC1 (次文字色)
outlineVariant   = #3A4A43 (边框色)
```

### 字体
- 主字体：Space Grotesk（需添加字体文件到 Resources/Fonts/）
- 保留系统 monospaced 作为终端日志字体
- 删除 PressStart2P 像素字体依赖

### 修饰器
- `pixelCard()` → 改为 0 圆角 + 新配色边框
- `neonGlow()` → 保留，改用新 primary 色
- 新增 `pixelGrid()` — 点阵背景图案
- 新增 `pixelProgressBar(value:color:segments:)` — 分段式像素进度条

## 各组件详细设计

### HeaderView
- 高度 40pt，`surfaceContainerHigh` 80% 透明度背景
- 左侧：terminal 图标 + "[SYS.MONITOR.v4.LND]" 文字，primary 色
- 右侧：位置标签 "Neo-Tokyo-01" + 实时时钟 HH:mm:ss + 设置齿轮图标
- 下边框 primary 20% 透明度

### CoreStatusView
- 占左列上部 flex-1 空间
- 中心：LobsterShape 64×64，primary 色 + 发光效果 + 脉冲动画
- 下方："OPENCLAW ACTIVE/OFFLINE" 状态文字
- 运行时间计数器：需在 OpenClawService 新增 `connectedAt: Date?` 属性，连接成功时记录，断开时清空。View 层用 Timer 每秒计算 `now - connectedAt` 格式化为 `DDD:HH:MM:SS`。未连接时显示 `---:--:--:--`
- Signal 进度条：tertiary 色，映射规则：
  - `running` → 98%（模拟信号强度，实际无真实信号数据）
  - `stopped` → 0%
  - `error` → 15%
  - `unknown` → 0%

### HardwareStatsView
- 左列下部，2 列 Grid
- 左格：CPU Load 标签 + 百分比数值，顶部 primary 色边线
- 右格：Temp 标签 + 温度数值，顶部 secondary 色边线

### TokenCard
- 左侧 2px 边框，颜色随工具类型变化（CODEX=primary, GEMINI=secondary, CLAUDE=tertiary）
- 顶部：工具名 + 版本标签 + SF Symbol 图标
  - 版本标签为硬编码装饰文字：CODEX="v4.2-STABLE", GEMINI="FLASH-ULTRA", CLAUDE="OPUS-DIRECT"
  - SF Symbol：CODEX=`chevron.left.forwardslash.chevron.right`, GEMINI=`memorychip`, CLAUDE=`brain.head.profile`
- 中部：百分比大字 + "82k/100k" 用量文字
  - 数据来源：TokenService 读取真实本地数据（Codex=SQLite, Claude=stats-cache.json, Gemini=session文件扫描）
  - 百分比计算：`totalTokens / userBudget * 100`，分母来自用户在 Settings 中设置的自定义预算值
  - 预算存储在 SettingsService 中，通过 UserDefaults 持久化：
    - `codexDailyBudget: Int`（默认 100_000）
    - `claudeDailyBudget: Int`（默认 500_000）
    - `geminiDailyBudget: Int`（默认 1_000_000）
  - 若 `totalTokens` 为 nil（如 Gemini 无 token 数据），显示 `messageCount` 替代，格式为 "3 msg"，百分比隐藏，进度条不显示
  - 若用户预算设为 0，等同于不设上限，不显示百分比，只显示绝对数值
- 底部：10 段像素进度条，填充段用工具色，空段用暗色

### TerminalLogView
- `surfaceContainerLowest` 背景，monospaced 字体
- 顶部：绿色脉冲圆点 + "Logs_Live :: Extended_Readout_v4"
- 内容区：ScrollView 渲染 ChatMessage 数据
  - user 消息：`[HH:mm:ss] >> USER: {content}`
  - assistant 消息：`[HH:mm:ss] >> CLAW: {content}`，primary 色
  - 新消息自动滚动到底部
- 底部：NEW COMMAND 按钮（primary 背景 + surface 文字）
  - 点击展开输入框（TextField + 发送按钮）
  - 或使用 Sheet/Popover 弹出输入界面

### BottomNavBar
- 固定底部，高度 48pt（HTML 80px 过大，缩小以留更多内容空间）
- 4 个 Tab：OpenClaw（龙虾图标）、Codex、Gemini、Claude
- OpenClaw Tab 高亮（primary 背景 + 深色文字）
- 其他三个 50% 透明度，无交互

### LobsterShape
- SwiftUI Path，从 HTML SVG 的 path data 转换
- 包含：身体、两只钳子、两根触须（红色）、两只眼睛
- 支持 `foregroundColor` 设置主体颜色

## SystemMonitorService

```swift
@Observable @MainActor
final class SystemMonitorService {
    var cpuUsage: Double = 0.0      // 0-100
    var cpuTemperature: Double = 0.0 // 摄氏度

    func startMonitoring()  // 启动 5s 间隔定时器
    func stopMonitoring()
}
```

### CPU 使用率
- 使用 `host_processor_info()` Mach API 获取每核 CPU ticks
- 计算 (user + system + nice) / total 得到使用率百分比

### CPU 温度
- 使用 Apple SMC (System Management Controller) 读取 `TC0P` 键值
- 通过 IOKit `IOServiceOpen` → `IOConnectCallStructMethod` 访问 AppleSMC
- 如果读取失败（沙盒限制等），fallback 显示 "--°C"

## 数据流

```
SystemMonitorService ──→ HardwareStatsView
TokenService ──→ TokenColumnView → TokenCard
OpenClawService ──→ CoreStatusView (状态/时长)
                ──→ TerminalLogView (消息数据)
SettingsService ──→ SettingsView (OpenClaw host/port + Token 预算配置)
               ──→ TokenColumnView (读取各工具的 dailyBudget 作为百分比分母)
VoiceService ──→ TerminalLogView (PTT 功能保留在 NEW COMMAND 交互中)
```

## 字体资源

需要下载 Space Grotesk 字体文件（OFL 开源协议）：
- SpaceGrotesk-Regular.ttf
- SpaceGrotesk-Bold.ttf
- SpaceGrotesk-Medium.ttf

放置于 `MacJarvis/Resources/Fonts/`，在 Info.plist 注册。

## PTT (Push-to-Talk) 处理

当前 PTTButton 被删除，但语音功能需保留：
- NEW COMMAND 按钮区域集成 PTT 功能
- 长按 NEW COMMAND 按钮触发录音
- 短按展开文字输入（TextField 替换按钮位置，带取消按钮）
- 录音状态在按钮上显示（颜色变红 + 文字变为 "LISTENING..."）
- 录音结束后转写文本自动填入输入框，用户可编辑后手动发送
- 转写过程中按钮显示 "TRANSCRIBING..."（secondary 色）

## OpenClawService 改动

需在 `OpenClawService` 中新增：
```swift
var connectedAt: Date?  // connect 成功时设为 Date.now，disconnect 时设为 nil
```
- 在 `connect()` 方法中 status 变为 `.running` 时赋值
- 在 `disconnect()` 和连接失败时清空

## 配置文件改动

### Info.plist
- 更新 `ATSApplicationFontsPath` 指向新字体目录
- 注册 SpaceGrotesk-Regular.ttf / SpaceGrotesk-Bold.ttf / SpaceGrotesk-Medium.ttf
- 移除 PressStart2P-Regular.ttf 注册

### project.yml
- Resources 配置确认包含新字体文件路径

## 测试影响

现有 UI 相关测试不受影响（测试针对 Service/Model 层）。
OpenClawService 新增 `connectedAt` 属性不影响现有测试（默认 nil）。
