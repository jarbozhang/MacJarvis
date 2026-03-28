# TODOS

## Visual: PixelGrid + StarfieldBackground 叠加验证
- **What:** 实施 StarfieldBackground 后，验证 PixelGrid 点阵是否遮挡星云效果
- **Why:** 星云 RadialGradient 只有 6-12% opacity，PixelGrid 的半透明点阵可能完全盖住星云
- **Action:** 降低 PixelGrid 透明度至 0.3，或考虑移除 PixelGrid（实测后决定）
- **Context:** Outside Voice 在 eng review 中指出此风险。DashboardView 渲染栈：StarfieldBackground → PixelGrid → CRT → UI
- **Depends on:** StarfieldBackground.swift 实现完成

## Test: queryClaudeUsageCache 单元测试
- **What:** 为 `TokenService.queryClaudeUsageCache()` 添加单元测试
- **Why:** 该方法是 Claude token 数据的唯一来源（Keychain fallback 已移除），需要覆盖 cache 缺失、过期、格式错误等场景
- **Action:** 在 TokenServiceTests.swift 中添加 4-5 个测试用例（正常 cache、过期 cache、文件不存在、JSON 格式错误、字段缺失）
- **Effort:** S | **Priority:** P3
- **Depends on:** 无
