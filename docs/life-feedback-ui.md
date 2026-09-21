# 生活界面与居民回音

本次改动处理两个实际问题：探索中的提示与天空混在一起、材料和居民之间的后续缺少清楚的来回。保留现有场景美术、存档、对话分支、活动、摄影、录音与旅行系统，改造它们的呈现和连接。

## 视觉与信息层级

- 探索使用海蓝实色承托暖白文字。右上只呈现一个当前方向，分开显示行动、缘由与地点；其下才出现短暂的结果反馈。靠近对象时底部出现可点击、可聚焦的交互提示，调用和键盘相同的实际动作。
- 当前方向优先处理即将到期的约定和晚间收尾，其后尊重玩家主动追踪的线索，再提示可进行的居民回访和当天建议。居民不在时不催促玩家立即前往；Notebook 的回音页会展示下一次可见时间。
- 新一天不再把右侧已经显示的任务重复弹成另一条通知。模态界面内暂缓通知，不消耗阅读时间。多个结果合并，原始事件仍保留在真实记录中。
- 货架与随身包共用物件插图卡片，数量、价格、购买限制和详情来自原有数据。罐头有独立插图；其他小物采用有色手绘简形。购买仍须确认，扣款成功后才更新库存与小票。
- 功能文字统一使用正文字体；手写用于 Notebook 的私人文字。Notebook/Archive 保留纸面，探索、商店、随身包、录音和暂停采用简洁实色/墨色层次。
- 一级页签统一蓝底与选中黄底；键盘焦点有独立描边。设置滑杆显示并改变实际百分比。没有使用完整 UI PNG，也没有透明热点。

## 参考职责

以下是用户指定的参考分工，不意味着照搬各游戏的画面或把它们混为一种皮肤：

| 参考 | 在 Solmere 中对应的规则 |
| --- | --- |
| Dordogne | 随身物导航、清晰的实体分页，统一页签外框 |
| SEASON: A Letter to the Future | 独立七日作品页，实际选择、移动、旋转、缩放和层级编辑 |
| Life is Strange | 从实际经历产生的照片和私人记录 |
| Mutazione / A Short Hike | 保留探索画面，仅保留必要的当前方向与附近交互 |
| Oxenfree / Night in the Woods | 对话留在场景里，选择有真实分支，玩家可以离开 |
| Kentucky Route Zero | 对话排布、停顿、文字层级和克制的过渡，见 dialogue-presentation.md |
| Disco Elysium | 独立的心理话信息层，不做头像栏或大对话框 |
| What Remains of Edith Finch | 进入记忆空间时隐藏全局工具界面 |
| GRIS | 观景与诗意体验以环境和声音反馈，避免分数或 SUCCESS |

本次沿用既有的摄影、拼贴、记忆和对话实现，不声称重新制作了这些系统的全部内容。[SEASON 官方](https://www.play-season.com/)与[Mutazione 发行方页面](https://akuparagames.itch.io/mutazione)用于核对记录与探索的方向；它们的美术没有进入项目。

## 真实的居民来回

`data/story/core_loop.json` 的 11 个活动关系补充了 `relationship`、`share_reply`、`return_reply`。例如，玩家与夏透明做出的塔罗记录可以给尘缘看。尘缘留下针对那件事的回应，玩家再带回给夏透明；不是只弹一句通用的“好感度增加”。

这仍然使用 `CoreLoopSystem.callbacks` 和 `ResidencySystem.materials`：

1. 原活动产出原有唯一材料 ID，登记次日回访。
2. 到实际 NPC 身边，自愿交谈并通过已有分享选项交出该材料。
3. 获得唯一 `reply_<callback id>` 材料，包含原材料 ID、居民、日期和地点。回应可继续用于已有材料系统。
4. 把回应展示给原合作者，保存 `returned`。重复展示不会重复产出回应或刷奖励。

尚未展示材料时，居民只会表示听说过并想看看，不会声称已经持有或看过它。街头争执未结束时，引导先指向实际争执入口；完成后的居民停留位置优先于普通日程。手动追踪同样跟随实际位置，已完成的回访线索退出可行动列表。

旧存档没有新字段时使用缺省值；已有真实分享历史在回访到期后补接回应。没有重置玩家材料、分页、NPC 记录或已完成活动。分享保存失败会回滚材料、关系和状态，同时保留原件。未返还的回应受到材料引用保护。

## 实现位置

- `interface_palette.gd`：字体、颜色、输入框与滑杆 Theme；限制 Label 实际宽度，避免 Godot 4.7 渲染时中文不换行。
- `interface_art.gd`：原生 Control 绘制的海岸线、柜台色块、装订和布面细节，不承载按钮文字。
- `direction_card.gd`、`guidance_toasts.gd`：从 Guidance/CoreLoop 推导的方向和结果组件。
- `goods_card.gd`、`goods_sketch.gd`：货架和背包共用的实际物品卡与插图。
- `gameplay_shell.gd` / `interactive_space.gd`：鼠标提示与 Input Map 接入同一交互方法。
- `living_objects.gd`：Notebook 回音页、统一工具页签、动态背包。

## 资产来源

`art/ui/sea-bean-tin.png` 是本次使用内置 ImageGen 生成的单个透明底物件，1254 × 1254 RGBA。原生成结果直接导入，没有裁切、重绘或将 UI 文字烘焙进图片。用于 `sea_beans`；`pretty_can` 共用同一图案并着色。不是来源于参考游戏的素材。

生成提示的设计内容：

> One isolated short cylindrical sealed food tin, three-quarter view with a visible elliptical lid. Sea-blue and warm-white label, a small lemon-yellow sun, two cream beans and a wavy coastal line. No lettering. Restrained 2D gouache and cut-paper illustration, light printed grain and imperfect edges. Transparent alpha background, no external shadow, no photorealistic or plastic 3D rendering, no wireframe.

## 验证与试玩

所有测试使用隔离的 APPDATA / LOCALAPPDATA 和 `--isolated-save`。不要把测试运行目录指向玩家正常存档目录。

```text
godot --path . --rendering-method gl_compatibility --script res://tests/integration/test_life_feedback.gd -- --isolated-save
godot --headless --path . --script res://tests/integration/test_life_feedback.gd -- --isolated-save --load-only
godot --path . --rendering-method gl_compatibility --script res://tests/integration/test_production_ui.gd -- --isolated-save
godot --path . --rendering-method gl_compatibility --script res://tests/integration/test_dialogue_presentation.gd -- --isolated-save
godot --path . --script res://tools/preview_production_ui.gd -- --isolated-save
```

新增生活/反馈检查覆盖实际按键、点击最近居民、Esc、追踪优先级、事件和日程可达性、回信、重复提交、保存失败回滚，以及跨进程继续回访。既有 production suite 保留全部摄影/录音/货架/旅行/小游戏检查；对话组件的旧断言更新到已实际使用的 `DialogueChoice`。Living UI 的“完全不显示 HUD”旧断言更新为本次明确要求的轻量时间和当前方向，仍检查钱包隐藏、模态中隐藏探索指引。

另运行 Core Loop、Living UI、Optional Dialogue、Native Guidance UI 和 Save Failure Recovery。渲染检查与实际窗口检查都需要执行；headless 字体不能独自证明视觉布局正确。

现有存档和模态系统保持兼容。商品插图仍是静态物件图；交互、数字、反馈和材料流转均来自原生节点与实际游戏状态。新增居民回应覆盖现有 11 类活动，不等同于重写所有 NPC 剧情。
