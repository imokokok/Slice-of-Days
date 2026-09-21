# Solmere 核心循环与实时引导

2026-09-22。按 Core Gameplay Loop 文档连接现有游戏系统，并修复浅色天空下引导难以阅读的问题。探索中使用实色海蓝底、暖白字；键盘焦点保留黄线，悬停与选中仍为不透明底色。场景美术未替换。

## 玩家流程

新存档直接进入街道，右上角提供一个当前方向。领取申请资料并完成一次自愿对话后，方向变为居民介绍的地点；到达后显示实际活动。活动完成，材料进入原有档案材料表，通知合并为一张短暂反馈卡。后续居民对话引用那件材料，分享相关作品后可以获得真实签记，并继续介绍新的地点。

每天有 3 个以内目标，分别归纳接触、参与和整理。自动生成的“走到某地”记录不冒充参与成果。玩家随时可以自己记录声音、照片或想法；未完成某条可选线索不会挡住回房整理。晚上进入原生 `EveningReview`，查看当天材料、写下感受、休息或打开今天的作品页；系统不自动打开 Notebook。

第七天按已有规则收存个人表达、生活记录、12 位居民签记、七页作品和最终回答。材料未齐不会自动结束申请。夜里在住处可明确选择“再留一晚补齐申请”，恢复该角色的可用时段；计入 `extra_nights`，时间牌显示 `DAY 07 +1`，不会增加第八张作品页或清空已有内容。

## 状态归属

`GameEvents` 只发送事件，不保存第二份游戏状态。

| 领域 | 原有/新增的唯一归属 |
| --- | --- |
| 世界、角色、日期、地点 | `GameState`，保留双主角、日历、预约与日程 |
| 关系、居民签记 | `RelationshipSystem` / `GameState.relationships`、`confirmed_residents` |
| 知识、来源、地点线索 | `KnowledgeSystem` / `shared_state.knowledge_A`、`knowledge_B` |
| 材料元数据 | `ResidencySystem.state().materials[id]`；实际媒体文件仍由 PhotoLibrary/SampleStore 管理 |
| 经济、物品、交易 | 原有 `EconomySystem`、钱包、库存、小票与收入账本 |
| 出行 | 原有 `TravelSystem` 扣费、时长与不同交通产出，`SceneRouter` 执行过场与返回 |
| 七页作品与最终文件 | 原有 `free_pages`、`final_answers`，新增 `final_references[question]` 保存材料 ID |
| 每日循环 | `shared_state.core_loop_A/B`：`days`、`introduced`、`shared`、`callbacks`、`opportunities`、`personal`、`extra_nights` |
| 引导与提示 | `GuidanceSystem` 读取上述状态；持久化追踪与已读记录，内存队列合并短暂反馈 |

`days[day]` 保存当日接触的人、参与成果 ID、整理状态、感受和草稿。回访记录保存 NPC、原材料 ID、模块、可回访日期及是否已回应。材料至少具有 `id/kind/type/source/day/minute/time/location/related_npc` 与用途标志。旧材料在读取时补充兼容字段；原文件、媒体 ID 和 Portfolio 放置 ID 不被重新生成。

事件包括 `LeadDiscovered`、`ObjectiveUpdated`、`ObjectiveCompleted`、`MaterialAdded`、`RelationshipChanged`、`RecognitionGranted`、`TravelCompleted`、`MinigameCompleted`、`WorldCallbackScheduled`。HUD、Notebook 和 Map 共享 `GuidanceSystem` 的只读投影，不分别保存任务完成状态。

## 引导与人物网络

- 优先显示即将结束的机会/约定，其次当前 MUST、玩家追踪线索、私人计划及附近机会。
- 无有效进展每 45 秒增加一级帮助：标题、上下文、来源、地图强调、环境心理文字。移动按键本身不会重置计时。
- `data/story/core_loop.json` 定义 12 位核心居民及杂货店老板的介绍、偏好材料、回应和后续连接。完成一次谈话才记录 encounter，提前退出不确认未听完的回访。
- 分享按钮读取真实材料。重复分享同一件物品不重复获得关系进展。签记条件读取相应活动成果/回访和实际分享，不使用聊天次数门槛。
- Day 4–6 的限时机会保存来源、时段、可重复性和错过后的转述。临近结束只提醒一次；未追踪的已知机会也能提醒。
- 同时产生的 DONE / FOUND / HEARD / CONNECTED 合并，优先重要反馈；对话、工具、菜单与过场期间排队，回到探索再显示。

## 玩法连接

`GameplayModuleSystem.module_completed` 的既有实际结果是接入点。料理、书写/拼贴、音乐、棋、塔罗、观景、视错觉、摄影、档案与翻译模块各有介绍来源、原有费用、原材料 ID、返回地点与人物回访配置。完成后仍执行原模块的经济、声音、贡献和场景返回逻辑；循环只补充关系与后续连接。

Memory Space 读取了实际物件后才产生记忆材料并结算 5 分钟。直接进入再退出不伪造作品。已检查物件 ID 随材料保存，回到小镇后可以进入分享、回访和作品页。

所有活动沿用既有费用校验和 SaveManager。分享、晚间整理、最终提交、续住以及入睡转换保存失败时回滚；草稿可以重试保存。已用于分享、回访、最终引用或作品页的录音不能误删源文件。

## UI 状态策略

`UIStateSystem` 从当前场景和实际模态栈推导状态，供移动、被动时间和提示队列读取。显式交易/活动费用仍由对应 gameplay 系统结算，不因 UI 暂停而免除。

| 状态 | 被动时间 / 日程 | 移动 | Notebook / Map | 反馈与退出 |
| --- | --- | --- | --- | --- |
| EXPLORATION | 推进 | 可用 | 可用 | 即时合并；Input Map 快捷键 |
| DIALOGUE / INTERACTION | 暂停 | 锁定 | 暂停 | 排队；当前界面的返回/Esc |
| CAMERA | 暂停 | 取景锁定 | 暂停 | 排队；相机收起键/Esc |
| RECORDER | 推进 | 可用 | 收起后可用 | 排队；先保存录音再退出 |
| NOTEBOOK / ARCHIVE / MAP | 暂停 | 锁定 | 对应物件导航 | 排队；关闭/Esc |
| TRAVEL | 按路线一次结算 | 锁定 | 暂停 | 排队；抵达后恢复 |
| MINIGAME | 按实际玩法结算 | 玩法接管 | 暂停 | 排队；玩法返回/取消 |
| MEMORY | 返回时结算 | 房间移动 | 暂停 | 排队；先关闭阅读，再退出房间 |
| PAUSE | 场景树暂停 | 锁定 | 暂停 | 排队；继续/Esc |

## 文件范围与验证

新增：`scripts/core/game_events.gd`、`core_loop_system.gd`、`ui_state_system.gd`，`scripts/ui/components/evening_review.gd`，`data/story/core_loop.json`。

连接修改：`project.godot` 自动加载；`chapter_system`、`dialogue_system`、`game_state`、`guidance_system`、`scene_router`；`conversation_panel`、`gameplay_shell`、`living_objects`、`map_paper`、`residency_system`；`guidance_toasts`、`solmere_button`、`media_browser`、`paper_language`；`memory_view`、`memory_objects`。现有场景挂载这些脚本，未另建平行游戏场景。

`tests/integration/test_core_loop_rebuild.gd` 从新存档通过原生对话选项、地图/路线确认、真实声音活动、居民回访与分享、晚间整理、拖入材料、旋转缩放、分页、私人计划、最终引用和实际 3D 物件阅读。另启 `--load-only` 进程核对材料 ID、位置/旋转/大小、关系、回访、每日整理、引用与追踪线索。

其他回归覆盖原生 UI/摄影/录音/音量设置、原生小游戏、保存失败回滚、室内外真实 Input Map 移动、入睡切换主角和世界时钟。测试使用独立 `.runtime/roaming`、`.runtime/local` 与 `--isolated-save`，不覆盖玩家存档。运行截图和日志位于 `.runtime`，不随源码发布。

本次结果：核心循环 80 项通过；独立进程重载 7 项通过；室内外键盘/录音/档案/取景 72 项通过；出行 30 项通过。`test_native_modules`、`test_native_guidance_ui`、`test_save_failure_recovery`、`test_walking_journey`、`test_world_clock` 均通过。核心循环测试输出 8 张实际游戏渲染截图（HUD、NPC 线索、追踪地图、小游戏结果、晚间整理、作品页、最终引用、3D 物件阅读）。
