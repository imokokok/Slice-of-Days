# 老棋友：三种棋与共享教棋

独立 Godot 4.4+ 项目，保留原始灰度场景。作为 Slice of Days 的独立原型保存，目前尚未接入主游戏场景与主存档。

## 运行

在 Godot 中导入本目录的 `project.godot`，按 F5。

```sh
godot --path prototypes/elder-board-game
```

Windows 可设置 `GODOT_EXE` 为 Godot 可执行文件路径，再运行 `启动游戏.cmd`；也支持 PATH 中的 `godot`。

## 玩法

- 围棋：9 / 13 / 19 路，本地 AI、提子、禁自杀、全局同形禁着、停手与手动死子确认，面积计分，白贴 7.5 子。
- 五子棋：15 路自由规则，无禁手，五子以上也算获胜，AI 会抢胜与防守。
- 国际象棋：合法走法、将军/将死/逼和、王车易位、吃过路兵、四种升变、两层本地搜索。三次重复与 50 回合条件简化为自动和棋。
- 棋后故事：老人从日常琐事谈起，逐步谈及孩子、老伴与后来教他棋的朋友；玩家的不同回应有不同接话，可随时离开。
- A/B 共享棋谱：角色教学草稿与听故事进度分别保存，确认学会的棋共同保留，标注教学者；修改另存版本。
- 教学输入：文字、画纸涂鸦、撤回笔画、导入 PNG/JPG/WebP；老人复述与追问，玩家确认后才能保存并对弈。

主菜单选择角色，点击「教棋 / 共享棋谱」进入。可先用「试教井字棋」体验：告诉老人 → 确认复述 → 下我教的棋。切换另一角色后，从共享棋谱选择同一条目。

## 模型连接与边界

三种预置棋和已保存规则的走棋在本地运行。离线教学仅能解析井字棋等简单连线棋，不具备读图能力。

在「模型连接」中填写支持图片与 JSON 输出的 Chat Completions 完整地址、模型名及密钥后，发送教学消息可获得模型回复。每次发送包含本次教学历史及历史中已发送的附图。密钥只在本次进程内存中，未写入源码或棋谱；可使用 `OPENAI_API_KEY` 环境变量。连接参数目前仅本次运行生效。

当前规则解释器支持自定义连线棋，以及单棋种、固定步长移动/落点吃子/单跳吃子/抵达底线等规则。尚不支持任意棋种、任意生成代码、复杂禁手、重力、连续跳吃或多种自定义棋子。未确认或不受支持的规则不会保存为可玩棋种。模型输出经数据校验，不作为代码执行。

真实云模型调用尚未由此项目进行端到端验证，需自行配置可用服务；已验证离线教学、回答格式校验和存档。

## 本地保存

Godot 的 `user://elder_memory` 保存共享棋谱、角色草稿、教学图片和故事进度，并保留上一版备份。此路径位于操作系统的 Godot 应用数据目录，不在仓库内。A/B 共享指同一电脑、同一系统用户下的这个原型，不是云同步，也尚未对接主游戏 A/B 存档。

## 验证

从本目录运行（`godot` 替换为实际引擎路径）：

```sh
godot --headless --path . --script res://tests/rules_test.gd
godot --headless --path . --script res://tests/scene_test.gd
godot --headless --path . --script res://tests/teaching_test.gd
godot --headless --path . --script res://tests/story_test.gd
```

规则测试包含国际象棋标准 perft 局面、围棋提子/同形/数子与五子棋攻防。教学测试覆盖 A 教/B 玩、B 教/A 玩、确认门槛、图片和涂鸦导出、保存与剧情推进；故事测试覆盖所有回复分支与离开行为。测试使用独立用户数据目录。

可通过 `-- --story-preview` 连续试看新故事，不改变正式进度；`-- --teach` 直接进入教学界面。

## 文件

- `scenes/main.tscn`、`scripts/main.gd`：入口与页面切换。
- `scripts/match.gd`、`grid_rules.gd`、`chess_rules.gd`：预置棋类。
- `scripts/elder_story.gd`、`game_text.gd`：故事和日常对白。
- `scripts/teaching_room.gd`、`teaching_ai.gd`、`sketch_pad.gd`：教学、模型适配与画纸。
- `scripts/teaching_rules.gd`、`learned_match.gd`：规则解释与已学棋对弈。
- `scripts/elder_memory.gd`：本地共享记忆。
- `assets/background.jpg`：用户提供的原始场景；未重绘。

字体使用系统回退（微软雅黑 / Noto Sans CJK SC / PingFang SC，棋子使用符号字体）。跨平台分发需在目标设备检查字体。仓库不包含引擎二进制、本地存档、真实教学记录或密钥。
