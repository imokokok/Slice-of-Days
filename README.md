# Solmere

Godot 4.7.2 项目。当前版本在第一阶段垂直切片上完成了第二阶段游戏骨架：玩家可以从 A 或 B 开始，在两条平行的七天线路之间切换；角色状态、时间、居民关系、认可、剧情事件、地点路线、章节过场和存档均可通过数据持续扩展。Solmere 塔罗海龟汤已作为可完整游玩的独立牌桌场景接入。

## 已完成

- 正式进入页面：继续游戏、开始新游戏、设置、制作人员和退出，并通过弹窗选择 A / B 双视角开局。
- A 的连续时间和 B 的碎片时间限制。
- 七个小镇地点、四种交通方式、时间与金钱消耗。
- 数据驱动的 NPC 日程和“此刻在场”查询。
- 图书馆、咖啡馆、夜市和居民对话线索。
- 找到夏透明、对话并获得第 4 份居民确认的闭环目标。
- A 的随身记忆 / B 的计划本。
- 本地存档、读取和继续游戏。
- Solmere 塔罗海龟汤：四步 Reading 引导、首轮教学牌、洗牌与依次翻牌动效、每轮三选一、22 张暖纸符号牌面、点读意象、本地语义自由提问、YES / NO / 无关、关键牌留阵、防重复线索、一次性交叉解读与 The World 结算。
- 统一的温暖手绘小镇界面：奶油纸纹、陶土屋顶、灰蓝与鼠尾草绿点缀，以及柔和的午后光。
- 自动截图入口和核心系统烟雾测试。
- A/B 两套相互隔离的七天状态与章节推进。
- 数据驱动剧情事件、居民关系记忆和认可状态。
- 可配置的逐日时间块、地点路线图、日记、作品和预约入口。
- 照片对齐章节过场，以及旧存档迁移。
- 按故事大纲录入的 A/B 七天关键灰盒事件。
- 烹饪、代写、误解翻译、声音采样、棋局、发呆、摄影和空间错觉通用玩法工作台。
- 完整计划本/相册界面与第七天双角色审核结局。
- 内容引用校验和 A/B 七天达到 12 份认可的可完成性模拟。

## 运行与测试

```bash
godot --path /Users/imokokok/Documents/100game
godot --headless --path /Users/imokokok/Documents/100game res://scenes/system_smoke_test.tscn
godot --headless --path /Users/imokokok/Documents/100game res://scenes/tarot_mechanic_test.tscn
```

在进入页面选择“开始新游戏”，再选择 A 或 B。目标是根据线索在第 1 天傍晚到达河岸公园，找到夏透明并取得确认。

## 主要内容入口

- 主菜单：`scenes/main_menu.tscn`
- 小镇日程：`scenes/town_day.tscn`
- Solmere 塔罗牌桌：`scenes/tarot_table.tscn`
- 玩家状态：`scripts/core/game_state.gd`
- NPC 日程：`data/npcs/demo_npcs.json`
- 地点：`data/world/locations.json`
- 塔罗牌库：`data/tarot/major_arcana.json`
- 牌桌案件：`data/tarot/cases.json`
- 后续玩法模块登记：`data/gameplay/modules.json`
- 七天时间配置：`data/story/calendar.json`
- 剧情事件：`data/story/events.json`
- 地点路线：`data/world/travel_routes.json`
- 灰盒玩法：`data/gameplay/module_prototypes.json`
- 画风参考：`art/reference/`
- 进入页面背景：`art/ui/title-screen-background.png`

正式文本和美术进入项目后，应保持数据 ID 稳定，逐步替换展示文字、人物模型、场景模型、材质、动画和声音。

## 当前边界

这是已经能够从第1天推进到第7天的灰盒版本，不是十个玩法模块和一百位居民的最终制作版。当前灰盒用于验证路线、条件、选择、时间成本、认可与结局；正式对白、美术、动画、声音和小游戏深度仍可逐项替换。工程结构说明见 `docs/SECOND_STAGE_SKELETON.md`。
