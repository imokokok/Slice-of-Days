# Solmere

Godot 4.7.2 · PC 横版生活叙事探索。新版以用户确认的《SOLMERE Codex 开发提示词》为准；当前交付为 Day 1 A + Day 2 B 的可玩 vertical slice。完整七天内容和各小游戏的扩展规格仍在分阶段制作，详见 DEV_STATUS.md。

## 现在怎么玩

- A/D 或左右键行走，Shift 快走；走近门、人物、物件按 E 或 F。世界互动只使用这一组键，其他功能都有独立快捷键。
- M 打开完整小镇地图。地点构成分支网络，公共区分成短舞台，住宅、公交站、停车区域和观景台独立连接。
- 地图展示步行、公交、出租车和符合条件的熟人接送；出发前可见总耗时、票价、等候、到达时间与已知预约冲突。公交只能在站点乘坐，夜间班次减少。
- J 或 Tab 打开 A 的 Pocket / B 的 Notebook；M 打开地图；R 打开录音，C 打开相机，P 打开相册。过去谈话可回看，不展示隐藏事件 GPS。
- NPC 对话始终保留场景。Space / Enter 继续，直接点击完整回应句子或用方向键与 Enter 选择，T 切换逐字显示，Esc 自然告别；不再使用 1/2/3/4 话题菜单。
- 顶栏持续显示钱包余额。菜摊和杂货店可实际购买，扣款与收入进入收支记录，食材进入随身物品，并会在饭店烹饪中优先消耗。交通、工作和玩法收入也使用同一钱包。
- 两人都在07:00起床、22:00休息。A先晨跑到08:00，19:00—20:00夜跑；B从07:00可直接行动，但三段远程工作会切开白天。界面持续区分碎片与整块，并给出返家工作所需的最晚出发时间。
- 相机使用全屏取景器：拖拽或方向键构图、滚轮变焦、Space快门；对准景物会识别名字并生成即时照片卡，照片与观察笔记进入景物相册。录音默认采集游戏声景，R开始/停止、Ctrl/Cmd+S保存，真实麦克风保持为清楚标注的可选项。
- 时间只显示 HH:MM。自然计时为现实60秒=游戏15分钟；站着也计时，阅读、菜单与小游戏暂停自然计时。正式行动和交通单独结算显示的分钟数。
- 长椅旁 E 坐下，再按 E 等待30分钟，Esc 起身；观景台旁可等到20:00。海浪循环播放，进室内后减弱。
- 回自己家走到床边睡觉。顺序为 A、B、B、A、B、A，第7天明确选择 A/B；无自由切换键。
- 观景台仍在地图临海尽头，每天20:00开放。近距离操作望远镜直接进入原有真实3D星空，鼠标拖动或方向键调整。

## 范围与保存

仍只有15处玩家地点和9个室内：公共区域、饭店、书信事务所、菜/罐头摊、杂货店、A家、B家、塔罗店、下棋摊、观景台、公交站、停车区域、唱片店、社区中心、书店。内部 public_west/middle/east 仅为程序分区，不显示为玩家区域名。

v5 存档新增随身物品、收支记录与固定工作状态，并兼容 v4/v3 的旧钱、作品、关系与记录；旧十四段日程仍会定位到匹配的七天角色日。New Game 自动选择存档，Continue 读取最近记录。备份代码分支 backup/pre-network-09129be。

配色参考用户提供的海边建筑图：钴蓝、奶油石色、蓝绿门窗、陶土橙、橄榄绿和少量亮黄；建筑与人物使用原创几何舞台表达。参考图片没有作为游戏背景直接复制。

## 检查

使用 Godot 4.7.2，在仓库目录运行：

### 协作原型：万景塔罗海龟汤

新增独立原型 [prototypes/myriorama-tarot](prototypes/myriorama-tarot/README.md)，含18种有效牌、逐张抽牌、离线提问库、万景入门与完整真相判断。请单独导入该目录的 `project.godot`；不会替换主游戏的 Solmere 塔罗场景。测试及素材说明见原型 README。

```bash
godot --headless --path . scenes/content_validation_test.tscn -- --isolated-save
godot --headless --path . scenes/system_smoke_test.tscn -- --isolated-save
godot --headless --path . --script tests/integration/test_network_vertical_slice.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_world_clock.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_turn_sit_sea.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_observatory_hours.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_walking_journey.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_minigame_invitations.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_myriorama_entry.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_native_modules.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_interactive_spaces.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_feedback_systems.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_camera_rhythm.gd -- --isolated-save
```

运行时检查与断言需同时通过；测试退出仍有原有 ObjectDB / resource 回收告警，不能只看进程退出码。旧的十四段轮换测试保留作为 v3 设计记录，不作为新版本验收。
