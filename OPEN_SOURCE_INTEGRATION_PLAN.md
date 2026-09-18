# 开源依赖审计 · 2026-09-17

检查了下列上游仓库说明和许可证。当前项目已有同职责的运行系统，本轮保留它们，补完整业务链；未复制下列候选的实现代码。

| 候选 / 上游 | 许可与声明兼容性 | 决定及原因 |
|---|---|---|
| [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) | MIT；4.x 要求 Godot 4.6+；GDScript | 不迁移。现有 DialogueSystem 的真实台词信号已通过验收，迁移需重写已验证的分支与存档 |
| [QuestSystem](https://github.com/ShomyKohai/quest-system) | MIT；Godot 4.4+；GDScript | 不引入。ResidencySystem 已从真实材料计算要求，增加第二份任务状态会产生不一致 |
| [GLoot](https://github.com/peter-kish/gloot) | MIT；3.x 支持 Godot 4.4+；GDScript | 不引入。保留 GameState 库存与实体 metadata，扩展收据和胶卷序列化 |
| [State Charts](https://github.com/derkork/godot-statecharts) | MIT；Godot 4+；GDScript/C# 接口 | 不引入。胶卷是有限的线性状态链；直接验证状态转换可避免旧存档节点迁移 |
| [SaveKit](https://github.com/fernforestgames/godot-savekit) | MIT；仓库声明 Godot 4.5+ | 不引入。其 SaveManager 与当前多旅程、A/B、原子回滚职责重叠 |
| [Lente](https://github.com/mbiggeri/lente-godot-photo-mode) | MIT；Godot 4.x；Camera3D 方案 | 不移植。保留 2D 取景与现有 Viewport PNG 管线；避免专业相机 HUD 和世界暂停行为 |
| [TimeTick](https://github.com/shoyguer/time-tick) | MIT；Godot 4.6；原生 GDExtension | 不引入。当前分钟系统规模无需原生扩展；排除额外平台二进制依赖 |
| [Input Helper](https://github.com/nathanhoad/godot_input_helper) | MIT；Godot 4；GDScript/C# 接口 | 不引入。沿用 SettingsSystem 输入绑定与 GameplayShell 情境提示 |
| [Sound Manager](https://github.com/nathanhoad/godot_sound_manager) | MIT；Godot 4.6+ | 不引入。WorldSound、SoundSettings 已管理录音总线、环境声与淡入淡出 |
| [Skelerealms](https://github.com/SlashScreen/skelerealms) | MIT；Godot 4；上游标注 Alpha | 不引入。整套 RPG Actor/Cell/GOAP 架构会重复现有 ScheduleSystem 与存档 |

兼容性栏为上游声明，未声称在本工程安装测试过这些候选。V3 新增业务编排复用现有时间、金钱、对话和存档；本轮无新的原生插件。
