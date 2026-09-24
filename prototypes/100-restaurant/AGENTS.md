# 100饭店工程约束

菜谱与引导改动前读 `docs/RECIPE_GUIDE_20260925.md`。书架和展开页保持同源；步骤从真实切配、熟度和装盘推进，不能由计时或确认按钮伪造。历史顺序缺失时明示状态推断。验证使用 `tests/test_recipe_guide.gd`、`tests/test_recipe_diy.gd` 和 GPU `tests/capture_recipe_guide.gd`。

2026-09-25 最新确认：以 `docs/kitchen_layout_20260925.jpg` 为最终布局参考（此前图为 `docs/kitchen_reference_20260925.jpg`）替换场景，见 `docs/REFERENCE_KITCHEN_20260925.md`。Letter 工作台文件是误发，不适用于本工程。新图的可移动道具必须与静态环境分层，切片、加热和摆盘状态不能因美术更换而重置。验证新增 `tests/test_slice_cooking_continuity.gd`，GPU 使用 `tests/capture_cooking_states.gd`。

保留现有 Godot 4.7.2 工程和 `modules/restaurant` 可接入结构。最高层体验与视觉指导保存在 [`docs/CORE_EXPERIENCE_REFERENCE.md`](docs/CORE_EXPERIENCE_REFERENCE.md)；完整原始规格保存在 [`docs/COOKING_FULL_SPEC.md`](docs/COOKING_FULL_SPEC.md)，原件保存在 `docs/COOKING_FULL_SPEC.docx`。实施任何厨房空间、食材、工具、液体、摆盘、菜谱、顾客、菜单、音频或存档改动前，必须先读取最高层指导及完整规格中的对应章节。`docs/HIGH_FIDELITY_INTERACTION_SPEC.md` 仅是执行摘要，不能替代上述文档。

关键约束：统一原创 2D 画风；食材状态连续且质量/液体数量可追踪；不放鱼；不在可交互层放置无效入口；不得以预制成品图替换实际切块、锅内状态、摆盘或照片；二维混色、流体和合成拟音必须标为近似。

验证至少包括：Godot `--headless --path . --quit-after 120` 无脚本错误、受影响模块的定向测试、`tests/test_integration.gd`、实际启动当前工程。逐项状态写入 `docs/COOKING_PROGRESS.md`，运行结果与限制写入 `docs/VALIDATION.md`，并按“已实现并验证 / 已实现但未验证 / 近似实现 / 尚未实现”分类。

本轮补充：柜格取物须扣除可见库存，调料台不放米饭；菜谱外侧与展开页共用渲染源；锅溢出按体积而不是小份数量。实施与验证见 docs/STOCK_RECIPE_PAN_20260925.md。

2026-09-25 最新操作修正：菜板固定在右侧备菜区，取消拖动，覆盖旧文档中可拖动菜板的要求；保留刀切及切块整批入锅。验证使用 tests/test_cut_batch_stability.gd 和 tests/test_knife_drag.gd，结果记录在 docs/VALIDATION.md。

音频最新要求：禁止程序生成拟音；仅使用许可核验可商用的外部录音，优先 CC0。当前音频来源、加工、缺口和验证入口在 docs/AUDIO.md；assets/audio/recorded/manifest.json 必须逐文件记录来源与哈希。新素材不得仅因写着“免费”就纳入。使用 tests/test_recorded_audio.gd 验证事件、tools/audit_recorded_audio.py 验证素材；技术测试不能冒充人耳试听。
