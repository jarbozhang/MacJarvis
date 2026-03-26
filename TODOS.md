# TODOS

## Visual: PixelGrid + StarfieldBackground 叠加验证
- **What:** 实施 StarfieldBackground 后，验证 PixelGrid 点阵是否遮挡星云效果
- **Why:** 星云 RadialGradient 只有 6-12% opacity，PixelGrid 的半透明点阵可能完全盖住星云
- **Action:** 降低 PixelGrid 透明度至 0.3，或考虑移除 PixelGrid（实测后决定）
- **Context:** Outside Voice 在 eng review 中指出此风险。DashboardView 渲染栈：StarfieldBackground → PixelGrid → CRT → UI
- **Depends on:** StarfieldBackground.swift 实现完成
