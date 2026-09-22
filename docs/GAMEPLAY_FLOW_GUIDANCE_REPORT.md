# 第二阶段：Gameplay Flow、持续生活世界与反馈引导

2026-09-23。依据《Solmere_GameplayFlow_Feedback_Guidance_CN》，在第一阶段五日制之上改动；既有场景、美术、小游戏核心玩法、十二位居民和原存档系统保留。

## 已实际接入

### 生活物件及认知触发

`scripts/core/chapter_system.gd` 在原 `GameState.shared_state` 中保存 `everyday_objects`。物件只来自真正完成的音乐/信件/菜谱/棋局结果，以及角色原有已报销采购小票；保留 source_id、owner、day、payload、places 和查看者。内部旧 public_traces 兼容字段保留，不作为玩家线索系统。

`scripts/ui/interactive_space.gd` 在 `home_a`、`home_b` 挂载正常可接近的「起居角的唱片与纸张」物件；`scripts/ui/components/everyday_shelf_display.gd` 用既有手绘素材与实际唱片封面、信件预览显示物件。由 `walk_stage.gd` 绘制在原画桌面、人物后方；相邻服务点不会抢走更近物件的交互提示。两间房的公共起居角及社区作品架展示同一组留底/公共作品，私人库存不因此增加。

`scripts/ui/components/public_trace_panel.gd` 从实际物件生成独立图片按钮。可以听真实 WAV、看真实信件留底和原始金额/报销章；没有线索数量、闪光、调查图标或「Trace Found」。Day 1/2 的查看不会触发寻找状态。`echo_system.gd` 移除了无来源的隔夜收据/公交票生成。

Day 3/4 必须实际查看至少两件来自此前另一角色行为的不同物件，重复点击同一件不算。Day 3 可由真实做法与采购小票互相印证；Day 4 可由已完成音乐和信件印证。触发写入 `day3_a_confirmed_other_person` / `day4_b_confirmed_other_person`，随后才改变引导语义。继续复用原功能性交谈，不展开新的 NPC 人设。

Day 4 的约定仍由棋摊内真实交谈选项触发，`arrange_meeting()` 额外核对实际所在地点；没有开日或睡觉自动生成约定。

### 四层反馈

`scripts/core/guidance_system.gd` 的 `possibility()` 从当前日/角色、主活动、采购状态、时段、地点开放状态、可选活动结果、认知状态、约定/揭示状态产生右侧建议。`flow_state()` 暴露这些真实状态用于验证；不是每日静态图片。`core_loop_system.gd` 的原引导入口转接同一函数。

- 环境：首次进入地点产生地点名反馈；`scripts/residency/map_paper.gd` 的独立 LocationMarker 随 GuidanceSystem.updated / GameState.state_changed 刷新，轻度强调当前可推进地点。关闭地点保持可查看，解释关闭原因；`living_objects.gd` 的地点详情同步显示原因。
- 右侧：`gameplay_shell.gd` 和 `components/direction_card.gd` 显示少量建议。阻塞说明优先；完成后提示可以继续探索或回家。不会提前解释另一角色的存在。
- 停滞：45 / 90 / 135 秒依次提示地点时间、活动、明确路线。单纯换地点不再重置停滞检测；真实进展重置。只提示，不自动传送、完成或结束一天。
- 操作：钱和大于等于五分钟的时间变化从实际状态差值生成即时反馈；小游戏进入确认先说明耗时，取消不启动玩法、不扣时间。原按钮 Hover/Pressed/Focus/Disabled 状态继续复用。

音乐制作台 `scripts/town_sound/studio/StudioScreen.gd` 逐步提示放素材→调整/试听→制作唱片；压片完成消耗真实 60 分钟。原音乐原型中不同选择仍按其真实 60/90 分钟成本结算，入口显示最大预计耗时；采购料理根据实际订单为 90 分钟。

### 第五天日程与安全切换

`data/story/calendar.json` 的 Day 5 override：A 可用 08:00–19:00、20:00–22:00；B 可用 07:00–10:00、11:00–12:00、14:00–16:00、18:00–22:00。数据由 `GameState.schedule_for()` / `can_fit_at()` 用于实际旅行和活动约束，并非装饰时间条。

`scripts/ui/components/day_five_planner.gd` 是实际挂载的新 Control，显示两人的真实时段、当前时钟、已过时段和选择按钮。通过 `gameplay_shell.gd` 的「日程与视角」进入；仅在揭示之后可用。`character_system.gd` 核对这个明确入口以及无对话/小游戏/其他模态工具，才允许切换。旧 V 即时切换入口撤除。切换共用世界时钟、当前位置和世界物件，私人物品、关系及成果各自独立。

时段结束后不会自动跳过工作空档。玩家可在日程界面确认「等待到下一段空闲」，明确显示前后时间和消耗，真正推进共享时钟。等待不会伪造工作完成或发工资。若没有更晚时段，等待按钮明确不可用。

`gameplay_module_system.gd` 在开始时检查时段，结果仍按现有 cost / direct_time_minutes 扣时；`scene_router.gd` 的 `request_gameplay()` 提供可取消确认，实际调用原 gameplay_module()。`town_day.gd`、`interactive_space.gd`、`economy_paper.gd`、`conversation_panel.gd` 的正常入口接入此确认。四个主游戏继续使用原场景和代码。

### 主动结束一天及保存

`ChapterSystem.can_end_day()` / `sleep_at_home()` 判断真实条件：Day 1/2 完成主活动即可休息；Day 3/4 完成主活动、生活交互和相关交谈/约定；Day 5 完成见面揭示。`components/evening_review.gd` 打开就说明当前是否可结束，同时保留返回探索按钮。

`chapter_transition.gd` 与原 SaveManager 继续保存角色、世界、叙事及时间后才切日；失败使用既有回滚。格式仍兼容第一阶段五日存档。若旧五日存档没有 everyday_objects，只从其中真实交付和原角色真实小票恢复，不根据天数生成对象。旧七日档仍不兼容并保留原文件。

## 实际验收结果

| 验证 | 结果 |
| --- | --- |
| New Game 连续 Day 1→5，全部可选塔罗/观景台跳过 | `test_five_day_flow.gd`：190 项通过 |
| 第五天 A 真正做菜/下棋，B 真正制作音乐/寄信，原场景实际结算 | 包含在上述 190 项，验证当前角色、耗时、钱包、物品、私人草稿归属 |
| 退出进程再读档，四个交叉结果、双份私人信件、公共物件、五日旧档来源恢复 | `--reload-only`：13 项通过 |
| 分级停滞、无自动推进、即时钱包反馈、地图原节点开放状态更新、关闭原因、确认取消不扣时、真实 A/B 时段差异 | `test_gameplay_guidance.gd`：33 项通过 |
| 原买菜、报销、烹饪、工资与收藏 | `test_v3_economy.gd`：51 项通过 |
| 保留观星图片、交互、介绍显隐与存档回滚 | `test_nebula_telescope.gd`：通过；用例内不可写路径报错为刻意验证失败回滚 |

实际窗口另外读取连续测试产生的第五天存档，观察两栏日程，并用鼠标按「以 A 继续」确认角色状态切换；也点击生活物件图片查看真实菜谱，并检查原画桌面与人物的前后关系。不是直接写 Day 5 或伪造完成标志来替代流程验收。测试脚本和图像取证不使用正式存档槽。

复现：Godot 4.7.2，项目根目录分别启动进程。

```powershell
godot --path . --script tests/integration/test_five_day_flow.gd -- --isolated-save --fresh
godot --headless --path . --script tests/integration/test_five_day_flow.gd -- --isolated-save --reload-only
godot --headless --path . --script tests/integration/test_gameplay_guidance.gd -- --isolated-save
godot --path . --script tests/integration/test_v3_economy.gd -- --isolated-save
godot --path . --script tests/integration/test_nebula_telescope.gd -- --isolated-save
```

## 明确未实现范围

- **NOT IMPLEMENTED（本轮规格明确后置）**：新 NPC 个性/错认层级、完整 Day 3/4 文学剧情、两角色不同小游戏操作数值、新角色动画。保留原功能与素材。
- **NOT IMPLEMENTED（现有项目限制）**：英文完整本地化，仓库仍缺 `localization/en.json`。当前中文流程可运行。
- **NOT IMPLEMENTED（不属于此次流程重构）**：此前所有场景/角色/UI 的最终美术重绘与像素级还原。本轮复用既有原画，新增的是实际节点、状态与反馈。

本报告不宣称所有历史七日测试均通过，也不把模块可打开当作已验证完整结果；核心四项交叉结果已单独实际完成。
