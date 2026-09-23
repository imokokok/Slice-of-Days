# SOLMERE 开源集成与现有系统审计

> 历史记录：本文是 2026-09-18 的 V3 审计，七日制、作品集推进门槛等已被后续五日制规格取代。不要依据本文恢复旧玩法。当前第三方接入状态见 [2026-09-24 核对](docs/third_party_integration_20260924.md)，实际许可见 [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)。

审计日期：2026-09-18

运行基线：Godot 4.7.2 stable，GDScript，1600×900 主视口
结论：保留一套 Solmere 原生运行时；本轮没有复制或安装第三方运行时代码，也没有并存第二套 Dialogue、Quest、Inventory、State Machine 或 Save 系统。

## 1. 现有系统、状态与处置

| 领域 | 现有实现与当前状态 | 处置 | 主要受影响文件 | 验收入口 |
|---|---|---|---|---|
| 时间 / 七日流程 | `GameState`、`ChapterSystem` 已可跨日，动作真实消耗分钟 | 沿用；让引导、交通、约定、营业时间共用同一时钟 | `scripts/core/game_state.gd`, `chapter_system.gd`, `data/story/calendar.json` | `test_world_clock`, `test_final_calendar` |
| 存档 | `SaveManager` 已有多槽、原子写入、失败回滚与旧档候选 | 沿用；所有 V3 状态继续放入角色 `artifacts` / `shared_state` | `scripts/core/save_manager.gd`, `game_state.gd` | `test_save_failure_recovery`, `test_final_runtime` |
| 对话 | `DialogueSystem` 已有真实线性对话、话题、邀请、争吵后状态 | 沿用；短问答与长聊天共享时间、知识、约定结果，不另装 Dialogue Manager | `scripts/core/dialogue_system.gd`, `data/npcs/*.json`, `scripts/ui/conversation_panel.gd` | `test_linear_dialogue`, `test_patch_npcs` |
| NPC / 日程 / 关系 | `ScheduleSystem`、`RelationshipSystem`、`ResidentProfileSystem` 可按地点时间放置居民 | 沿用；认可由多事件、兑现承诺和生活圈计算，不暴露好感数字 | `scripts/core/*relationship*.gd`, `schedule_system.gd`, `data/npcs/core_residents.json` | `test_patch_npcs`, `test_v3_residency` |
| 地图 / 交通 | `WorldGraph`、`TravelSystem` 已有路线与费用，但旧区域切换曾暴露临时入口 | 沿用图数据；正式入口统一为 Tab 纸图、Walk / Taxi，禁用 W/S 切区 | `scripts/core/travel_system.gd`, `scripts/residency/map_paper.gd`, `data/world/*.json` | `test_patch_travel`, `test_route_layout` |
| 目标 / 机会 | 旧剧情日程可用，但缺少从真实进度导出的“下一步” | 补 `GuidanceSystem`；只读 Dossier、知识和约定，不维护第二套任务状态 | `scripts/core/guidance_system.gd`, `scripts/residency/paper_overlay.gd` | `test_v3_guidance`, `test_final_tools` |
| Residency / Dossier | 旧档案页可写，但硬要求、实物来源和贡献签收不足 | 升级 `ResidencySystem` V3；资料袋、七页作品集、Proof、散页均为实体记录 | `scripts/residency/residency_system.gd`, `paper_overlay.gd` | `test_patch_residency`, `test_v3_residency` |
| 金钱 / 商店 / 小票 | `GameState` 有钱包和流水；旧商品与小票证据不足 | 补 `EconomySystem` V3；动态库存、采购、原票盖章报销、收藏摆放共用同一账本 | `scripts/core/economy_system.gd`, `scripts/ui/shop_panel.gd`, `data/economy/*.json` | `test_v3_economy`, `test_daily_spending` |
| 物品 / Proof | 既有 `artifacts` 是稳定存档容器，没有通用格子背包需求 | 不引入 GLoot；用带来源 metadata 的纸张、胶卷、作品和收藏记录 | `game_state.gd`, `residency_system.gd`, `film_system.gd` | `test_v3_residency`, `test_v3_film` |
| 胶片摄影 | 既有 2D Viewport 截图和相册，但缺胶卷生命周期 | 补 `FilmSystem`；24 张、四类胶卷、冲洗状态、Gallery/拼贴/房间/Dossier 用途 | `scripts/photography/*.gd`, `scripts/town_sound/PocketCamera.gd`, `data/photography/film_types.json` | `test_v3_film`, `test_camera_rhythm` |
| 录音 | Town Sound 已有录制、采样、唱片工作流 | 沿用；增加随身轻量录音器与 Dossier 实物入口 | `scripts/residency/recorder_lite.gd`, `scripts/town_sound/*` | `test_recorder_movement`, `test_final_tools` |
| Inner Voice / Marginalia | 旧系统存在但正常流程触发不可靠 | 重接真实对话、观察、消费、打车、争吵、错过事件；必现事件与随机日常分开 | `scripts/meta/meta_experience.gd`, `place_layer.gd`, `data/meta/catalog.json` | `test_patch_voices`, `test_meta_layer` |
| UI / 移动 | 横向 2D 控制器可用，旧 HUD 与部分入口偏调试态 | 保留 A/D、Shift、E/C/R/G/Tab/B/F/H/Space/Esc；HUD 只显示 RP-07、时间与情境提示 | `scripts/ui/walk_stage.gd`, `scripts/residency/gameplay_shell.gd` | `test_walking_journey`, `test_final_tools` |

## 2. 审计中发现并处理的冲突

- Residency 以前可由文字或布尔值替代证据；现改为小票、工资单、探索纸、签记和贡献证明的来源校验。
- 完成作品以前会提前产生公共余波；现必须先由对应地点真实签收，之后才生成唯一 `world_trace_id`、证明和次日反馈。
- 报销以前可能重复造纸或被当成收入；现给同一原票盖 `reimbursed` 状态，返款幂等且排除收入证明。
- 普通聊天以前可能等同认可；现按不同事件去重，并要求 12 位居民覆盖至少 4 个生活圈。
- 未冲洗照片以前可能直接出现在素材入口；现只有 `DEVELOPED` 照片进入 Gallery、拼贴与 Dossier。
- 旧 W/S 区域切换和路牌传送不再作为正式入口；跨区统一走地图路线。
- Day 1 早到社区中心时曾被外部门锁挡住；现允许进等候区，到 09:00 后在真实柜台领资料。
- RP-07 图示页曾遮住六份已领取文件；现图示首页和可操作资料袋分层，六份文件可重复打开。

## 3. 开源候选评估

以下兼容性来自各上游仓库声明。候选仅作设计和边界审计；本轮没有把其源码带入工程。

| 候选 / 上游 | 许可 / 版本线索 | 决定 | 原因与未来迁移门槛 |
|---|---|---|---|
| [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) | MIT；Godot 4.x，近期版本要求较新的 4.x | 不迁移 | 现有对话信号已被 Inner Voice、知识、约定和存档引用；只有当需要专用对白 DSL 且能提供全量存档迁移器时再评估 |
| [QuestSystem](https://github.com/ShomyKohai/quest-system) | MIT；Godot 4.x | 不引入 | `GuidanceSystem` 是从真实证据读取的视图；另建 Quest 状态会与 Dossier 产生双真相 |
| [GLoot](https://github.com/peter-kish/gloot) | MIT；Godot 4.x | 不引入 | 本作核心是有来源的异构证据，不是格子/装备背包；迁移收益低于 metadata 丢失风险 |
| [Godot State Charts](https://github.com/derkork/godot-statecharts) | MIT；Godot 4.x | 不引入 | 胶卷与冲洗链状态少且必须直接序列化；当前显式转换更容易做旧档迁移与幂等测试 |
| [SaveKit](https://github.com/fernforestgames/godot-savekit) | MIT；面向 Godot 4.x | 不引入 | 与现有多旅程、原子回滚、旧档扫描职责重叠；迁移会扩大存档风险 |
| [Lente](https://github.com/mbiggeri/lente-godot-photo-mode) | MIT；Godot 4.x，Camera3D Photo Mode | 只参考 capture 分层 | Solmere 是 2D 世界和 3:2 胶片机，不采用暂停世界的 3D 专业摄影 UI |
| [TimeTick](https://github.com/shoyguer/time-tick) | MIT；Godot 4.x 原生扩展 | 不引入 | 当前分钟制规模不需要平台二进制依赖；所有时间约束已由同一可测试时钟处理 |
| [Input Helper](https://github.com/nathanhoad/godot_input_helper) | MIT；Godot 4.x | 不引入 | `SettingsSystem` 与情境提示已经覆盖本轮键鼠范围；若做手柄热插拔再单独评估 |
| [Sound Manager](https://github.com/nathanhoad/godot_sound_manager) | MIT；Godot 4.x | 不引入 | `WorldSound`、`SoundSettings`、录音总线和 Town Sound 已形成一条验证链 |
| [Skelerealms](https://github.com/SlashScreen/skelerealms) | MIT；Godot 4.x，上游仍偏 Alpha | 只参考 schedule 思路 | 整套 Actor/Cell/GOAP 架构会重复 `ScheduleSystem`，且给七日生活模拟带来不必要迁移面 |

## 4. 数据与存档迁移

- 顶层 `save_version` 继续由 `GameState` 迁移；旧预算按 `starting_budget_version` 校正到 A=12000、B=1600，避免重复补款。
- 旧 `photos` 存在时初始化胶片容器并保留相机可用性；新胶卷、照片用途、房间展示写入 `artifacts.film`。
- `artifacts.economy.version = 3` 保存 receipts、procurement、stock_sold、collections、knowledge_events、appointments；缺字段按空容器补齐。
- `artifacts.residency.version = 3` 由既有页面、流水和真实产物导入；证明始终保留 source / issuer / transaction / trace 标识。
- A/B 角色数据继续隔离在各自 role state；贡献余波等共同世界结果只写入 `shared_state.world_artifacts`，并用唯一 ID 去重。
- UI 节点、事件 ID、居民 ID、地点 ID、玩法 module ID 保持稳定；美术替换不改变存档键。

## 5. UI 保留与验收策略

保留 Solmere 的暖纸、陶土红、灰蓝与近人物对话卡；第三方候选即使未来引入，也只能替换数据/执行层，不得替换纸质地图、RP-07 文件夹、随身记录本、3:2 取景框和横向世界表现。

验收采用两层：领域测试验证幂等、迁移和来源链；正常流程测试通过主菜单、步行、门、柜台、纸张按钮、商店按钮、取景器、录音器和存档文件完成 Player Input → State → Feedback → Persistence → Downstream Effect。实际结果见 `docs/SOLMERE_REQUIREMENTS_ACCEPTANCE_CN.md`。
