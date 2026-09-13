# Solmere / Slice of Days

Godot 4.7.2 横版叙事探索游戏。正面建筑、剖面室内、简化几何与舞台式构图；玩家实际行走，靠近人物、门和物件后互动。主流程继续使用现有剧情、居民关系、七日日程、小游戏和存档系统。

## 怎么玩

- 开始新游戏直接从最左侧小镇街道进入，固定从 A 开始；不选择角色或空白存档槽。
- A / D 或左右方向键行走，Shift 快走，E 与附近人物、门、物件互动。
- 当前对白浮在场景中，E 继续；分支可用数字键选择。没有底部任务、对话记录或操作说明栏。
- J 打开记录。录音、相机、相册以右上角图形图标显示。录音机收起后可边走边录。
- 走进自己的家，走到床边按 E 睡觉。幕间自动切换为 A 第1天 → B 第1天 → A 第2天……；无需移动或对齐计划页。
- 继续游戏自动选择最近的有效存档。新游戏自动分配位置，已有三份旅程时先归档最旧旅程再复用位置。
- 最右端固定为观景台，可以看到大海，21:00 开放；可在入口长椅等待开放。望远镜直接进入保留真实星点深度的 Camera3D 星空，拖动转动镜头，方向键微调。

## 场景范围

严格按《场景需求表(1).docx》保留 15 个地点：

| 从左向右 | 地点 | 室内 |
|---|---|---|
| 1 | 小镇街道公共区域 | 无 |
| 2 | A的家 | 有 |
| 3 | 社区中心 | 有 |
| 4 | 饭店 | 有 |
| 5 | 卖菜兼罐头摊 | 无 |
| 6 | 杂货店 | 有 |
| 7 | 邮局 / 书信事务所 | 有 |
| 8 | 书店 | 有 |
| 9 | 唱片店 | 有 |
| 10 | 塔罗店 | 有 |
| 11 | B的家 | 有 |
| 12 | 下棋摊 | 无 |
| 13 | 公交站 | 无 |
| 14 | 停车区域 | 无 |
| 15 | 观景台 | 无 |

共九个室内、六个仅外部。棋摊按树枝悬挂棋盘布、低棋桌和坐垫的构图；公交站按正面顶棚、长椅、圆形站牌和远山构图。它们没有新增室内。表外旧地点的事件已迁至相应允许场景；部分内部 ID 为兼容原剧情与存档而保留，不代表额外场景。

## 代码入口

- `scripts/ui/walk_stage.gd`：街道/室内共用的移动、镜头、邻近检测和几何绘制。
- `scripts/ui/town_day.gd`：街道上的人物、剧情、门和户外小游戏绑定；复用现有 EventSystem。
- `scripts/ui/interactive_space.gd`：九个室内的物件、对话、睡觉和书店便利贴。
- `scripts/core/scene_router.gd`：淡入淡出、靠近镜头及小游戏返回原房间。
- `scripts/core/chapter_system.gd`：固定十四幕和睡觉触发。
- `data/world/locations.json`：唯一地点清单和顺序。
- `data/world/interactive_spaces.json`：九个室内。
- `data/world/street_objects.json`：菜摊、棋摊、观景台的户外玩法入口。

书店便利贴、唱片与照片当前保存在本机。联网漂流瓶或公共唱片库仍需相应后端；实时棋局读图仍需配置模型服务。建筑与室内目前为可运行的统一几何舞台表现，小游戏保留已有具体画面。

## 运行与检查

在仓库目录运行：

```bash
godot --path .
godot --headless --path . res://scenes/content_validation_test.tscn -- --isolated-save
godot --headless --path . res://scenes/system_smoke_test.tscn -- --isolated-save
godot --headless --path . res://scenes/seven_day_simulation_test.tscn -- --isolated-save
godot --headless --path . --script res://tests/integration/test_interactive_spaces.gd -- --isolated-save
godot --headless --path . --script res://tests/integration/test_walking_journey.gd -- --isolated-save
```

横版回归检查实际覆盖直接开局、左侧出生、十五地点/九室内、最右观景台、连续移动、远处拒绝互动、床边睡觉、自动换主角、小游戏进入/返回和书店便利贴。测试使用独立存档。Godot 4.7.2 在测试进程退出阶段仍有资源回收告警；运行时错误需单独检查，不能只看进程退出码。

随身本按主角区分：A 的灵感本列出当天创作线索，B 的日程本列出当天待办与预约；街道和室内均可按 J 打开。行走有加减速、屈膝抬脚与镜头缓动，对话逐字呈现，E 先补全再继续。

观景台专项检查：`godot --headless --path . --script res://tests/integration/test_observatory_hours.gd -- --isolated-save`，覆盖 21:00 门禁、真实三维星体与摄像机旋转、星座解法、返回街道及两种随身本。
