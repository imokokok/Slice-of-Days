# SOLMERE 程序检查、优化与验收报告

日期：2026-09-18

引擎：Godot 4.7.2 stable

结论：需求表中的玩法与持久化链路已接入正常游戏；本轮最终矩阵 29 个测试文件、0 个失败。正式发行美术仍需按素材需求表替换程序绘制占位，物理麦克风权限仍需在目标机器人工确认。

## 1. 修改文件清单

### 本轮生产代码修正

- `scripts/ui/town_day.gd`：Day 1 可在 09:00 前进入社区中心等候区，服务柜台仍按营业时间开放。
- `scripts/residency/paper_overlay.gd`：RP-07 图示首页与真实资料袋分层；六份 Starter Paper 首次领取和再次打开都可达。
- `scripts/ui/main_menu.gd`：开场视频增加按真实片长计算的解码兜底，平台不发 `finished` 时也不会卡死新游戏。
- `scripts/photography/film_system.gd`：新档不再给 A 隐形相机；A 付 240 元购买并获得普通卷，B 可用 25 分钟帮忙换二手机和旧库存卷；旧照片存档继续迁移相机所有权。
- `scripts/photography/film_paper.gd`：摄影柜台按角色限制帮助交换入口，保留直接购买、胶卷、送洗和取片。

### 验收与回归更新

- `tests/integration/test_linear_dialogue.gd`
- `tests/integration/test_native_modules.gd`
- `tests/integration/test_network_vertical_slice.gd`
- `tests/integration/test_feedback_systems.gd`
- `tests/integration/test_patch_residency.gd`
- `tests/integration/test_v3_residency.gd`
- `tests/integration/test_v3_film.gd`
- `tests/integration/test_camera_rhythm.gd`
- `tests/integration/test_patch_travel.gd`
- `tests/integration/test_route_layout.gd`
- `tests/integration/test_recorder_movement.gd`
- `tests/integration/test_save_failure_recovery.gd`
- `tests/integration/test_midnight_rollover.gd`
- `tests/integration/test_observatory_hours.gd`
- `tests/integration/test_v2_entry_debug.gd`
- `docs/meta/v2_debug.png`、`docs/patch_map_route.png`：渲染回归证据刷新。

### 交付文档

- `OPEN_SOURCE_INTEGRATION_PLAN.md`：现有系统、去留、候选、迁移、UI 与验收方法。
- `docs/SOLMERE_ART_ASSET_GAPS_CN.md`：17 组正式美术缺口和逐项制作规格。
- `docs/FINAL_TEST_RESULTS.json`：最终机器可读测试矩阵。
- 本报告。

本轮是在现有 V3 可玩实现上做审计与缺口修正。完整系统还包含 `EconomySystem`、`FilmSystem`、`GuidanceSystem`、`ResidencySystem`、`MetaExperience`、纸质地图、横向移动、商店、NPC 与 Town Sound 等既有文件；没有复制第二套同类系统。

## 2. 系统实现说明

### 核心循环与 Day 1

`GuidanceSystem` 从真实 Dossier、知识、消费和约定中推导 Next / Today / Opportunities。Day 1 正常路径为社区中心领取六份资料、读取七日要求、第一次购买并生成小票、向店主问到可用信息、在 Tab 地图比较 Walk/Taxi 与时间冲突、晚上回房用 Organize Mode 把实物放入 Day 1。早到社区中心可进等候区并在柜台等到 09:00，不会被第一步卡死。

### Residency / Dossier

Requirements 与 Seven-Day Portfolio 分层。硬要求由真实证据计算：收入证明 1、生活小票 3 且用途至少 2、三种探索、居民认可 12 且生活圈至少 4、Contribution Proof 1、七日页、个人页和 Why Stay。资料袋六份独立文件、七页作品集、Proof、Recognition、Personal、Loose Papers 均可实际操作；文件位置只是玩家归档选择，不会凭空制造完成状态。

### 地图、时间与交通

Tab 打开纸质地图。地点展示营业状态、已知信息、NPC/事件、Walk/Taxi 分钟、费用和已知冲突。Walk 免费且真实消耗时间，可产生沿路物件与观察；Taxi 更快、扣款并跳过沿路内容。W/S 和路牌跨区函数已经移除，路段边缘不能绕过地图。

### 经济、商店与生活物件

B 新档 1600，住宿不扣款，随身本显示余额、日支出、预算、Proof、约定和知识。A 新档 12000，可购买每日少量变化的收藏并命名、备注和摆放到房间槽位。商店按天库存，购买真实扣款并生成带交易来源的小票。餐厅采购会把番茄、香草和奇异食材放进库存，出餐实际消耗；报销返还同一原票金额、盖章、保留 Living Record 资格且不可重复。

### NPC、Recognition 与约定

短问答、聊天和长相处拥有不同时间成本。BEETMAN 与杂货店主保留购买/问事/闲聊；争吵结束后双方恢复普通 NPC。知识可更新营业时间、路线、折扣、留货、工作和人物出现时间。Recognition 按真实不同事件去重，不把一次对话直接计为认可。约定写入随身本，可赴约或错过；后续对白读取状态，不弹硬扣分。

### Inner Voice 与 Marginalia

指定对话、环境观察、A 的怪商品、B 的消费/打车、争吵结束、第二次见面、时间紧张和错过营业等重要事件走确定触发；日常候选受冷却和安全区约束。调试数据包含 last trigger、candidate、blocked reason、cooldown 和 render success。Marginalia 只在无 NPC 对话、无小游戏、无店铺交互的公共空地可靠出现，按 2–3 波展示 5–9 条，并记录已见状态。

### 摄影、录音与作品余波

A 在杂货店直接购买二手相机；B 看过相机后可帮忙 25 分钟换相机与过期卷。每卷 24 张，3:2 取景，缩放仅 1.0/1.3/1.6，快门有短黑帧且第 25 张被拒绝。普通冲洗次日上午，加急 180 游戏分钟；底片在领取前不进入 Gallery。成片可进 Gallery、Dossier、拼贴、NPC 展示、房间和公共展示。轻量录音器可边走边录、加时间标记并保存到 Field Book / Dossier / 唱片链。作品必须真实交付后才产生唯一公共余波与 Contribution Proof，重复交付不能刷奖励。

## 3. 数据结构说明

| 容器 | 关键字段 | 作用 |
|---|---|---|
| `GameState.role_states[role]` | day, minute, money, inventory, ledger, relationships, appointments, knowledge, artifacts | A/B 私人生活与七日状态隔离 |
| `artifacts.economy` | version, receipts, procurement, stock_sold, collections, knowledge_events, appointments | 商店、原票、报销、动态库存、收藏与约定 |
| Receipt | merchant_id, day, minute, total, category, reimbursable, reimbursed, valid_for_living_record, stamp, source_transaction_id | 真实消费凭证与幂等报销 |
| `artifacts.residency` | version, packet, pages[7], materials, filing, ledger, visits, map_notes, submitted | RP-07 实物与七页作品集 |
| Residency Material | id, kind, title, source, issuer, proof_kind, world_trace_id, filing | Proof 来源、归档和公共贡献链 |
| `artifacts.film` | camera_owned, helped, active_roll, rolls, photo_uses, room_display, collage_selection | 相机、胶卷、照片后续用途 |
| Film Roll | film_type, state, exposures_used, captures, developed_photo_ids, history, ready_day/minute | 24 张与跨日冲洗状态机 |
| Developed Photo | capture_path, developed_path, shown_to_npcs, used_in_collage, submitted_to_dossier | 原底片和纸质副本用途 |
| `shared_state.world_artifacts` | contributions, visible_echoes | A/B 共享的小镇变化与唯一余波 |
| `shared_state.inner_voice_state` | once, last_epoch, faculties, recent, history, event_flags | 确定触发、冷却和已见状态 |

## 4. 迁移内容

- 旧存档由顶层 `save_version` 继续迁移；A/B 启动资金按版本一次性校正，不会重复补款。
- 旧照片存档初始化 `artifacts.film` 时保留相机所有权；新档必须走杂货店获取路径。
- 缺少 V3 经济或 Residency 字段的旧角色状态按空容器补齐，再从既有流水、作品和页面导入，不伪造 Proof。
- 旧连续海岸坐标按地点 ID 迁移到当前 route/arrival；旧 W/S 入口不保留。
- 公共贡献只进 `shared_state.world_artifacts`；角色私人材料仍在各自 role state，唯一 ID 防止重复导入。

## 5. 开源项目使用情况

本轮没有安装或复制第三方运行时代码。Dialogue Manager、QuestSystem、GLoot、State Charts、SaveKit、Lente、TimeTick、Input Helper、Sound Manager 与 Skelerealms 均已评估。现有系统职责完整，引入它们会产生双状态或高风险存档迁移，因此仅参考设计边界。逐项许可、版本线索和未来迁移门槛见 `OPEN_SOURCE_INTEGRATION_PLAN.md`。

## 6. 正常游戏路径验证

已通过真实节点和输入验证：

1. 主菜单点击新游戏并播放开场；即使视频结束信号异常也能进入街道。
2. Day 1 通过 Tab 地图步行到社区中心，进门、在柜台等到 09:00、领取六份资料。
3. F 打开七日册、返回档案首页、再次打开六份文件；要求页链接到真实表单。
4. 商店按钮购买、扣款、生成原票；地图按钮 Walk/Taxi 应用时间和费用。
5. NPC 对话、信息、争吵后聊天、预约和认可均走正常事件入口。
6. C 拿相机、LMB 举起、滚轮缩放、Space 拍满 24 张、送洗、到时领取。
7. R 录音可在室内外移动中持续，保存后进入材料；相机取景时会正确锁定移动。
8. 晚上回房间用 E/F 打开整理桌，拖动物件归档；H 返回 Home。
9. 保存、退出/切场景、重新加载后，钱、时间、票据、胶卷、Dossier 和公共余波保持。

## 7. Save / Load 验证

通过 `test_final_runtime`、`test_v3_residency`、`test_v3_film`、`test_patch_travel` 与 `test_save_failure_recovery` 验证：正常写盘可恢复 Day/Time、Money、Receipts、Reimbursement、Inventory、Film、Exposed Frames、Processing、Gallery、Relationship、Schedule、Appointments、Knowledge、Routes、Marginalia、Inner Voice、Dossier、Night Organization、Collectibles、Room Placement 和 Contribution World State。购买、出行、小游戏退出若写盘失败会回滚到动作前，玩家收到可重试提示。

## 8. 已知问题与非程序交付项

- **正式发行美术未完成**：当前程序绘制与纸卡占位可完整游玩，但须按 `docs/SOLMERE_ART_ASSET_GAPS_CN.md` 交付并替换后再做发行视觉验收。
- **物理录音设备需人工验收**：自动测试覆盖录制状态、移动、时间标记、WAV 保存和材料链；macOS 麦克风隐私授权、具体 USB/蓝牙设备和真实噪声底只能在目标机器确认。
- **渲染测试有焦点前提**：录音移动、胶片/拼贴和视频测试必须在非 headless、窗口有焦点的环境运行；最终矩阵已用该模式通过。
- 没有关键玩法依赖 Debug 菜单、TODO 或手动改变量。Debug 面板只显示 Inner Voice 诊断，不授予进度。

## 9. 缺失美术素材

已提交独立正式需求表，包含名称、用途、尺寸、比例、透明底、分层、动画帧、交互状态、参考与命名规则。重点为：相机正面/手持/取景框、四类胶卷、冲洗纸袋与凭条、通用小票、RP-07 Proof、B Notebook、地图图标、A 收藏、杂货店货架、Marginalia 字体、Gallery contact sheet、房间照片绳和录音纸片。

## 10. 最终验收 Checklist

- [x] Day 1 第一次玩能知道下一步
- [x] 每天有明确硬目标
- [x] 每天有已知机会
- [x] 地图不再用 W/S 切区
- [x] 点击地图地点可以 Walk / Taxi
- [x] Walk 真实消耗时间
- [x] Taxi 真实扣钱
- [x] 已知时间冲突会在决策前显示
- [x] B 初始 1600
- [x] B Notebook 真实更新
- [x] 买东西真实生成小票
- [x] 小票可进入 Living Record
- [x] 餐厅采购可报销且不能重复
- [x] 餐厅采购物真实进入厨房
- [x] A 收藏可实际购买
- [x] A 收藏真实出现在房间
- [x] 罐头摊老板可买、问、聊
- [x] 争吵 NPC 事件后仍可分别闲聊
- [x] Recognition 不是一次对话直接获得
- [x] NPC 人脉可真实改变路线/价格/机会
- [x] 约定可记录、赴约、放鸽子
- [x] Inner Voice 在正常游玩稳定出现
- [x] Inner Voice 必现案例 100% 成功
- [x] Marginalia 在符合条件时稳定出现
- [x] 相机能真实获得
- [x] A 可直接花钱购买相机与普通胶卷
- [x] B 可通过帮店主获得二手相机
- [x] 每卷胶卷 24 张
- [x] 胶卷用完不能继续拍
- [x] 后续可以买胶卷
- [x] 取景框 3:2
- [x] 滚轮有限缩放
- [x] 拍摄有快门反馈
- [x] 杂货店能代收冲洗
- [x] 普通 / 加急冲洗时间不同
- [x] Developing 状态跨场景保存
- [x] 到时间后能回店领取
- [x] 冲洗后照片进入 Gallery
- [x] 照片可进入拼贴诗
- [x] 照片可进入 Dossier
- [x] Recorder 可进入音乐 / Dossier
- [x] 夜间 Organize Mode 有真实物件
- [x] Contribution 后世界会再次反馈
- [x] Save / Load 后所有关键状态保留
- [x] 所有关键行为有即时反馈
- [x] 不存在“只有创作者知道策略”的隐藏玩法

机器可读结果见 `docs/FINAL_TEST_RESULTS.json`。发行前剩余工作是正式美术替换与目标硬件的音频权限验收，不是玩法/存档缺口。
