# 电饭煲、正式顾客与完整录像（2026-09-25）

## 交互与数据

水槽旁干台新增可点击的电饭煲。点击锅盖开合；打开后点击饭体，用饭勺盛出一份带实体碰撞和热状态的米饭。库存只扣一次，空锅不能重复盛取；未加工的米饭可以归还电饭煲。冰箱和完整食材柜均不再出售一份悬空的米饭，菜谱跟做会指向电饭煲。电饭煲位置与水龙头接水区分开，锅仍须由玩家移到水流正下方才接水。

厨房顾客由主游戏 `data/npcs/core_residents.json` 的 12 个稳定 ID 和姓名构成。厨房 `modules/restaurant/data/customers.json` 保留各自口味、等待与反馈字段；每轮将 12 人排成随机队列，订单、评价与出餐展示使用同一顾客身份。主游戏人物设定文件不在本轮编辑范围。

## 美术来源

`modules/restaurant/assets/appliances/rice_cooker_closed.png` 与 `rice_cooker_open.png` 是本轮使用 imagegen 新绘制的透明位图，并非用户提供的原画，也未覆盖团队食材。生成简述：参考现有厨房暖色纸面与平涂笔触，绘制奶油白/鼠尾草绿的小型电饭煲闭盖与开盖状态；两图同视角、同机身，开盖图露出白米饭与饭勺，透明背景，无文字和额外厨房场景。最终导入文件 SHA-256：

- 闭盖：`e885b4eb9f7941330a88988b8a0c9ec0b6c9ccf2026dd7b892fce4e833e11a6f`
- 开盖：`8986f03eec18715f91e89d85f79f53caf6bc2b4a20e687e82d587642857b9673`

## 录像与验证

`tests/capture_full_cooking.gd` 在生产 Godot 场景中注入真实鼠标/键盘事件，依次演示柜层翻页、手持锅至水槽接水至溢出、关水与倒水、开电饭煲盛饭、切番茄、下锅翻炒、敲蛋、加热、挤酱、摆盘、出餐展示、正式 NPC 反馈、将本餐保存为菜谱及翻页。每个关键节点由脚本读取实际世界状态断言。它是自动化游玩录像，不是人工手动试玩，也不代表完整三维流体/软体仿真。

Godot Movie Maker 写出 MJPEG AVI 与 48 kHz 立体声 PCM。`tools/extract_godot_avi.py` 逐块提取真实视频帧和原声，`tools/encode_godot_movie.swift` 使用系统 VideoToolbox 编成 H.264，`tools/mux_godot_movie.swift` 将原声音轨线性增益至无削波后合入，生成仓库 `demo/100Restaurant_Complete_Cooking_20260925_CN.mp4`。验证包括实际 2218 帧 / 24 FPS / 92.42 秒；跨时间抽帧、出餐与菜谱画面抽查，1310 个不同源帧（静止画面自然重复），最长同帧连续 75 帧；MP4 片尾系统解码成功，并确认带非静音原声。开盖实景见 [截图](qa/20260925-rice-cooker-open.jpg)。完整回归条目与结果见 `docs/VALIDATION.md`。
