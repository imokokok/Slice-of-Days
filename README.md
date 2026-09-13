# Solmere

Godot 4.7.2 · PC 横版生活叙事探索。新版以用户确认的《SOLMERE Codex 开发提示词》为准；当前交付为 Day 1 A + Day 2 B 的可玩 vertical slice。完整七天内容和各小游戏的扩展规格仍在分阶段制作，详见 DEV_STATUS.md。

## 现在怎么玩

- A/D 或左右键行走，Shift 快走；走近门、人物、物件按 E。脚步跟随步频，镜头按空间构图缓动。
- M 打开完整小镇地图。地点构成分支网络，公共区分成短舞台，住宅、公交站、停车区域和观景台独立连接。
- 地图展示步行、公交、出租车和符合条件的熟人接送；出发前可见总耗时、票价、等候、到达时间与已知预约冲突。公交只能在站点乘坐，夜间班次减少。
- J 打开 A 的 Pocket 或 B 的 Notebook。A 夹着明信片和纸条，B 记录已知消息、来源、可信度、预算、Pin 和预约。过去谈话可回看，不展示隐藏事件 GPS。
- NPC 对话始终保留场景。E 继续，数字键或鼠标选择话题；按钮支持默认 UI 导航与确认，T 切换逐字显示，Esc 收起。
- 时间只显示 HH:MM。自然计时为现实60秒=游戏5分钟；站着也计时，阅读、菜单与小游戏暂停自然计时。正式行动和交通单独结算显示的分钟数。
- 长椅旁 E 坐下，再按 E 等待30分钟，Esc 起身；观景台旁可等到21:00。海浪循环播放，进室内后减弱。
- 回自己家走到床边睡觉。顺序为 A、B、B、A、B、A，第7天明确选择 A/B；无自由切换键。
- 观景台仍在地图临海尽头，每天21:00开放。近距离操作望远镜直接进入原有真实3D星空，鼠标拖动或方向键调整。

## 范围与保存

仍只有15处玩家地点和9个室内：公共区域、饭店、书信事务所、菜/罐头摊、杂货店、A家、B家、塔罗店、下棋摊、观景台、公交站、停车区域、唱片店、社区中心、书店。内部 public_west/middle/east 仅为程序分区，不显示为玩家区域名。

v4 存档保留旧钱、作品、关系与记录，将旧十四段日程定位到匹配的七天角色日；旧坐标迁移到当前地点。New Game 自动选择存档，Continue 读取最近记录。备份代码分支 backup/pre-network-09129be。

配色参考用户提供的海边建筑图：钴蓝、奶油石色、蓝绿门窗、陶土橙、橄榄绿和少量亮黄；建筑与人物使用原创几何舞台表达。参考图片没有作为游戏背景直接复制。

## 检查

使用 Godot 4.7.2，在仓库目录运行：

```bash
godot --headless --path . scenes/content_validation_test.tscn -- --isolated-save
godot --headless --path . --script tests/integration/test_network_vertical_slice.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_world_clock.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_turn_sit_sea.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_observatory_hours.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_native_modules.gd -- --isolated-save
godot --headless --path . --script tests/integration/test_interactive_spaces.gd -- --isolated-save
```

运行时检查与断言需同时通过；测试退出仍有原有 ObjectDB / resource 回收告警，不能只看进程退出码。旧的十四段轮换、旧核心名单和长街测试保留作为 v3 设计记录，不作为新版本验收。
