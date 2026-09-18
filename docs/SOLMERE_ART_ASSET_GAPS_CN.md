# SOLMERE 正式美术素材需求表

版本：2026-09-18

用途：替换当前程序绘制、通用纸卡或临时图标；这些占位已能完成玩法与验收，但不应直接作为最终发行美术。所有尺寸均按 1600×900 基准设计，并需在 1280×720 与 1600×900 检查裁切和文字安全区。

## 交付约定

- 色彩：暖纸色、陶土红、灰蓝、鼠尾草绿；克制颗粒，避免现代手机/专业相机 UI。
- PNG 使用 sRGB；需要缩放的线框可另交 SVG，但工程内最终文件名保持下表约定。
- 分层源文件交 `.kra` 或 `.psd`；图层名使用英文小写与下划线。
- 文件名：`{system}_{object}_{state}_{size}_v01.png`，序列帧追加 `_f00`。
- 稳定 ID、节点和 JSON 字段不可随美术命名变化；只替换资源路径。

## 缺口与规格

| 名称 | 用途 | 尺寸 / 比例 | 透明底 | 分层 / 动画帧 | 交互状态 | 视觉参考 | 最终文件名 |
|---|---|---|---|---|---|---|---|
| 轻便胶片相机正面 | 杂货店陈列、取得相机、随身物件 | 1024×768，4:3 | 是 | 机身、镜头、背带、反光分层；无逐帧 | normal / hover / acquired | 小型塑料日用胶片机，略有使用痕迹 | `camera_compact_front_1024x768_v01.png` |
| 手持相机状态 | C 键拿出但仍可行走 | 800×450，16:9 安全区 | 是 | 左手、右手、相机三层；2 帧轻微呼吸 | idle / raise_hint / no_film | TOEM 的主动观察感，但不做卡通相机 HUD | `camera_held_idle_800x450_v01_f00.png` |
| 3:2 取景框 | 举起相机后的固定取景 UI | 1200×800，3:2 开口 | 是 | 边框、中心点、计数、胶卷名分层；无动画 | normal / shutter / full_roll | 轻量光学框，禁止 ISO、快门、电池、准星 | `camera_viewfinder_3x2_1200x800_v01.png` |
| 快门短黑帧 | 0.08–0.12 秒机械反馈 | 1200×800，3:2 | 是 | 单层；2 帧（闭合 / 回弹） | shutter_down / release | 机械叶片感，不用大型 PHOTO SAVED | `camera_shutter_frame_1200x800_v01_f00.png` |
| 四类胶卷包装 | 商店库存、胶卷纸、Gallery 状态 | 每款 512×512，1:1 | 是 | 包装与标签分层；无动画 | normal / expired / bw / night；available / sold_out | 小镇杂货包装，旧库存允许褪色与贴价签 | `film_pack_{normal|expired|bw|night}_512_v01.png` |
| 冲洗纸袋 | Drop-off / Pickup 实物 | 900×600，3:2 | 是 | 袋体、封口、手写编号、污渍分层 | dropped / processing / ready / opened | 牛皮纸冲洗袋，生活化柜台笔迹 | `film_envelope_{state}_900x600_v01.png` |
| 冲洗凭条 | Loose Papers 与取片证明 | 600×1000，3:5 | 是 | 底纸、印字、手写时间、印章分层 | standard / rush / picked_up | 小票热敏纸 + 店主手写时间 | `film_ticket_{standard|rush}_600x1000_v01.png` |
| 通用消费小票 | Living Record、报销、Dossier | 600×1100，约 6:11 | 是 | 商户头、明细、金额、注记、章位分层 | valid / reimbursable / reimbursed / invalid | 热敏纸轻卷边；盖章后仍可读原文 | `receipt_generic_600x1100_v01.png` |
| RP-07 Proof 纸张组 | Income / Contribution / Recognition / Explore | 每张 1000×1400，5:7 | 是 | 底纸、规则线、印章、签名区分层 | blank / earned / filed / submitted | 社区中心真实纸档，不像任务菜单 | `dossier_proof_{kind}_1000x1400_v01.png` |
| B 随身 Notebook 页面 | Today / Money / Notes / Proof / Thoughts | 1400×900，14:9 | 否 | 纸页、标签、手写层、夹页分层 | normal / selected_tab / overdue_note | B 的生活笔记，不用教程口吻 | `notebook_b_{tab}_1400x900_v01.png` |
| 纸质地图图标组 | 已知地点、营业与事件状态 | 96×96，1:1 | 是 | 每图标单层；无动画 | known / closed / event / selected / unknown | 手绘蓝铅笔与盖章，不做圆形 minimap | `map_icon_{location}_{state}_96_v01.png` |
| A 收藏物套组 | 商店、房间桌面/架子/墙面、Dossier | 单物 512×512，1:1 | 是 | 物体与阴影分层；无动画 | shop / owned / placed / selected | 旧明信片、丑杯子、钥匙牌、徽章、贴纸、旧照片、盐罐、手工 CD、摆件、罐头 | `collectible_a_{id}_512_v01.png` |
| 杂货店新增货架 | 胶卷、配件、采购品与奇异食材陈列 | 1600×900，16:9 | 否 | 背景、三层货架、前景遮挡、商品槽分层 | day_variant_1/2/3 / closed | 重复访问可见少量变化，不做随机装备商店 | `shop_grocery_shelf_day{n}_1600x900_v01.png` |
| Marginalia 手写状态 | 公共记忆 2–3 波展示 | 字体源 + 2048×512 测试条 | 是 | 每种笔触独立层；无逐帧 | pencil / pen / crossed_out / corrected / faded | 不同居民笔迹，允许纠正、错误和无上下文句子 | `marginalia_hand_{style}_2048x512_v01.png` |
| Gallery 接触印样 | 24 张、冲洗状态与照片用途 | 1600×900，16:9 | 否 | 底纸、24 格、编号、胶卷标签、选中框分层 | processing / developed / selected / used | 胶片 contact sheet，不做手机相册 | `gallery_contact_sheet_1600x900_v01.png` |
| 房间照片绳与夹子 | 冲洗照片真实展示 | 1400×500，14:5 | 是 | 绳、夹子、照片槽、投影分层 | empty / occupied / selected | 生活化纸质照片展示，可容纳不同 3:2 成片 | `room_photo_line_1400x500_v01.png` |
| 录音素材纸片 | Field Book / Dossier / 唱片工作台 | 900×420，15:7 | 是 | 波形、标题、时长、地点、胶带分层 | raw / marked / used_in_cd / filed | 纸张波形与手写时间戳，不做 DAW 专业面板 | `recorder_sample_card_900x420_v01.png` |

## 当前占位与替换入口

- 相机与取景框当前由 `scripts/town_sound/PocketCamera.gd`、`scripts/photography/camera_frame.gd` 程序绘制。
- 胶卷、冲洗与 Gallery 当前由 `film_paper.gd`、`PhotoAlbum.gd` 和主题控件组成。
- 小票、Proof、Notebook 和地图当前由 `paper_overlay.gd`、`economy_paper.gd`、`map_paper.gd` 生成。
- A 收藏物和照片绳当前由 `collection_display.gd`、`room_photo_display.gd` 以几何图形绘制。
- Marginalia 当前使用系统楷体回退；正式字库必须确认商业授权并覆盖简体中文。

替换后必须重跑 `test_supplied_art.gd`、`test_v3_film.gd`、`test_patch_residency.gd`，并手工检查两种窗口尺寸、中文/英文、色弱对比、点击区域与旧存档。
