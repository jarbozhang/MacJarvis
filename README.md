# MacJarvis

MacJarvis 是一个原生 macOS SwiftUI 状态墙，用来在 1024 或 1280 宽度的小屏上常亮展示大 agent 可用状态、token 消耗和本机负载。

![MacJarvis agent status wall](docs/images/status-wall.png)

当前默认界面围绕“agent 是否正常工作”组织：

- 主读数：已安装大 agent 的全局状态，优先显示正常、运行中、卡住、离线或错误
- 大 agent：OpenClaw / Hermes 只显示已安装项；缺失安装不会被当作故障
- 消耗：OpenClaw / Hermes 的大 agent 消耗和 Codex / Claude / Gemini 的小 agent 消耗分开显示
- 本机状态：CPU、内存常驻摘要，系统详情页显示磁盘
- 轮询：主状态、消耗详情和本机状态详情自动切换；大 agent 故障会暂停轮询

## 当前能力

- Codex / Claude / Gemini 本地使用数据采集
- OpenClaw 网关连接、健康检测、活动状态和消耗汇总
- Hermes 本地自动发现、gateway 状态读取和 SQLite 消耗汇总
- Push-to-Talk 语音输入，WhisperKit 本地转写
- CPU / 内存 / 磁盘监控
- OpenClaw 连接参数和每日预算设置持久化
- 针对 5 寸 / 7 寸小屏优化的赛博终端风状态墙 UI

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
- OpenClaw gateway usage: `openclaw gateway usage-cost --json`
- Hermes: `~/.hermes/gateway_state.json`、`~/.hermes/gateway.pid`、`~/.hermes/state.db`

说明：

- Codex 小 agent 消耗不再使用 OpenClaw gateway 作为 fallback，避免和 OpenClaw 大 agent 消耗重复展示
- Claude 当前展示的是 `claude-hud` 缓存里的 5 小时用量百分比和套餐名
- Gemini 当前只统计今日 session 数，不显示真实 token

## 状态墙行为

大 agent 指 OpenClaw 和 Hermes。它们有安装状态、运行状态和消耗量。小 agent 指 Codex、Claude Code 和 Gemini；当前默认界面只展示它们的消耗，不推断运行健康。

状态墙自动轮询：

- 主状态页停留最长，用于常亮观察
- 消耗详情页展示大 agent 和小 agent 的分组消耗
- 本机状态详情页展示 CPU、内存和磁盘
- 大 agent 卡住、离线或错误时显示故障中断页，直到恢复

开发预览可以使用 fixture 启动：

```bash
open -na /path/to/MacJarvis.app --args -ApplePersistenceIgnoreState YES --fixture healthy-openclaw --page status
```

可用 fixture 包括 `healthy-openclaw`、`no-large-agents`、`stuck-openclaw`、`error-openclaw`、`mixed-openclaw-hermes` 和 `missing-small-token`。

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
- OpenClaw 聊天、嵌入式终端和 PTT 控件已从默认常亮界面降级为后续 debug/operator 模式范围

## 安装到其他电脑

1. 打开 `MacJarvis.dmg` 并拖入 Applications
2. 首次运行时右键应用，选择“打开”
3. 授予麦克风权限以启用语音输入
