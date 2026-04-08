---
date: 2026-04-08
topic: api-mode-token-cost-tracking
---

# API 模式 Token 消耗与费用追踪

## Problem Frame

MacJarvis 当前仅支持订阅模式的用量展示（5h/7day 窗口百分比）。当用户使用 Claude Code 或 Codex 的 API 模式（按 token 计费）时，百分比窗口没有意义——用户需要看到实际的 token 消耗量和对应费用，并按时间维度（小时/天/周）聚合查看。

## Requirements

**模式切换**
- R1. Settings 面板中为 Claude 和 Codex 各提供一个模式开关：订阅模式 / API 模式
- R2. 模式选择持久化到 UserDefaults，重启后保持

**数据采集 — Claude Code**
- R3. API 模式下读取 `~/.claude/usage-data/session-meta/*.json`，提取每个 session 的 `input_tokens`、`output_tokens`、`start_time`
- R4. 按 start_time 聚合到小时/天/周三个时间桶

**数据采集 — Codex**
- R5. API 模式下读取 `~/.codex/state_5.sqlite` 的 `threads` 表，提取 `tokens_used`、`created_at`
- R6. 按 created_at 聚合到小时/天/周三个时间桶（Codex 无 input/output 拆分，仅展示总量）

**费用换算**
- R7. 内置模型定价表（Claude opus/sonnet/haiku 的 input/output 单价，OpenAI 模型的单价），token 数乘以单价得出费用
- R8. 定价表硬编码在代码中，后续可考虑配置化（本期不做）

**UI 展示**
- R9. API 模式下 TokenCard 展示内容切换为：当前时间桶的 token 数 + 费用（如 "125K tokens / $2.50"）
- R10. TokenCard 支持点击切换时间维度（小时 → 天 → 周循环）
- R11. 进度条在 API 模式下隐藏或改为柱状趋势指示（无百分比上限）

**Gemini**
- R12. Gemini 本期不支持 API 模式（本地无 token 数据），保持现有订阅百分比展示

## Success Criteria

- 用户在 Settings 中切换到 API 模式后，TokenCard 立即展示从本地文件聚合的 token 数和费用
- 小时/天/周切换流畅，数据准确反映本地文件中的实际消耗
- 订阅模式和 API 模式互不干扰，切换无需重启

## Scope Boundaries

- 不调用任何外部 Usage/Billing API
- 不做历史数据持久化（每次从本地文件重新聚合）
- 不做 Gemini API 模式
- 定价表不做用户可配置（硬编码）
- 不做图表/趋势图（纯数值 + 简单指示）

## Key Decisions

- **数据源选择本地文件而非 API**: 避免额外的 API Key 配置，利用工具已有的本地数据
- **费用由客户端换算**: 各工具不存储费用，MacJarvis 维护定价表自行计算
- **Gemini 跳过**: 本地完全无 token 数据，强行支持没有意义
- **Settings 手动切换**: 不做自动检测，让用户明确选择每个工具的模式

## Outstanding Questions

### Deferred to Planning
- [Affects R3][Needs research] Claude session-meta JSON 的完整字段结构和时间格式需确认
- [Affects R5][Needs research] Codex state_5.sqlite 的 `created_at` 字段是 Unix timestamp 还是 ISO 格式
- [Affects R7][Technical] 定价表的具体数据结构设计（按模型名 key 的字典？）
- [Affects R9][Technical] TokenCard API 模式的具体布局方案

## Next Steps

→ `/ce:plan` for structured implementation planning
