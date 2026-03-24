# MacJarvis

MacJarvis 是一个原生 macOS SwiftUI dashboard，用来把本地 AI 工具用量、OpenClaw 对话入口和机器状态集中展示在一块 800×480 外接小屏上。

当前界面已经是三栏 cockpit 布局：

- 左列：OpenClaw 状态、运行时长、磁盘占用
- 中列：Codex / Gemini / Claude 用量卡片
- 右列：终端风格消息流、文本输入、Push-to-Talk

## 当前能力

- Codex / Claude / Gemini 本地使用数据采集
- OpenClaw 网关连接、状态检测和流式聊天
- Push-to-Talk 语音输入，WhisperKit 本地转写
- CPU / 内存 / 磁盘监控
- OpenClaw 连接参数和每日预算设置持久化
- 针对 800×480 小屏优化的赛博终端风 UI

## 技术栈

- SwiftUI, macOS 14+
- `@Observable` + Environment 状态注入
- WhisperKit 本地语音识别
- AVSpeechSynthesizer TTS 能力
- SQLite3 / JSON 文件直接读取本地工具数据
- XcodeGen 管理工程文件

## 本地数据源

MacJarvis 不走云端统计接口，直接读取本机数据：

- Codex: `~/.codex/state_5.sqlite`
- Claude: `~/.claude/plugins/claude-hud/.usage-cache.json`
- Gemini: `~/.gemini/tmp/*/chats/session-*.json`

说明：

- Codex 当前展示的是“今日总 token + 会话数”
- Claude 当前展示的是 `claude-hud` 缓存里的 5 小时用量百分比和套餐名
- Gemini 当前只统计今日 session 数，不显示真实 token

## 构建

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build
```

测试：

```bash
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug clean build-for-testing
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug test-without-building
```

## OpenClaw 配置

MacJarvis 通过 OpenAI 兼容的 `/v1/chat/completions` 端点与 OpenClaw 通信。该端点默认关闭，需要手动启用。

### 1. 启用 `chatCompletions`

编辑 `~/.openclaw/openclaw.json`：

```json
{
  "gateway": {
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "<your-token>"
    },
    "http": {
      "endpoints": {
        "chatCompletions": { "enabled": true }
      }
    }
  }
}
```

### 2. 重启 OpenClaw

```bash
pkill -f openclaw
openclaw gateway start
```

### 3. 验证接口

```bash
curl -X POST http://127.0.0.1:18789/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your-token>" \
  -d '{"model":"openclaw","messages":[{"role":"user","content":"ping"}],"stream":false}'
```

返回结果里应包含 `choices[0].message.content`。

### 4. 在应用里填写连接参数

Settings 面板需要配置：

| 字段 | 说明 |
|------|------|
| `HOST` | `127.0.0.1` 或 Tailscale IP |
| `PORT` | 默认 `18789` |
| `TOKEN` | OpenClaw gateway token |
| `AGENT` | 默认 `main` |

应用启动后会尝试用已保存配置自动连接。

## WhisperKit 模型

首次启动时，如果本地没有模型文件，WhisperKit 会自动下载 `openai_whisper-base`。

如需离线准备模型，可提前放到：

```text
~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-base/
```

## 外接屏行为

应用会尝试检测分辨率接近 800×480 的屏幕，并把窗口切过去显示。匹配逻辑带 10% 容差，适配一些缩放和面板差异。

## 当前已知限制

- README 反映的是当前代码实现，不是最初设计稿
- Claude 数据依赖本地 `claude-hud` 插件缓存，不存在该文件时不会显示用量
- Gemini 暂时只显示 session 数，不显示 token
- TTS 能力已经在代码里，但当前界面没有把“自动播报”完整接回新版 UI
- 系统监控当前展示的是 CPU / 内存 / 磁盘，不是旧文档里写的 CPU / 温度

## 安装到其他电脑

1. 打开 `MacJarvis.dmg` 并拖入 Applications
2. 首次运行时右键应用，选择“打开”
3. 授予麦克风权限以启用语音输入
