# 本次可玩更新

已有七天流程、A/B 时间表、居民对话、小游戏、邀请与存档继续使用原有系统。修改位于独立副本 `SOLMERE_Playable`。

## 已接入

- 房间：A 的透光台、B 的采样桌。点击纸张进入记忆，Esc 返回原桌面。
- 记忆：A1–A7、B1–B7 共十四个第一人称房间；另有 A、B 当前房间模型。WASD 移动，鼠标环顾，靠近纸张按 E 查看，Tab 释放鼠标。
- 转场：纸张先占满画面，声音提前进入，摄影机从同一纸面拉回房间。减少动态效果设置会缩短位移。
- 内心声音：八种倾向、角色权重、全局与分类冷却、近期内容去重。设置内可改字号、透明度。
- 书店：九张便利贴、继续翻看、当地留言保存、小刊、报纸。
- 对话：E/F 继续原有聊天；靠近居民按 1 打开简短提问。聊天 12 分钟，提问 4 分钟，时间块不足时不开始。
- 手账：同一条消息更新后保留旧文字，旧版划线，新版保留问号。入口位于手账右上角“改过的记忆”。
- 小镇痕迹：扩展 EchoSystem。预设事件发生后留下当地文字；离线变化上限六小时、单次最多三条，七天主时钟保持原规则。
- 投稿覆盖：开发预览按 F9 查看来源数量。98 个真实投稿席位保留为空，匿名示例单列。

## 本轮边界

这是系统可玩原型。十四个房间使用 Blender 建模的独立陈设；纸面内容和环境声音目前使用原创程序示意素材。剧情依据用户提供的 Script A、Script B，尚未加入角色表演、剧本配音与完整声音设计。

小镇生活使用三条离线示例、三条并行事件示例。当前变化主要通过当地文字显现；可继续在同一事件数据上接入门牌、家具、店铺库存的状态美术。

真实参与者投稿、署名与授权名单尚未提供。现有十二名核心 NPC、原项目的其余日程角色和匿名排版示例，均未计为已验证的 98 名投稿者。

## 文件对应

| 文件 | 用途 |
| --- | --- |
| `data/meta/catalog.json` | 开关、时间消耗、心声、便利贴、报纸、小刊、安全区域、生活事件 |
| `data/meta/memories.json` | 角色、场景、模型、纸张、声音与剧本出处 |
| `data/meta/participant_index.json` | 真实投稿的待填席位与来源口径 |
| `scripts/meta/meta_experience.gd` | 内容入口、心声选择、开发覆盖查询 |
| `scripts/meta/place_layer.gd` | 地点文字及对话、人物、弹窗避让 |
| `scripts/meta/trace_panel.gd` | 便利贴、小刊、报纸、手账旧版 |
| `scripts/meta/ask_panel.gd` | 直接提问 |
| `scripts/meta/memory_entry.gd` | 透光台与可独立播放、调音量的七层声音 |
| `scripts/meta/memory_view.gd` | 同物转场、碰撞、第一人称控制、退出 |
| `model_sources/Solmere_memory_rooms.blend` | 十六个房间的 Blender 源文件 |
| `art/memories` | GLB、SVG、WAV |

存档沿用 GameState.shared_state，新键包括 meta_checkpoint、ambient_applied_at、ambient_traces、memory_visits；KnowledgeSystem 的每条记录新增 revisions。旧存档缺少这些键时按空值处理。可玩副本使用独立用户数据目录 `Solmere_Playable_Meta`。

## 验证

- `test_meta_layer.gd`：100 项检查通过；覆盖十四房间、碰撞、自由退出、A/B 入口、冷却、留言分页、对话计时、修订回读、离线幂等与主时钟。
- 原 `system_smoke_test.tscn` 通过。
- 原 `test_linear_dialogue.gd` 通过。
- 原 `seven_day_simulation_test.tscn` 通过：A/B 原有十二份认可路线仍然成立。
- 图形窗口运行检查通过，预览截图位于本目录 `qa_*.png`。灯光和纸张遮挡已做调整。

运行测试须加 `--isolated-save`，并顺序运行涉及存档的测试。入口命令示例：

```text
Godot --headless --path <项目目录> --script res://tests/integration/test_meta_layer.gd -- --isolated-save
Godot --path <项目目录> -- --meta-preview
```

`--meta-preview` 只添加房间快捷入口和 F9 检查页。常规启动保留游戏原主页。
