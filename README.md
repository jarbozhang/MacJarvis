# MacJarvis

macOS AI Dashboard — 赛博朋克风格的 AI 工具监控面板，针对 800×480 外接屏优化。

## 功能

- Codex / Claude / Gemini token 用量监控
- OpenClaw AI 网关对话（语音 + 文字）
- Push-to-Talk 语音输入（WhisperKit 本地推理）
- TTS 自动播报
- CPU / 温度系统监控

## 构建

```bash
# 需要 XcodeGen
brew install xcodegen

# 生成 Xcode 项目并构建
xcodegen generate
xcodebuild -project MacJarvis.xcodeproj -scheme MacJarvis -configuration Debug build
```

## OpenClaw 配置

MacJarvis 通过 OpenAI 兼容的 `/v1/chat/completions` 端点与 OpenClaw 通信。该端点默认关闭，需要手动启用。

### 1. 启用 chatCompletions 端点

编辑 `~/.openclaw/openclaw.json`，在 `gateway` 下添加 `http` 配置：

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
# 停止后重新启动
pkill -f openclaw
openclaw gateway start
```

### 3. 验证

```bash
curl -X POST http://127.0.0.1:18789/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your-token>" \
  -d '{"model":"openclaw","messages":[{"role":"user","content":"ping"}],"stream":false}'
```

应返回包含 `choices[0].message.content` 的 JSON 响应。

### 4. 在 MacJarvis 中配置

打开 Settings 面板（右上角齿轮图标），填入：

| 字段 | 值 |
|------|-----|
| HOST | `127.0.0.1`（本机）或 Tailscale IP |
| PORT | `18789` |
| TOKEN | OpenClaw gateway token |
| AGENT | `main`（默认） |

应用启动时会使用保存的配置自动连接。

## WhisperKit 语音模型

首次启动时，如果本地没有模型文件，会自动从 HuggingFace 下载 `openai_whisper-base`（约 140MB）。

如需离线使用，可提前手动放置模型到：

```
~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-base/
```

## 安装（其他电脑）

1. 打开 `MacJarvis.dmg`，拖入 Applications
2. 首次打开：右键 → 打开 → 确认（未签名应用）
3. 授予麦克风权限（语音功能需要）
