# 100饭店工程约束

保留现有 Godot 4.7.2 工程和 `modules/restaurant` 可接入结构。最高层体验与视觉指导保存在 [`docs/CORE_EXPERIENCE_REFERENCE.md`](docs/CORE_EXPERIENCE_REFERENCE.md)；完整原始规格保存在 [`docs/COOKING_FULL_SPEC.md`](docs/COOKING_FULL_SPEC.md)，原件保存在 `docs/COOKING_FULL_SPEC.docx`。实施任何厨房空间、食材、工具、液体、摆盘、菜谱、顾客、菜单、音频或存档改动前，必须先读取最高层指导及完整规格中的对应章节。`docs/HIGH_FIDELITY_INTERACTION_SPEC.md` 仅是执行摘要，不能替代上述文档。

关键约束：统一原创 2D 画风；食材状态连续且质量/液体数量可追踪；不放鱼；不在可交互层放置无效入口；不得以预制成品图替换实际切块、锅内状态、摆盘或照片；二维混色、流体和合成拟音必须标为近似。

验证至少包括：Godot `--headless --path . --quit-after 120` 无脚本错误、受影响模块的定向测试、`tests/test_integration.gd`、实际启动当前工程。逐项状态写入 `docs/COOKING_PROGRESS.md`，运行结果与限制写入 `docs/VALIDATION.md`，并按“已实现并验证 / 已实现但未验证 / 近似实现 / 尚未实现”分类。
