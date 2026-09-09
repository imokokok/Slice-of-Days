# 100game

Godot 4.7.2 项目。当前版本完成了第一阶段垂直切片：玩家可以从主菜单选择 A 或 B，在同一天的小镇中安排时间、选择交通、追踪居民日程、收集线索，并找到夏透明获得一份居民确认。塔拉牌关系推理作为可进入的独立工作台场景保留。

## 已完成

- 正式进入页面：继续游戏、开始新游戏、设置、制作人员和退出，并通过弹窗选择 A / B 双视角开局。
- A 的连续时间和 B 的碎片时间限制。
- 七个小镇地点、四种交通方式、时间与金钱消耗。
- 数据驱动的 NPC 日程和“此刻在场”查询。
- 图书馆、咖啡馆、夜市和居民对话线索。
- 找到夏透明、对话并获得第 4 份居民确认的闭环目标。
- A 的随身记忆 / B 的计划本。
- 本地存档、读取和继续游戏。
- 固定牌桌、对象—关系—对象推理、塔罗提示能力。
- 统一的温暖手绘小镇界面：奶油纸纹、陶土屋顶、灰蓝与鼠尾草绿点缀，以及柔和的午后光。
- 自动截图入口和核心系统烟雾测试。

## 运行与测试

```bash
godot --path /Users/imokokok/Documents/100game
godot --headless --path /Users/imokokok/Documents/100game res://scenes/system_smoke_test.tscn
```

在进入页面选择“开始新游戏”，再选择 A 或 B。目标是根据线索在第 1 天傍晚到达河岸公园，找到夏透明并取得确认。

## 主要内容入口

- 主菜单：`scenes/main_menu.tscn`
- 小镇日程：`scenes/town_day.tscn`
- 塔拉牌桌：`scenes/tarot_table.tscn`
- 玩家状态：`scripts/core/game_state.gd`
- NPC 日程：`data/npcs/demo_npcs.json`
- 地点：`data/world/locations.json`
- 牌桌案件：`data/tarot/demo_case.json`
- 后续玩法模块登记：`data/gameplay/modules.json`
- 画风参考：`art/reference/`
- 进入页面背景：`art/ui/title-screen-background.png`

正式文本和美术进入项目后，应保持数据 ID 稳定，逐步替换展示文字、人物模型、场景模型、材质、动画和声音。

## 当前边界

这是验证核心体验的垂直切片，不是十个玩法模块和一百位居民的完整制作版。烹饪、代写、翻译、空间错觉、声音采样、棋局、风景、摄影等已登记为数据化模块，但要等对应文本规则和美术资源确定后再进入完整实现。
