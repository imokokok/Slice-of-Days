# SOLMERE — CODEX 缺失功能强制补实现提示词
## Runtime Integration Patch / 必须实际可玩，不接受“假实现”

> 这是对之前《SOLMERE — CODEX × GODOT 最终完整开发总提示词》的**强制补实现补丁**。
>
> 之前总提示词已经交付，但目前项目里有若干系统只做了外壳、只存在脚本/数据、或根本没有接进真实游戏流程。**这次不要再写设计方案，不要只创建 Manager / JSON / UI Mockup。请直接检查当前 Godot 项目，在现有工程上把下面所有内容接进 active runtime，并实际跑通。**
>
> 不要重做已经正常工作的内容。先识别现有主场景、Autoload、DialogueManager、TimeSystem、Money/CurrencySystem、MapUI、Dossier UI、NPC 数据与争吵事件，再在现有架构上补齐。

---

# 0. “完成”的定义

以下任何一种都**不算完成**：

- 只新建了一个 `.gd` 文件，但没有挂到真实场景；
- 只写了一个 Manager，却没有实际 signal / event 调用；
- 只做了按钮，但点下去没有改变时间、金钱、场景或存档；
- 只创建 JSON / Resource，但游戏里读不到；
- 只写了 TODO / placeholder / dummy text；
- 只在 Debug Scene 能看到，正常开局流程看不到；
- 只打印 log，玩家界面没有表现；
- 只在一个临时测试 NPC 上实现，没有接到真实 NPC；
- 说“系统已支持”，但实际从游戏里无法触发。

本次每项功能必须满足：

1. **正常游戏流程可触发**；
2. **界面有真实反馈**；
3. **正确修改游戏状态**；
4. **Save / Load 后仍然存在**；
5. **不会重复扣钱、重复扣时间或重复发证明**；
6. **能从当前主游戏场景实际测试通过**。

开始开发前先扫描项目，不要自行创建一套和现有系统平行的新架构。

---

# 1. 七日作品集 + Residency 文件系统必须真正实现

目前最大的缺失之一，是之前已经明确要求的 **七日作品集、Starter Packet、RP-07 Dossier 及那些独立文件并没有真正落地到游戏里**。

这次必须把它们做成玩家真的能领取、打开、翻页、看到状态变化的系统。

## 1.1 Day 1 在社区中心真实领取 Starter Packet

第一天玩家在社区中心完成对应交互后，必须获得一个**真实的初始文件包**，包含以下六项独立文件：

1. `WELCOME TO SOLMERE`
2. `WHY SEVEN DAYS?`
3. `RESIDENCY REQUIREMENTS`
4. `A WEEK IN SOLMERE` 七页 Portfolio
5. `RP-07 RESIDENCY DOSSIER`
6. `GUIDE MAP / 小镇基础地图`

这些不能合并成一个网页式菜单。

视觉上要像真正收到的一叠纸和文件夹：
- 文件袋 / 文件夹；
- 独立纸张；
- 可翻页；
- 可查看；
- 有纸张层级和标签；
- Day 1 看起来较薄，后续随着材料增加逐渐变厚。

领取以后：
- `F` 可以随时打开 Residency Dossier；
- `H` 的 Home 入口也能进入；
- 第一次领取时要有明确但克制的 UI 反馈；
- `SaveGame` 必须记录已经领取，不能读档后再次发一套。

## 1.2 `RESIDENCY REQUIREMENTS` 必须是动态清单

第 7 天 18:00 前的正式要求：

- 七日作品集：7 页；
- 有效收入证明 ×1；
- 七日生活记录：收入 / 支出 / 当前余额；
- 探索材料 ×3；
- 居民认可 ×12；
- 贡献记录 ×1；
- Show Yourself；
- Why Stay / 最终居住说明。

这张清单不能只是一张静态图片。

每一项都必须读取真实游戏状态，并显示：
- 未完成；
- 已满足；
- 当前数量，例如 `8 / 12`；
- 对应材料可点击跳转到 Dossier 内相关页。

禁止做总评分、S/A/B 等级或 `87/100`。

## 1.3 七日 Portfolio 必须是实际 7 页

Portfolio 只能有 Day 1–Day 7 七页。
介绍页、制度页、任务清单都属于独立文件，不能混入七页作品集。

Day 页面主题：

- Day 1 — ARRIVAL
- Day 2 — EXPLORE
- Day 3 — SUSTAIN
- Day 4 — CONTRIBUTE
- Day 5 — SHOW YOURSELF
- Day 6 — PEOPLE & PLACES
- Day 7 — WHY STAY?

必须有：
- 当前日期 / Day X / 7；
- 对应问题和记录区域；
- 可放入照片、票根、证明、声音、文字等材料的位置；
- Resident Mark / Recognition 的实际状态；
- A / B 完全独立的数据。

数据必须按 protagonist 分开保存，例如：

```text
portfolio_state[A]
portfolio_state[B]
```

绝对不能 A 填完以后覆盖 B。

## 1.4 Proof 必须是“真实物件”，不是布尔值假完成

至少支持：

- 饭店工作 / 收入证明；
- 唱片店作品归档 / Contribution Proof；
- 代写信 / 工作记录；
- 临时居住证明；
- 交通票据 / 收据；
- 其他现有玩法已经产出的证明。

状态要区分：

```text
contribution_created = true
contribution_proof_collected = false
```

也就是说：完成作品 ≠ 已经拿到正式证明。

玩家可能需要在营业时间内回到店里领取证明。

领取证明时：
- 不可重复发；
- 不可重复结算收入；
- Proof 自动进入 `Loose Papers` 或指定 Proof Tab；
- 玩家晚上可自行整理进 Dossier。

## 1.5 夜间 Organize Mode 要真的可用

晚上在房间打开整理模式时：
- 游戏时间暂停；
- 当天获得的票据、照片、工资单、证明、便签等铺在桌面；
- 玩家可以拖入：
  - Day page
  - Proof
  - Recognition
  - Personal
  - Loose Papers
- 也可以不提交，留在 Field Book / 私人空间。

不要做成自动结算页面。

## 1.6 文件系统验收

请从**正常新游戏**完成以下 smoke test：

1. Day 1 去社区中心；
2. 领取 Starter Packet；
3. 按 `F` 打开；
4. 能分别打开 Welcome / Why Seven Days / Requirements / 7-Day Portfolio / Guide Map；
5. Requirements 显示真实动态状态；
6. 获得一个票据或证明后，Dossier 里能看到；
7. Save；
8. Load；
9. 文件与状态仍然存在；
10. 不会重新发 Starter Packet。

---

# 2. 删除住宅区 / 文化街之间的 W / S 切换

当前实现里，住宅区和文化街需要按 `W` / `S`，或靠路牌来切换区域。

**这一套交互全部取消。**

Solmere 是 2D 横版：

- `A / D` 只负责左右移动；
- `W / S` 不用于区域切换；
- 删除 / 禁用住宅区与文化街之间依赖 `W / S` 的 Scene Change；
- 删除用于这个切换的路牌交互物；
- 不要保留一个隐藏的 W / S fallback。

如果代码里已经有：

```text
if Input.is_action_pressed("move_up"):
    change_area(...)
```

或同类逻辑，请从 active gameplay path 中移除。

---

# 3. 区域移动改为“地图选点 + 步行 / 打车”

按 `Tab` 打开地图。

地图仍然是大面积纸质 Overlay，打开时游戏内时间暂停。

现在地图除了查看，还必须支持**地点旅行**。

## 3.1 点击地图地点

地图上的可访问地点必须是可点击的：

例如：
- 住宅区；
- 文化街；
- 社区中心；
- 唱片店；
- 书店兼图书馆；
- 饭店；
- 邮局 / 书信相关地点；
- 买菜摊 / 罐头摊；
- 观景台；
- 当前工程里已经存在的其他正式场景。

不要为了本补丁新造不存在的地点。

点击一个不在当前场景的地点后，弹出简洁的 Route Choice：

```text
去往：唱片店

步行      24 min      $0
打车       8 min      $X

取消
```

数值必须从统一的 Travel / Economy 配置读取，不要把每个按钮的数字散落硬编码在 UI 脚本里。

若项目已有距离 / 时间 / 金钱配置，优先复用。
若没有，则建立单一数据源，例如：

```text
travel_routes.json
```

或 Godot Resource。

每一对地点可以配置：

```text
from

to
walk_minutes
taxi_minutes
taxi_cost
arrival_spawn_id
```

## 3.2 步行

选择“步行”：
- 不扣钱；
- 调用真实 `TimeSystem.advance_minutes()`；
- 消耗对应时间；
- 加载目标场景；
- 出现在目标地点正确 spawn point；
- 地图关闭后才恢复游戏。

不要真的让玩家在 loading screen 等 24 分钟。
这是游戏内时间成本。

## 3.3 打车

选择“打车”：
- 检查真实当前余额；
- 余额不足时按钮 disabled 或给出自然提示；
- 成功时只扣一次车费；
- 消耗少于步行的时间；
- 加载同一目标场景；
- 到正确 spawn point。

禁止：
- 点击两次扣两次；
- Scene Load 又扣一次；
- Save / Load 后重复扣款；
- 地图打开期间后台继续走时间。

## 3.4 当前地点

点当前所在地：
- 不弹旅行确认；
- 显示 `你已经在这里` 或直接不响应；
- 不扣时间，不扣钱。

## 3.5 地图旅行验收

必须实际测试：

1. 从住宅区按 `Tab`；
2. 点击文化街；
3. 选择步行；
4. 游戏时间增加，金钱不变；
5. 正确到文化街；
6. 再打开地图，点击住宅区；
7. 选择打车；
8. 金钱减少一次，时间减少正确；
9. 正确回住宅区；
10. 全程不需要 W / S，也没有切区路牌。

---

# 4. Inner Voices / 心理话目前是假实现，必须接进真实 runtime

当前项目里的“心理话”如果只是：
- 有脚本；
- 有 Manager；
- 有测试文本；
- 有一个永远不会被真实对话调用的 Layer；

都视为**未实现**。

这次必须让它在正常游戏里真实出现。

## 4.1 必须接入真实 DialogueManager

使用当前项目真正负责 NPC 对话显示的系统。

真实调用链必须类似：

```text
DialogueManager
→ dialogue_line_presented(context)
→ InnerVoiceManager.request_thought(context)
→ candidate filtering
→ choose 0–2
→ InnerVoiceLayer.show_thought()
```

不要另写一个完全平行的假 DialogueManager。

`context` 至少应包含：

```text
speaker_id
npc_id
location_id
event_id
dialogue_id
line_id
protagonist_id
time_of_day
flags / world_state
```

## 4.2 必须接环境观察点

至少支持：

```text
ObservationHotspot
→ InnerVoiceManager
→ optional thought
```

例如：
- 看见一个奇怪物件；
- 某店关门；
- 争吵结束后的现场；
- 某个声音 / 海报 / 桌面。

不要每帧随机弹。

## 4.3 心理话内容规则

后台可有：
- empathy
- reason
- wonder
- taste
- play
- memory
- instinct
- ambition

但屏幕上**绝对不显示这些属性名**。

心理话整体比例：
- 60% 日常 / 审美 / 走神 / 好笑 / 没用；
- 25% 实用判断 / 关系判断；
- 10% 内部矛盾；
- 5% 真正沉重。

不要做成焦虑模拟器。

不要出现：
- `EMPATHY +1`
- `Reason Check Passed`
- RPG 技能数值

视觉：
- 柔软手写感；
- 小；
- 在留白里出现；
- 1.8–4 秒；
- fade in / fade out；
- 不挡对话、不挡脸、不挡互动按钮。

## 4.4 必须做“确定能看到”的验收触发点

为了防止系统又变成“理论上支持但我玩不到”，请指定至少三个**确定测试点**：

### Test A — 罐头摊老板聊天
第一次完整闲聊中的某一条指定 line 必须有 1 条 authored Inner Voice 候选。

### Test B — 两人争吵结束
玩家听完争吵后，现场必须有一个 observation / event trigger，可出现一条心理话。

### Test C — 任意已存在的普通 NPC 对话
指定一个真实 NPC 的一条普通闲聊 line，确认 DialogueManager signal → InnerVoiceLayer 全链路工作。

测试模式可以让这三处固定命中，以证明系统接通。
正式游戏再恢复正常权重 / cooldown。

## 4.5 Debug 只用于验证，不是玩家实现

增加开发日志，例如：

```text
[InnerVoice] trigger=line_023
[InnerVoice] protagonist=A
[InnerVoice] candidates=3
[InnerVoice] selected=thought_beetman_02
```

如果没出现，要能看到 blocking reason：

```text
cooldown
no_candidate
ui_blocked
important_silence
wrong_protagonist
```

但玩家正式 UI 不显示这些 debug 信息。

## 4.6 Inner Voice Save / Load

保存：
- 已触发的一次性 thought；
- cooldown 必要状态；
- 主角差异；
- event flags。

不要读档后连续重播一次性心理话。

---

# 5. 罐头摊老板不能只有“买罐头”

现有买菜摊 / 罐头摊老板（项目现有 NPC 数据里对应的摊主，若当前 ID 是 BEETMAN 则继续复用）必须是**正常 NPC + 商店功能**，而不是 vending machine。

## 5.1 靠近时的交互

正常世界状态：

- `E` = 聊一会儿；
- `1` = 问点事；
- 购买罐头是聊天 / 交互里的一个分支，不要让 `E` 直接无条件打开 Shop UI。

可以是：

```text
E 聊一会儿

对话中：
- 随便聊聊
- 看看今天有什么罐头
- 问点事
- 走了
```

或复用当前项目已经有的 Dialogue Choice 样式。

不要新增一个风格完全不同的 RPG 菜单。

## 5.2 闲聊必须真实存在

至少准备一个可重复轮换的小型闲聊池。

内容应以当前 NPC 已有设定为基础，例如：
- 摊位本身；
- 罐头；
- 买菜；
- 今天生意；
- 小镇里的普通琐事；
- 书店兼图书馆等该 NPC 已有地点关系。

不要突然给他编新的重大身世。

不是每句话都给任务。
不是每次聊天都推动 Residency。
允许纯闲聊。

## 5.3 聊天和购物必须分开结算

- 聊天按当前对话时间规则消耗时间，例如 `E 聊一会儿` 的既有逻辑；
- 打开购买 UI 本身不要重复扣一整次聊天时间；
- 买罐头只按商品价格扣钱；
- 退出购物后仍可继续聊天；
- 不要求玩家先购买才能认识 / 聊 NPC。

---

# 6. 两个人争吵以后，仍然要能和他们聊天

当前争吵事件如果只是：

```text
玩家靠近
→ 两人争吵
→ event ends
→ NPC 变成不可交互 / 消失 / 只剩任务结论
```

这是不完整的。

玩家听完争吵后，必须还能分别靠近这两个人，并和他们聊一些**普通的、没有任务目的的闲话**。

## 6.1 Event State

争吵结束设置：

```text
argument_seen = true
argument_finished = true
```

两个 NPC 都进入 `post_argument` 对话状态。

不要强制：
- 玩家判断谁对谁错；
- 玩家选边站；
- 立刻让两人和好；
- 立刻把事件变成 Quest Completion。

## 6.2 争吵后两个 NPC 都可交互

对每个人：

- `E` = 聊一会儿；
- `1` = 如果有相关问题，可以直接问；
- 至少存在一组 `post_argument_smalltalk`；
- 其中要有**和刚才争吵完全无关的闲聊**。

例如可以聊：
- 天气 / 店铺 / 吃的；
- 今天去哪；
- 手里的东西；
- 某个普通小镇细节；
- 一句没什么用的话。

不要所有台词都围绕：
“你怎么看刚才的争吵？”

真实的人吵完架以后，也仍然可以聊别的。

## 6.3 如果 NPC 按日程离开

不要为了让玩家聊天而破坏 Schedule System。

正确做法：
- 争吵刚结束后留一个合理的可交互窗口；
- 之后 NPC 可以继续自己的日程；
- `argument_seen` 状态持久化；
- 玩家以后再遇到她们时，仍能进入对应的 post-event 对话池。

## 6.4 已有“重复聊天”NPC要继续保留

如果项目现有 NPC 数据里已经有“争执事件路人 / 重复聊天”这类设定，请直接复用，不要另造一个重复角色。

---

# 7. 这几个系统要互相连起来，不要各做各的

这次尤其要避免“每个文件都存在，但彼此没有关系”。

至少完成以下真实连接：

## 7.1 地图旅行 ↔ Time / Money

```text
MapUI
→ RouteChoice
→ TimeSystem
→ CurrencySystem
→ SceneLoader
→ SaveGame
```

## 7.2 对话 ↔ Inner Voices

```text
DialogueManager
→ InnerVoiceManager
→ InnerVoiceLayer
```

## 7.3 NPC ↔ 闲聊 / 商店

```text
NPCInteraction
→ Dialogue
→ optional Shop
→ back to Dialogue / World
```

## 7.4 争吵事件 ↔ 后续 NPC 状态

```text
ArgumentEvent
→ WorldState.argument_finished
→ NPC post_argument dialogue
→ SaveGame
```

## 7.5 玩法 / 证明 ↔ Residency Dossier

```text
Activity / Job / Contribution
→ Proof generated
→ Inventory / Loose Papers
→ Dossier
→ Requirements checklist
→ SaveGame
```

---

# 8. UI 仍然遵守现有 Solmere 规范

不要因为补功能又做出一套新 UI。

继续使用：

- 左上小型 `RP-07`；
- 右上 Day / Time + contextual hints；
- sky blue key prompt；
- fade in / fade out；
- 无常驻底部大条；
- 无圆形 minimap；
- Dialogue 卡靠近说话 NPC；
- Map / Gallery / Field Book / Dossier 打开时暂停游戏内时间。

地图旅行选择框也要延续纸张 / editorial / 轻 UI 的感觉，不要像 RPG Fast Travel 菜单。

---

# 9. 禁止新增的错误行为

本补丁明确禁止：

- 用 `W / S` 在住宅区和文化街切换；
- 保留切区路牌；
- 点击地图直接免费瞬移；
- 打车只做动画但不扣钱；
- 步行只写“24 min”但时间不变；
- 地图打开期间时间继续走；
- Inner Voices 只存在 Manager，游戏里不出现；
- 每次心理话都很沉重；
- 罐头摊老板只会打开商店；
- 争吵结束后 NPC 失去普通对话；
- 七日 Portfolio 只是静态图片；
- Dossier 只是一个 Quest List；
- Proof 只是隐藏 bool；
- 新建第二套 Time / Money / Dialogue / Save 系统来绕过现有系统。

---

# 10. 开发完成后必须自行跑的验收流程

请不要只告诉我“已实现”。

至少实际跑以下流程：

### A. Residency
- 新游戏；
- Day 1 社区中心；
- 领取六项 Starter Packet 文件；
- `F` 打开；
- 看 7 页 Portfolio；
- Save / Load；
- 文件仍在。

### B. 地图旅行
- 住宅区；
- `Tab`；
- 点文化街；
- 步行；
- 时间真实变化；
- 回程打车；
- 金钱和时间真实变化；
- 无 W/S、无路牌。

### C. Inner Voice
- 与真实罐头摊老板闲聊；
- 至少一次指定 line 真实触发心理话；
- 心理话 UI 可见；
- 不挡对话；
- Save / Load 后一次性 thought 不乱重播。

### D. 罐头摊
- `E` 可以聊天；
- 不自动强制购买；
- 可以从聊天进入购物；
- 退出购物后仍能继续交互。

### E. 争吵
- 玩家听完整场争吵；
- 事件结束；
- 分别走近两个人；
- 两个人都能聊天；
- 至少有一条与争吵无关的闲聊；
- 离开 / Save / Load 后 post-event 状态仍正确。

---

# 11. 完成后请给出实施报告

完成开发后，请输出一个简短、具体的报告，不要写空泛总结。

必须列出：

1. 修改了哪些现有场景；
2. 修改 / 新增了哪些脚本；
3. 哪些 signal 已经连接；
4. 哪些 UI 已接进真实 gameplay；
5. Starter Packet / Portfolio 的真实入口在哪里；
6. 地图旅行具体从哪个 MapUI 触发；
7. Inner Voice 的三个确定验收触发点；
8. 罐头摊老板的聊天入口；
9. 争吵事件后两个 NPC 的 post-event dialogue 入口；
10. 实际跑过哪些测试；
11. 如果仍有内容素材缺失，只能列在 `MISSING_CONTENT.md`，**不能用“缺素材”作为不接 runtime 的理由**。

---

# 12. 最后一次强调

这次任务的重点不是“系统设计得更完整”，而是：

> **之前写在提示词里的东西，现在必须真的在游戏里发生。**

玩家需要真实地：

- 收到并翻阅七日作品集和整套 Residency 文件；
- 从地图选择目的地；
- 在步行时间与打车费用之间做选择；
- 在真实对话中看到心理话；
- 和罐头摊老板聊天，而不只是买东西；
- 听完一场争吵以后，仍然可以走过去和那两个人聊些没那么重要的话。

不要再停留在“架构已预留”“Manager 已创建”“数据表已准备”的层面。

**请直接在当前项目上实现、连接、运行、测试。**
