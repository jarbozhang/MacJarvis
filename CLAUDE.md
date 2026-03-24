# MacJarvis — macOS AI Dashboard

## 项目概述

MacJarvis 是一个 macOS 原生 SwiftUI 应用，用于：
1. 展示本地 AI 工具（Codex、Claude、Gemini）的 token 使用量
2. 监控 OpenClaw AI 网关的运行状态
3. 通过语音输入（Push-to-Talk）与 OpenClaw 进行交互

针对 800×480 外接屏优化，赛博朋克/像素风视觉风格。

## 技术栈

- **UI**: 纯 SwiftUI, macOS 14+ (Sonoma)
- **状态管理**: `@Observable` macro + SwiftUI Environment
- **语音识别**: WhisperKit (SPM, CoreML 本地推理)
- **语音合成**: AVSpeechSynthesizer (zh-CN)
- **OpenClaw 通信**: URLSessionWebSocketTask
- **数据存储**: SQLite3 C API (Codex), JSON (Claude/Gemini)
- **项目管理**: XcodeGen (`project.yml`)

## 架构模式

- 所有 Service 标记 `@Observable @MainActor`
- 耗时操作通过 `Task.detached` 或 `nonisolated static` 方法在后台执行
- Service 之间不直接持有引用，跨 Service 流程由 View 层协调
- 数据流单向：Service 持有状态 → View 订阅渲染

## 目录结构

```
MacJarvis/
├── project.yml              # XcodeGen 配置
├── MacJarvis/
│   ├── MacJarvisApp.swift   # App 入口，注入所有 Service
│   ├── Info.plist           # CFBundleIdentifier, 麦克风权限
│   ├── MacJarvis.entitlements
│   ├── Services/
│   │   ├── DisplayManager.swift     # 800×480 外接屏检测 + 全屏切换
│   │   ├── TokenService.swift       # Codex/Claude/Gemini token 采集
│   │   ├── OpenClawService.swift    # WebSocket 连接、心跳、自动重连
│   │   ├── SettingsService.swift    # UserDefaults 持久化 (OpenClaw host/port)
│   │   └── VoiceService.swift       # WhisperKit STT + AVSpeech TTS + 音频录制
│   ├── Models/
│   │   ├── ToolUsage.swift          # Token 使用量数据模型
│   │   ├── ChatMessage.swift        # 聊天消息 (role: user/assistant)
│   │   └── ClawStatus.swift         # OpenClaw 状态枚举
│   ├── Views/
│   │   ├── DashboardView.swift      # 主布局 (顶部卡片 + 底部聊天)
│   │   ├── TokenCardView.swift      # Token 使用量卡片
│   │   ├── ClawStatusCardView.swift # OpenClaw 状态卡片
│   │   ├── ClockCardView.swift      # 时钟卡片
│   │   ├── ChatView.swift           # 消息列表 + 输入 + PTT
│   │   ├── PTTButton.swift          # Push-to-Talk 按钮 + 波形动画
│   │   └── SettingsView.swift       # 设置面板 (OpenClaw host/port)
│   ├── Theme/
│   │   ├── CyberTheme.swift         # 颜色/字体/修饰器 (neonGlow, pixelCard)
│   │   └── CRTEffect.swift          # CRT 扫描线效果
│   └── Resources/
│       ├── Assets.xcassets
│       └── Fonts/                   # PressStart2P 像素字体
└── MacJarvisTests/
    ├── DisplayManagerTests.swift    # 屏幕匹配逻辑 (5 tests)
    ├── ChatMessageTests.swift       # 消息模型 + ClawStatus (4 tests)
    ├── SettingsServiceTests.swift   # 设置持久化 (5 tests)
    ├── OpenClawServiceTests.swift   # WebSocket 连接逻辑 (5 tests)
    ├── VoiceServiceTests.swift      # 语音服务状态 (3 tests)
    ├── TokenServiceTests.swift      # Codex SQLite 查询 (unknown)
    ├── TokenServiceClaudeTests.swift # Claude JSON 解析 (4 tests)
    └── TokenServiceGeminiTests.swift # Gemini 日志扫描 (3 tests)
```

## 构建和测试

```bash
# 生成 Xcode 项目 (首次或 project.yml 变更后)
cd MacJarvis && xcodegen generate

# 构建
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build

# 测试 (两步: build-for-testing 然后 test-without-building 避免 CodeSign 问题)
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug clean build-for-testing
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug test-without-building
```

## 外部数据源

| 工具 | 数据路径 | 格式 | 读取方式 |
|------|----------|------|----------|
| Codex | `~/.codex/state_5.sqlite` | SQLite WAL | `sqlite3_open_v2` with `?immutable=1` URI |
| Claude | `~/.claude/stats-cache.json` | JSON | `JSONSerialization`, 按 `dailyActivity[].date` 过滤今日 |
| Gemini | `~/.gemini/tmp/*/chats/session-*.json` | JSON files | `FileManager` 扫描文件名前缀匹配今日日期 |

## 关键设计决策

- **OpenClaw 不自动连接**: 启动时不连接 WebSocket，用户通过 Settings 面板手动 RECONNECT
- **SQLite immutable URI**: Codex 数据库使用 `?immutable=1` 避免 WAL 文件访问冲突
- **Whisper 后台推理**: `Task.detached` 运行推理避免阻塞 MainActor
- **TTS 自动播报**: assistant 消息自动 TTS，PTT 按下可打断
- **OpenClaw 支持本地和远程**: 默认 127.0.0.1:18789，可配置为 100.67.1.75 (Tailscale)

## 已知注意事项

- **SourceKit 误报**: 构建期间 SourceKit 经常报 "Cannot find X in scope" 假阳性，只信任 xcodebuild 输出
- **xcodeproj 在 .gitignore 中**: `MacJarvis.xcodeproj` 由 XcodeGen 生成，不纳入版本控制
- **测试 CodeSign 问题**: 命令行 `xcodebuild test` 可能遇到 CodeSign 失败，使用两步构建解决

## Milestone 状态

- [x] M1: 骨架 + 屏幕检测
- [x] M2: Token Dashboard (Codex)
- [x] M3: OpenClaw 状态监控
- [x] M4: 语音输入 + 对话
- [x] M5: TTS + 打磨 (自动播报, 波形动画, CRT 效果)
- [x] M6: 扩展预留 (Claude/Gemini token 采集)
