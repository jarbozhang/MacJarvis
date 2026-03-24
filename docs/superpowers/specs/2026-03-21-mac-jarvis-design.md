# MacJarvis — macOS AI Dashboard 设计文档

> 日期：2026-03-21
> 状态：Draft

## 1. 概述

MacJarvis 是一个 macOS 原生应用，用于：

1. 展示本地 AI 工具（Codex、Claude、Gemini）的 token 使用量
2. 监控 OpenClaw AI 网关的运行状态
3. 通过语音输入（Push-to-Talk）与 OpenClaw session 进行交互

应用针对一块 800×480 外接屏优化，检测到该屏幕时自动全屏显示为 dashboard，否则作为常规 macOS 窗口运行。视觉风格为赛博朋克/像素风。

## 2. 技术选型

| 维度 | 选择 | 备注 |
|------|------|------|
| UI 框架 | 纯 SwiftUI | macOS 14+ (Sonoma)，@Observable 要求 |
| 语音识别 | WhisperKit（本地 CoreML） | whisper-base 或 whisper-small |
| 语音合成 | AVSpeechSynthesizer | 系统原生，后续可替换 |
| OpenClaw 通信 | WebSocket | ws://127.0.0.1:18789 |
| Token 数据 | SQLite 读取 (`~/.codex/state_5.sqlite`) | 其他工具预留接口 |
| 架构模式 | 单体应用，模块化 Service 层 | @Observable + SwiftUI Environment |

## 3. 整体架构

```
┌─────────────────────────────────────────────────┐
│                  MacJarvis.app                   │
│                                                  │
│  ┌───────────┐  ┌───────────┐  ┌─────────────┐  │
│  │ TokenView │  │ ClawView  │  │  VoiceView  │  │
│  │ Dashboard │  │  Status   │  │  PTT + Chat │  │
│  └─────┬─────┘  └─────┬─────┘  └──────┬──────┘  │
│        │              │               │          │
│  ┌─────┴─────┐  ┌─────┴─────┐  ┌─────┴──────┐  │
│  │  Token    │  │ OpenClaw  │  │   Voice    │  │
│  │  Service  │  │  Service  │  │   Service  │  │
│  └─────┬─────┘  └─────┬─────┘  └──┬─────┬───┘  │
│        │              │            │     │       │
│   SQLite read   WebSocket ws://  Whisper  AVSpeech│
│  ~/.codex/db    127.0.0.1:18789  (local)  (TTS) │
│                                                  │
│  ┌──────────────────────────────────────────┐    │
│  │         DisplayManager                    │    │
│  │  检测 800×480 外接屏 → 自动全屏/窗口模式   │    │
│  └──────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

**分层：**

- **View 层**：SwiftUI 视图，赛博朋克/像素风主题
- **Service 层**：各模块业务逻辑，`@Observable` 类注入 SwiftUI Environment
- **外部接口层**：SQLite 读取、WebSocket、本地 Whisper 模型、系统 TTS

**数据流**：单向。Service 持有状态 → View 订阅渲染。用户操作通过 View → Service 方法调用。

**Service 间协调**：Service 之间不直接持有引用。跨 Service 流程（如语音识别完成后发送给 OpenClaw）由 View 层协调，保持各 Service 单一职责。

**并发模型**：Swift Concurrency（async/await + Task）。所有 Service 标记 `@MainActor`，耗时操作（Whisper 推理、SQLite 读取）通过 `Task.detached` 或 nonisolated 方法在后台执行。

## 4. 屏幕检测与布局

### 检测逻辑

`DisplayManager` 通过 `NSScreen` API 监听屏幕变化：

- 匹配条件：通过 `NSScreen.deviceDescription[NSDeviceSize]` 获取像素尺寸，匹配 800×480（允许 ±10% 偏差），同时考虑 `backingScaleFactor`
- 检测到 → 窗口移至该屏幕，全屏显示，隐藏标题栏
- 未检测到 / 拔出 → 回退常规窗口模式（可调整大小，有标题栏）
- 监听 `NSApplication.didChangeScreenParametersNotification` 支持热插拔

### 布局

```
┌── 800×480 全屏模式 ──────────────────────────────┐
│                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────┐  │
│  │  Token 用量  │  │ OpenClaw    │  │ 时间/日期 │  │
│  │  Codex: ██░  │  │ ● Running   │  │ 19:55    │  │
│  │  Claude: --  │  │ Sessions: 3 │  │ 03.21    │  │
│  │  Gemini: --  │  │ Uptime: 2h  │  │          │  │
│  └─────────────┘  └─────────────┘  └──────────┘  │
│                                                   │
│  ┌────────────────────────────────────────────┐   │
│  │  OpenClaw 对话区                            │   │
│  │  > 帮我查一下明天的天气                      │   │
│  │  🦞 明天北京晴，最高温度 22°C ...            │   │
│  ├────────────────────────────────────────────┤   │
│  │  🎤 [ 按住说话 ]                            │   │
│  └────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────┘
```

- **上半部**：三栏状态卡片（Token 用量 / OpenClaw 状态 / 时钟）
- **下半部**：对话区 + PTT 按钮
- 常规窗口模式同样布局，尺寸可调，有标题栏

### 视觉风格

- 自定义像素字体（Press Start 2P 或 VT323）
- 深色底 + 霓虹色文字（青色 #00FFFF、品红 #FF00FF、亮绿 #00FF41）
- 卡片边框像素化发光效果
- 进度条像素块风格（██░░）
- 微妙 CRT 扫描线叠加效果

## 5. 模块详细设计

### 5.1 TokenService

```swift
@Observable class TokenService {
    var tools: [ToolUsage] = []

    func fetchCodexUsage()   // 读取 ~/.codex/state_5.sqlite threads 表
    func fetchClaudeUsage()  // 预留，读取 ~/.claude/stats-cache.json
    func fetchGeminiUsage()  // 预留，读取 ~/.gemini/ session logs
}

struct ToolUsage: Identifiable {
    let id: String           // 工具名
    var name: String         // 显示名
    var inputTokens: Int?
    var outputTokens: Int?
    var totalTokens: Int?
    var cost: Double?
    var lastUpdated: Date?
    var sessionCount: Int?   // 会话数量
}
```

- Codex 先实现，Claude 和 Gemini 留接口和 UI 占位（显示 "--"）
- 定时刷新：每 60 秒自动拉取

#### Codex 数据源

SQLite 数据库 `~/.codex/state_5.sqlite`，`threads` 表结构：

```sql
-- 关键字段
id TEXT PRIMARY KEY,
title TEXT,
tokens_used INTEGER,        -- 累计 token 数
model_provider TEXT,         -- "openai"
created_at INTEGER,          -- Unix timestamp
updated_at INTEGER
```

查询示例：
```sql
-- 今日 token 总量
SELECT SUM(tokens_used) FROM threads
WHERE created_at >= strftime('%s', 'now', 'start of day');

-- 按日统计
SELECT date(created_at, 'unixepoch') as day, SUM(tokens_used)
FROM threads GROUP BY day ORDER BY day DESC LIMIT 7;
```

使用 SQLite3 C API（系统自带 `libsqlite3`）以只读模式打开，避免与 Codex 进程冲突。

### 5.2 OpenClawService

```swift
@Observable class OpenClawService {
    var status: ClawStatus = .unknown  // .running / .stopped / .error
    var sessions: [ClawSession] = []
    var messages: [ChatMessage] = []

    func connect()                     // WebSocket 连接
    func disconnect()
    func sendMessage(_ text: String)   // 向当前 session 发送
    func checkHealth()                 // `openclaw doctor`
}

enum ClawStatus { case running, stopped, error, unknown }

struct ChatMessage: Identifiable {
    let id: UUID
    var role: Role                     // .user / .assistant
    var content: String
    var timestamp: Date
}
```

- 启动时尝试 WebSocket 连接，失败标记 `.stopped`
- 心跳：每 30 秒 ping，断线自动重连（最多 3 次，间隔 1s/3s/10s）
- 健康检测备选方案：若 WebSocket 协议对接复杂度过高，M3 阶段先用 `openclaw doctor` CLI 命令轮询状态

#### OpenClaw WebSocket 协议（待确认）

OpenClaw Gateway 在 `ws://127.0.0.1:18789` 暴露 WebSocket 端点。实现时需确认：

- 消息格式：预计为 JSON（基于 Node.js 生态）
- 消息类型：chat message / status / heartbeat 的区分方式
- 发送 payload 结构：`sendMessage` 所需字段（session_id、content 等）
- 回复模式：流式（逐 token）还是完整响应
- 认证机制：是否需要 token 或 session key

**降级策略**：若 WebSocket 协议文档不足，M3/M4 阶段改用 CLI 方式：
- 状态检测：`openclaw doctor`（解析输出判断健康状态）
- 发送消息：`openclaw agent --message "text"`（通过 Process API 调用）
- 此方案功能等价，只是延迟略高

### 5.3 VoiceService

```swift
@Observable class VoiceService {
    var isRecording: Bool = false
    var isTranscribing: Bool = false
    var isSpeaking: Bool = false
    var transcript: String = ""

    func startRecording()              // PTT 按下，AVAudioEngine 开始
    func stopAndTranscribe() async     // PTT 松开，Whisper 转文字
    func speak(_ text: String)         // AVSpeechSynthesizer 播报
}
```

- WhisperKit：Apple 原生 Swift 封装，CoreML 加速
- 模型：默认 `whisper-base`（~140MB），可选 `whisper-small`（~460MB）
- 模型管理：WhisperKit 内置从 HuggingFace 下载，使用默认缓存路径（`~/Library/Caches/com.argmax.whisperkit/`）
- 离线场景：模型下载后完全离线工作；未下载且无网络时 PTT 不可用，提示"需要首次联网下载模型"
- 录音：16kHz mono PCM
- TTS：`AVSpeechSynthesizer`，中文用 `zh-CN` voice
- TTS 播报中用户再按 PTT → 打断播报，开始新录音
- 音频会话：录音和播放共用 AVAudioEngine，PTT 打断 TTS 时先停止播放再切换到录音模式

### 5.4 DisplayManager

```swift
@Observable class DisplayManager {
    var isExternalScreenConnected: Bool = false
    var targetScreen: NSScreen?

    func startMonitoring()             // 监听屏幕变化通知
    func stopMonitoring()
    func moveWindowToTarget()          // 移动窗口并全屏
}
```

- 监听 `NSApplication.didChangeScreenParametersNotification`
- 匹配：通过 `NSScreen.deviceDescription[NSDeviceSize]` 获取像素尺寸，±10% 偏差容忍

## 6. 交互流程

### 语音交互完整流程

```
用户按住 PTT ──→ VoiceService.startRecording()
    │                    │
    │              AVAudioEngine 录音
    │                    │
用户松开 PTT ──→ VoiceService.stopAndTranscribe()
                         │
                   WhisperKit 推理（后台线程）
                         │
                   transcript 就绪
                         │
                 OpenClawService.sendMessage(transcript)
                         │
                   WebSocket 发送
                         │
                 OpenClaw 返回回复
                         │
               ┌─────────┴─────────┐
               │                   │
         UI 显示文字         VoiceService.speak(reply)
         （立即）            （TTS 播报）
```

### PTT 交互状态

| 阶段 | UI 表现 |
|------|---------|
| 按住录音 | 录音波形动画 + "正在聆听..." |
| 松开识别 | "识别中..." + 加载动画 |
| 识别完成 | 文字出现在对话区，自动发送 |
| 等待回复 | "思考中..." |
| 收到回复 | 文字滚动显示 + TTS 播报 |

PTT 触发方式：app 内聚焦时支持键盘快捷键（如空格键）。外接屏场景下 app 可能不在焦点，后续可考虑通过辅助功能权限实现系统级全局热键。

## 7. 错误处理

| 场景 | 处理 |
|------|------|
| OpenClaw 未运行 | 状态卡片红色 "● Offline"，PTT 按钮置灰 |
| WebSocket 断连 | 自动重连 3 次（1s/3s/10s），失败标记 Offline |
| Whisper 模型未加载 | 首次启动后台下载，显示进度条；加载期间 PTT 不可用 |
| Codex SQLite 读取失败 | Token 面板对应项显示 "--" |
| 麦克风权限未授予 | 弹出系统请求，未授权则显示 "需要麦克风权限" |
| TTS 中再按 PTT | 打断播报，开始新录音 |

## 8. App 生命周期

```
启动 ──→ 加载 Whisper 模型（后台）
    ├──→ DisplayManager 检测屏幕
    ├──→ OpenClawService 尝试 WebSocket 连接
    └──→ TokenService 首次数据拉取
         │
    进入主循环：定时刷新 Token（60s）+ WebSocket 心跳（30s）
         │
    退出 ──→ 断开 WebSocket，释放音频资源
```

## 9. 依赖

| 依赖 | 用途 | 引入方式 |
|------|------|----------|
| WhisperKit | 本地语音识别 | Swift Package Manager |
| 像素字体 (Press Start 2P / VT323) | 赛博朋克 UI | Bundle 内嵌 |

无其他第三方依赖。WebSocket 使用系统 `URLSessionWebSocketTask`。SQLite 使用系统 `libsqlite3`。

## 10. 权限与分发

| 权限 | 用途 | 备注 |
|------|------|------|
| `NSMicrophoneUsageDescription` | 语音录音 | Info.plist 声明 |
| 网络访问（Outgoing） | WebSocket 连接 OpenClaw | App Sandbox 允许 |
| 文件系统读取 | 读取 ~/.codex/state_5.sqlite | 需要用户目录访问 |

**分发方式**：Developer ID 签名 + 直接分发（非 App Store）。原因：需要读取用户目录下第三方工具的数据文件。App Sandbox 关闭（`com.apple.security.app-sandbox = false`）。

**字体许可**：Press Start 2P / VT323 均为 OFL（Open Font License），需 Bundle 内附许可文件。回退字体：Menlo。

## 11. Milestones

| # | Milestone | 范围 | 验收标准 |
|---|-----------|------|----------|
| M1 | 骨架 + 屏幕检测 | Xcode 项目、SwiftUI 骨架、DisplayManager、像素风主题基础 | 可编译运行；接入 800×480 屏幕自动全屏；拔出后回退窗口模式；像素字体和霓虹配色可见 |
| M2 | Token Dashboard | TokenService + Codex SQLite 集成 + 状态卡片 UI | 卡片显示 Codex 今日 token 用量和 session 数；60 秒自动刷新；Claude/Gemini 显示 "--" 占位 |
| M3 | OpenClaw 状态监控 | CLI 连接（`openclaw doctor`）、健康检测、状态卡片；WebSocket 作为可选升级 | OpenClaw 运行时显示绿色 Running + session 数；未运行显示红色 Offline；支持自动重连 |
| M4 | 语音输入 + 对话 | WhisperKit 集成、PTT 录音、OpenClaw 消息收发、对话 UI | 按住 PTT 录音 → 松开识别文字 → 发送 OpenClaw → 回复显示在对话区；Whisper 模型首次自动下载 |
| M5 | TTS + 打磨 | AVSpeech 播报、错误处理完善、动画细节、CRT 效果 | OpenClaw 回复自动 TTS 播报；TTS 中按 PTT 可打断；CRT 扫描线效果；录音波形动画 |
| M6 | 扩展预留 | Claude/Gemini token 采集接口实现 | Claude 读取 stats-cache.json 显示 token 用量；Gemini 读取 session logs 显示用量 |

Milestone 之间为线性依赖，M1 → M2 → M3 → M4 → M5 → M6。
