---
title: "feat: API 模式 Token 消耗与费用追踪"
type: feat
status: active
date: 2026-04-08
origin: docs/brainstorms/2026-04-08-api-mode-token-cost-tracking-requirements.md
---

# feat: API 模式 Token 消耗与费用追踪

## Overview

为 Claude Code 和 Codex 新增 API 模式展示：从本地文件读取实际 token 消耗，按小时/天/周聚合，通过内置定价表换算费用，在 TokenCard 中展示。用户通过 Settings 面板手动切换订阅/API 模式。

## Problem Frame

MacJarvis 当前仅展示订阅制窗口百分比。API 模式用户按 token 计费，需要看到实际消耗量和费用的时间维度聚合。(see origin: docs/brainstorms/2026-04-08-api-mode-token-cost-tracking-requirements.md)

## Requirements Trace

- R1. Settings 面板为 Claude 和 Codex 各提供订阅/API 模式开关
- R2. 模式选择持久化到 UserDefaults
- R3. API 模式读取 `~/.claude/usage-data/session-meta/*.json` 的 `input_tokens`、`output_tokens`、`start_time`
- R4. 按 start_time 聚合到小时/天/周
- R5. API 模式读取 `~/.codex/state_5.sqlite` threads 表的 `tokens_used`、`created_at`
- R6. 按 created_at 聚合到小时/天/周
- R7. 内置模型定价表，token 数乘以单价得出费用
- R8. 定价表硬编码
- R9. TokenCard 展示 token 数 + 费用
- R10. 点击切换时间维度（小时→天→周）
- R11. 进度条在 API 模式下隐藏或改为简单指示
- R12. Gemini 保持现有展示

## Scope Boundaries

- 不调用外部 Usage/Billing API
- 不做历史数据持久化
- 不做 Gemini API 模式
- 定价表硬编码不可配置
- 不做图表/趋势图

## Context & Research

### Relevant Code and Patterns

- `TokenService.swift`: 已有 `refreshAll()` → `fetchCodex()`/`fetchClaude()`/`fetchGemini()` 模式，新增 API 模式 fetch 方法即可
- `ToolUsage.swift`: 已有 `inputTokens`/`outputTokens`/`totalTokens`/`cost` 字段但未使用，API 模式直接填充
- `TokenCard.swift`: 已有 `usagePercent` 和 `budget` 双模式显示逻辑，API 模式新增第三种展示
- `SettingsService.swift`: 已有 `codexDailyBudget`/`claudeDailyBudget` 等字段 + UserDefaults 持久化模式
- Codex SQLite 读取模式已有先例：当前代码注释提到 `sqlite3_open_v2` with `?immutable=1` URI

### Data Source Details

| Source | File | Token Fields | Time Format |
|--------|------|-------------|-------------|
| Claude | `~/.claude/usage-data/session-meta/*.json` | `input_tokens`, `output_tokens` | ISO 8601 (`2026-03-27T06:31:21.185Z`) |
| Codex | `~/.codex/state_5.sqlite` threads 表 | `tokens_used` (仅总量) | Unix 秒级时间戳 |

## Key Technical Decisions

- **时间聚合在内存完成**: 每次 refresh 重新扫描文件并聚合，不做持久化缓存。session-meta 文件量级约 100+ 个 JSON 文件，性能可接受。(see origin: scope boundary "不做历史数据持久化")
- **定价表用 Swift 字典**: 按模型名做 key，值为 (inputPricePerMToken, outputPricePerMToken) 元组。Codex 无 input/output 拆分，使用均价。
- **时间维度状态放在 ToolUsage 或 View 层**: 每个 TokenCard 独立维护当前时间维度 state，点击循环切换。
- **Claude session-meta 使用 `input_tokens + output_tokens` 计算费用**: Claude 有 input/output 拆分，可分别按不同单价计费，比 Codex 更精确。
- **Codex 费用使用均价估算**: `tokens_used` 无 input/output 拆分，使用 OpenAI 模型的平均单价。

## Open Questions

### Resolved During Planning

- **Claude session-meta 字段名**: 确认为 `input_tokens`、`output_tokens`、`start_time`（ISO 8601 UTC）
- **Codex created_at 格式**: 确认为 Unix 秒级时间戳（INTEGER）
- **定价表结构**: Swift 字典，key 为模型名前缀匹配，value 为 (input $/M tokens, output $/M tokens)

### Deferred to Implementation

- **Claude session-meta 文件中是否有 model 字段**: 如果没有，费用计算默认使用 opus 定价
- **Codex threads 表 model 字段目前全为 NULL**: 费用使用 model_provider 级别的默认定价

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification.*

```
数据流:

[本地文件] → [Reader] → [TimeBucket 聚合] → [定价换算] → [ToolUsage] → [TokenCard]

Reader 层:
  ClaudeAPIReader: 扫描 session-meta/*.json → [(date, inputTokens, outputTokens)]
  CodexAPIReader:  查询 threads 表 → [(date, totalTokens)]

聚合层:
  TimeBucket enum: .hour / .day / .week
  aggregate(records, bucket) → { totalInput, totalOutput, totalTokens }

定价层:
  ModelPricing 字典查找 → cost = input * inputPrice + output * outputPrice

展示层:
  TokenCard 根据 SettingsService.claudeMode/.codexMode 选择:
    - .subscription → 现有百分比展示
    - .api → token 数 + 费用 + 时间维度切换
```

## Implementation Units

- [ ] **Unit 1: 模式设置持久化**

**Goal:** 为 Claude 和 Codex 添加订阅/API 模式开关，持久化到 UserDefaults

**Requirements:** R1, R2

**Dependencies:** None

**Files:**
- Modify: `MacJarvis/Services/SettingsService.swift`
- Modify: `MacJarvis/Views/SettingsView.swift`
- Test: `MacJarvisTests/SettingsServiceTests.swift`

**Approach:**
- SettingsService 新增 `claudeMode: UsageMode` 和 `codexMode: UsageMode`（enum: `.subscription` / `.api`）
- UserDefaults 持久化，与现有 `openClawHost` 等字段同模式
- SettingsView 在 token budget 区域上方添加模式切换按钮组（复用现有 theme 切换的按钮风格）

**Patterns to follow:**
- `SettingsService.currentTheme` 的 enum + UserDefaults 持久化模式
- SettingsView 中 THEME 按钮组的 UI 模式

**Test scenarios:**
- Happy path: 设置 claudeMode 为 .api，重新初始化 SettingsService，确认值保持
- Happy path: 设置 codexMode 为 .subscription，确认 UserDefaults 存储正确
- Edge case: UserDefaults 中无 mode 值时，默认为 .subscription

**Verification:**
- Settings 面板中 Claude 和 Codex 各有模式切换按钮，点击后状态持久化

---

- [ ] **Unit 2: 定价模型与时间聚合模型**

**Goal:** 新增 ModelPricing 定价表和 TimeBucket 时间聚合逻辑

**Requirements:** R4, R6, R7, R8

**Dependencies:** None

**Files:**
- Create: `MacJarvis/Models/ModelPricing.swift`
- Test: `MacJarvisTests/ModelPricingTests.swift`

**Approach:**
- `TimeBucket` enum: `.hour` / `.day` / `.week`
- `TokenRecord` struct: `(date: Date, inputTokens: Int, outputTokens: Int, totalTokens: Int)`
- `ModelPricing` struct: 静态字典存储各模型定价，提供 `cost(input:output:model:)` 方法
- 聚合函数 `aggregate(_ records: [TokenRecord], bucket: TimeBucket) -> TokenRecord`：按时间桶过滤并求和
- Claude 定价: opus input $15/M, output $75/M; sonnet input $3/M, output $15/M
- OpenAI 定价: 默认使用 gpt-4o input $2.50/M, output $10/M（Codex 无 model 字段时的 fallback）

**Patterns to follow:**
- `ToolUsage` struct 的简洁数据模型风格

**Test scenarios:**
- Happy path: 传入一组 TokenRecord，按 .day 聚合，验证今日总量正确
- Happy path: cost 计算 — Claude opus 100K input + 50K output = 预期费用
- Happy path: cost 计算 — Codex 均价模式 200K total = 预期费用
- Edge case: 空记录数组聚合返回零值
- Edge case: 跨天记录按 .day 聚合只包含当天数据
- Edge case: 按 .week 聚合包含过去 7 天数据
- Edge case: 按 .hour 聚合只包含当前小时数据

**Verification:**
- 定价计算和时间聚合逻辑通过单元测试

---

- [ ] **Unit 3: Claude API 模式数据读取**

**Goal:** 读取 Claude session-meta JSON 文件，返回 TokenRecord 数组

**Requirements:** R3

**Dependencies:** Unit 2 (TokenRecord 类型)

**Files:**
- Modify: `MacJarvis/Services/TokenService.swift`
- Test: `MacJarvisTests/TokenServiceTests.swift`

**Approach:**
- 新增 `nonisolated static func fetchClaudeAPIUsage() async -> [TokenRecord]` 方法
- 扫描 `~/.claude/usage-data/session-meta/*.json`
- 用 JSONSerialization 解析每个文件，提取 `input_tokens`、`output_tokens`、`start_time`
- `start_time` 用 ISO8601DateFormatter 解析
- 后台执行（与现有 fetchClaude 同模式，使用 Task.detached 或 nonisolated）

**Patterns to follow:**
- TokenService 中现有的 `fetchClaude()` 方法的文件读取和错误处理模式
- `nonisolated static` 后台执行模式

**Test scenarios:**
- Happy path: 给定包含 input_tokens/output_tokens/start_time 的 JSON，解析出正确的 TokenRecord
- Edge case: JSON 文件缺少 input_tokens 字段，跳过该文件
- Edge case: start_time 格式异常，跳过该记录
- Error path: session-meta 目录不存在，返回空数组

**Verification:**
- 能从真实 session-meta 文件中读取并返回 TokenRecord 数组

---

- [ ] **Unit 4: Codex API 模式数据读取**

**Goal:** 读取 Codex SQLite threads 表，返回 TokenRecord 数组

**Requirements:** R5

**Dependencies:** Unit 2 (TokenRecord 类型)

**Files:**
- Modify: `MacJarvis/Services/TokenService.swift`
- Test: `MacJarvisTests/TokenServiceTests.swift`

**Approach:**
- 新增 `nonisolated static func fetchCodexAPIUsage() async -> [TokenRecord]`
- 打开 `~/.codex/state_5.sqlite` with `?immutable=1` URI（与现有 Codex 读取方式一致）
- 查询 `SELECT tokens_used, created_at FROM threads WHERE tokens_used > 0`
- `created_at` 为 Unix 秒级时间戳，用 `Date(timeIntervalSince1970:)` 转换
- Codex 无 input/output 拆分，TokenRecord 的 inputTokens/outputTokens 设为 0，totalTokens 填充

**Patterns to follow:**
- CLAUDE.md 中记录的 `sqlite3_open_v2` with `?immutable=1` URI 模式

**Test scenarios:**
- Happy path: threads 表有数据，正确返回 TokenRecord 数组
- Edge case: tokens_used 为 0 的 thread 被过滤
- Error path: SQLite 文件不存在，返回空数组

**Verification:**
- 能从真实 Codex SQLite 中读取并返回 TokenRecord 数组

---

- [ ] **Unit 5: TokenService 模式切换集成**

**Goal:** TokenService 根据 Settings 中的模式选择，调用不同的数据采集方法

**Requirements:** R3-R6, R9

**Dependencies:** Unit 1, 2, 3, 4

**Files:**
- Modify: `MacJarvis/Services/TokenService.swift`
- Modify: `MacJarvis/Models/ToolUsage.swift`

**Approach:**
- `refreshAll()` 中根据 `settingsService.claudeMode` 和 `settingsService.codexMode` 决定调用哪个 fetch 方法
- API 模式下，fetch 后调用聚合函数，填充 ToolUsage 的 `inputTokens`/`outputTokens`/`totalTokens`/`cost` 字段
- TokenService 需要接收 SettingsService 引用（通过初始化参数或 Environment）
- ToolUsage 新增 `timeBucket: TimeBucket?` 字段，供 UI 展示当前时间维度

**Patterns to follow:**
- 现有 `refreshAll()` 的并行 fetch 模式

**Test scenarios:**
- Happy path: claudeMode 为 .api 时，ToolUsage 的 inputTokens/outputTokens/cost 被填充
- Happy path: codexMode 为 .subscription 时，走现有百分比逻辑
- Integration: 模式切换后下次 refresh 自动使用新模式数据

**Verification:**
- 切换模式后，TokenService 输出的 ToolUsage 数据源正确切换

---

- [ ] **Unit 6: TokenCard API 模式 UI**

**Goal:** TokenCard 在 API 模式下展示 token 数 + 费用，支持点击切换时间维度

**Requirements:** R9, R10, R11

**Dependencies:** Unit 5

**Files:**
- Modify: `MacJarvis/Views/TokenCard.swift`
- Modify: `MacJarvis/Views/TokenColumnView.swift`

**Approach:**
- TokenCard 新增 `isAPIMode: Bool` 参数（或从 ToolUsage 推断）
- API 模式下：
  - 主数字显示 token 数（K/M 格式化，复用现有 `formatTokens`）
  - 副文本显示费用（$X.XX 格式）
  - 底部显示当前时间维度标签（"1H" / "1D" / "1W"）
  - 进度条隐藏
  - 整个卡片点击切换时间维度
- TokenColumnView 传入 SettingsService 的模式信息

**Patterns to follow:**
- TokenCard 现有的 `usagePercent` / `budget` 双模式显示逻辑
- 现有的 `formatTokens()` 工具函数

**Test scenarios:**
- Happy path: isAPIMode=true 时，显示 token 数 + 费用文本
- Happy path: 点击卡片，时间维度从 .day 切换到 .week
- Edge case: cost 为 0 或 tokens 为 0 时显示 "--"
- Edge case: 时间维度循环 hour→day→week→hour

**Verification:**
- API 模式下 TokenCard 正确展示 token/费用/时间维度，点击可切换

## System-Wide Impact

- **Interaction graph:** TokenService ← SettingsService（新增模式读取依赖），TokenCard ← ToolUsage（新增 API 模式字段）
- **Error propagation:** 文件读取失败静默降级为零值展示，不影响其他工具
- **State lifecycle risks:** 模式切换时 ToolUsage 的百分比字段和 token 字段可能同时存在，UI 应根据模式严格分支显示
- **Unchanged invariants:** Gemini 展示完全不变；订阅模式下的 Claude/Codex 展示完全不变

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Claude session-meta 文件量大导致 refresh 慢 | 后台线程执行，仅读取需要的字段，跳过异常文件 |
| Codex SQLite 被 Codex 进程锁定 | 使用 `?immutable=1` URI 避免锁冲突 |
| 模型定价变化导致费用不准 | 硬编码当前定价，README 注明；后续可配置化 |
| session-meta 无 model 字段 | 默认使用 opus 定价，可能高估费用 |

## Sources & References

- **Origin document:** [docs/brainstorms/2026-04-08-api-mode-token-cost-tracking-requirements.md](../brainstorms/2026-04-08-api-mode-token-cost-tracking-requirements.md)
- Claude session-meta 示例: `~/.claude/usage-data/session-meta/*.json`
- Codex SQLite schema: `~/.codex/state_5.sqlite` threads 表
