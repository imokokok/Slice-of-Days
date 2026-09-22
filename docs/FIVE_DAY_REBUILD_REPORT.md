# 五日主流程重构交付报告

2026-09-23。依据用户确认：以《Solmere_Codex_5Day_Rebuild_CN》为准，保留已有美术和可用小游戏。本报告区分五日流程的已完成接入与仍需继续打磨的内容。

## 实际流程

| 日期 | 视角 | 活动与推进 |
| --- | --- | --- |
| Day 1 | A | 唱片店录音、混音、试听、压片；与 Xanni 交谈；回家休息 |
| Day 2 | B | 接采购单，实际购买、交货报销、烹饪；与石泳琪交谈；回家休息 |
| Day 3 | A | 拼贴、折信、封装、火漆并交付；查看公共痕迹，与 Mossner 交谈 |
| Day 4 | B | 实际棋局；查看痕迹，与闹闹交谈并选择约定见面 |
| Day 5 | A，见面后可切换 | 三段实际见面对白，最后确认才揭示身份并开放切换 |

第一、二天没有寻找进度或提前揭示身份；第三、四天的留意/寻找来自真实互动。每晚核对当天活动及交谈条件，第五天之后不产生 Day 6/7。右侧引导来自实际尚未完成的步骤。

## 修改与实际挂载

下列路径均相对本项目根目录。继续复用现有 `.tscn` 场景，界面由原生 Control 脚本创建。

| 范围 | 路径与职责 |
| --- | --- |
| 状态机 | `scripts/core/chapter_system.gd`：固定五日、真实推进、痕迹与见面；使用既有 ChapterSystem autoload |
| 数据/存档/切换 | `scripts/core/game_state.gd`、`save_manager.gd`、`character_system.gd`：角色深拷贝、格式验证、安全切换、失败回滚 |
| 日程与引导 | `scripts/core/core_loop_system.gd`、`event_system.gd`、`travel_system.gd`、`economy_system.gd`；`data/story/calendar.json`、`core_loop.json`、`events.json`：新日程、实时采购步骤和旧事件过滤 |
| NPC | `scripts/core/dialogue_system.gd`、`relationship_system.gd`、`resident_profile_system.gd`、`scripts/ui/conversation_panel.gd`：分角色关系、共享误认与可中途退出的主线对白 |
| 模块上下文 | `scripts/core/gameplay_module_system.gd`、`scripts/ui/native_module_game.gd`、`extension_host.gd`：入口携带 current_character/day/location，返回验证上下文，双方复用同一模块 |
| 音乐 | `scripts/town_sound/record_shop/PressingTable.gd`、`RecordShelf.gd`、`studio/Arrangement.gd`、`StudioScreen.gd`、`data/SampleStore.gd`、`network/LocalRecordLibrary.gd`：真正压片成功才结算；样本和草稿私有，交付成品公开 |
| 原信件和棋类 | `extensions/collage_letter/workshop/workshop.gd`、`extensions/elder_board/scripts/main.gd`、`elder_memory.gd`：原工作台/棋局接上下文，草稿归当前角色 |
| 新增公共展架 | `scripts/ui/components/public_trace_panel.gd`：由 `town_day.gd` 的真实街道入口创建，动态条目、发现记录、封面/信件预览与实际 WAV 播放 |
| 新增见面界面 | `scripts/ui/components/meeting_scene.gd`：由 `town_day.gd` 第五天见面入口创建，保存对白进度；`walk_stage.gd` 在场景内显示见面者 |
| 纸页与收尾 | `scripts/residency/gameplay_shell.gd`、`living_objects.gd`、`residency_system.gd`、`scripts/ui/components/evening_review.gd`、`chapter_transition.gd`、`ending.gd`：可选记录、安全切换和睡觉推进 |
| 入口和身份文字 | `scripts/ui/main_menu.gd`、`components/save_slots.gd`、`journal.gd`、`town_map.gd`、`interactive_space.gd`、`scripts/meta/memory_entry.gd`、`scripts/photography/film_system.gd` 及地点数据：旧档提示和前期身份隐藏 |

两个新组件实际挂载于 `scenes/town_day.tscn` 的脚本入口。模块继续使用 `scenes/native_module_game.tscn`、`scenes/extension_host.tscn`、原拼贴信与棋类场景；没有建立独立假数据演示页。

保留工作区原有的上色角色、步行帧、观星图片和相关场景调整，本次没有新增 AnimationTree 或替换建筑、天空。观星图片展示不再虚报体积层数和采样数；保留照片视角/缩放和可选星座交互，不将其描述成物理精确三维重建。

## 私有和共享数据

- `GameState.role_states.A/B`：钱、物品、关系、笔记、成果和活动；活动角色继续读取原 GameState 字段，切换时深拷贝保存，避免引用串用。
- 当前角色 `artifacts.minigame_drafts`：音乐、拼贴信和棋局草稿；既有小游戏直接读写，不新建平行人物状态。
- `shared_state.five_day_story`：每日完成状态、双方留意/寻找、约定与揭示。
- `shared_state.public_traces`：唯一 ID、owner、day、place、type、payload、visibility、discovered_by。A 的实际唱片在读档后的 B 日程中仍可查看和播放。
- `shared_state.npc_memory`：分别见过 A/B 与误认/记忆标志；关系数值仍由各角色已有关系字典提供。
- 真实图片、声音与作品媒体由原系统写文件；存档保留路径和条目。声音素材按旅程/角色过滤，公共成品按本旅程交付记录过滤。

五日存档使用 `user://solmere_five_day.json` 和另外两个槽。schema 7 是格式版本，与天数无关。旧七日文件只读检测，明确拒绝不兼容格式并保留原文件；新游戏从 Day 1 A 开始。独立存档名也避免旧窗口把七日状态写入五日槽。

## 停用与保留

七日轮换、作品集提交门槛、居民认可数量门槛、最终申请提交、Day 6/7、旧争执/消除误解入口退出主流程。旧事件标为 legacy 并过滤。旧纸页绘制辅助代码和素材仍供现有界面复用，不能由文件残留推断旧推进逻辑仍开启。

摄影、录音、购物、小票、做菜、拼贴写信、棋类、钓鱼、观星等现有功能保留；塔罗/观星不是必需主线。没有自动替玩家补齐小游戏完成状态。

## 验证

1. `tests/integration/test_five_day_flow.gd`：134 项通过，0 项失败。连续新游戏至第五天；真实录音、压片生成 WAV、采购报销及烹饪、折信火漆交付、实际棋局、痕迹交互和约定/见面对话。各晚经真实休息入口推进；只跳过交通卡片过场动画，不写主线完成标志。
2. 关闭测试进程后重新启动同一脚本 `--reload-only`：4 项通过。第五天角色、切换状态、四条公共痕迹、A 私人信件未复制给 B 均正确。
3. `tests/integration/test_nebula_telescope.gd`：通过。实际图片尺寸、打开关闭、缩放、介绍显隐和原可选星座流程。故意向不可写路径保存产生的报错属于回滚用例。
4. Godot 无界面启动退出码 0；新可玩窗口实际观察到 Day 1、实色引导、真实地图地点/交通选择与可开关的暂停菜单。

在项目目录分别启动进程，`godot` 替换为 Godot 4.7.2 可执行文件：

```powershell
godot --path . --script tests/integration/test_five_day_flow.gd -- --isolated-save --fresh
godot --path . --script tests/integration/test_five_day_flow.gd -- --isolated-save --reload-only
godot --path . --script tests/integration/test_nebula_telescope.gd -- --isolated-save
```

测试媒体和存档不提交 Git；不能在正式存档上跑测试。

## 限制

上述是五日循环及指定回归的结果，不是所有历史测试的全量通过声明。旧七日断言需随新规格淘汰。见面已具备真实交互和持久状态，台词仍可继续扩写。启动仍提示缺少英文目录 `localization/en.json`，中文可用、英文设置暂不可用。本次没有声称此前全部 UI 像素级还原、动作与天气素材需求均已完成。
