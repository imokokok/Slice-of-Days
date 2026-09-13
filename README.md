# Solmere

## 随身录音、拍照与唱片店 / Town Sound

[Town Sound 使用说明](prototypes/town-sound/README.md)：主游戏小镇右上角有录音、相机、相册三个图标。录音和游戏内照片保存在本机；抵达“潮声唱片”室内后，可从唱片制作台进入编曲、动态视觉、封面、十一段压片仪式和本地唱片架。声音素材会记录 A/B 视角、游戏日、时刻、地点、在场居民、关联事件和使用范围；真实麦克风及含在场居民的采样默认仅限本地。A/B 拥有独立 Studio 工程，唱片授权费进入主游戏钱包且同一唱片不会重复结算。公共后端尚未部署时自动保持可完整运行的 Local Mode。

## 独立原型：拼贴书信

[拼贴书信源码与运行说明](prototypes/collage-letter/README.md)：刻刀裁切、33 份素材、拼贴书信与火漆封装，以及含服务端的漂流瓶互寄/回信系统。可运行内容已复制到 `extensions/collage_letter/` 并由海盐书信事务所接入主游戏；原型目录继续作为独立开发源保存。

Godot 4.7.2 项目。当前版本在第一阶段垂直切片上完成了第二阶段游戏骨架：玩家可以从 A 或 B 开始，在两条平行的七天线路之间切换；角色状态、时间、居民关系、认可、剧情事件、地点路线、章节过场和存档均可通过数据持续扩展。Solmere 塔罗海龟汤已作为可完整游玩的独立牌桌场景接入。

## 已完成

- 正式进入页面：继续游戏、开始新游戏、设置、制作人员和退出，并通过弹窗选择 A / B 双视角开局。
- A 的连续时间和 B 的碎片时间限制。
- 十一个主地图地点和五个街区地点、四种交通方式、时间与金钱消耗。
- 100 位稳定 ID 居民的七日日程和“此刻在场”查询：32 位显式居民加 68 位模板化灰盒居民；草稿居民可通过多次真实相处形成待定、拒绝、修复与认可结果。
- 十二名核心居民已具备独立身份、公开面貌、私人压力、认可/拒绝依据、说话方式、A/B 观察差异与环境闲聊台词；计划本会随关系展开显示人物化记录。
- 图书馆、咖啡馆、夜市和居民对话线索。
- 找到夏透明、对话并获得第 4 份居民确认的闭环目标。
- A 的随身记忆 / B 的计划本。
- 三个独立本地存档位、读取和继续游戏；旧存档自动沿用存档 1。
- Solmere 塔罗海龟汤：四步 Reading 引导、首轮教学牌、洗牌与依次翻牌动效、每轮三选一、22 张暖纸符号牌面、点读意象、本地语义自由提问、YES / NO / 无关、关键牌留阵、防重复线索、一次性交叉解读与 The World 结算。
- 统一的温暖手绘小镇界面：奶油纸纹、陶土屋顶、灰蓝与鼠尾草绿点缀，以及柔和的午后光。
- 自动截图入口和核心系统烟雾测试。
- A/B 两套相互隔离的七天状态与章节推进。
- 按故事大纲拆分的 A/B 人物资料：职业、背景、野心、矛盾、行为习惯、美术方向和私人记忆意象均可独立替换。
- 数据驱动剧情事件、居民关系记忆和认可状态。
- 可配置的逐日时间块、地点路线图、日记、作品，以及待赴约、可赴约、完成和错过四态预约。
- 计划本会列出满足前置条件的“今日可追踪机会”，包括地点、时间窗和是否已经错过。
- 关键剧情选择按 A/B 分别保存，可在计划本和结局回声中读取。
- 数据驱动的 A/B 章节轻交互：每天会根据故事进度切换照片、计划页、地图、波形、棋局等平行记录，并保留照片对齐操作。
- A/B 合计十四段每日开场卡，保存角色当日重点、内在线索与已读状态。
- 按故事大纲录入的 A/B 七天关键灰盒事件。
- 第一天已形成完整新手叙事链：A 从打印店偶遇进入咖啡邀约、剧场预约与晚霞摄影；B 从食堂观察进入日程、边界、图书馆等待与私人异常记录。主界面会按进度给出下一步引导。
- 烹饪选材、代写拼句、误解补全、声音排序、棋局观察、发呆取景、摄影构图和空间记录选择工作台。
- 第二天饭店段落已加入逐拍进店、协作式选材反馈和收台后的认可场景；店主签字来自共同完成劳动，而不是单次菜单选择。
- 第三天声音采样已加入来源与授权选择、可交付素材硬约束、雨天唱片店场景，以及无来源门轴声的保留/删除分支。
- 第五天代写已加入真实选句回响：工作台排列的三句话会进入后续对白，玩家最终决定保留委托人的停顿，或保留准确却不像本人的成稿。
- 第七天结局已接入动态经历回响：实际选过的菜材、声音排序、代写句序、错过的日程和关系修复会从 A/B 各自存档重新出现，不改变审核通过与否的判定。
- 有日程的居民均支持一次带时间成本的短交流，关系会记住具体地点与当时活动，但不会自动给出认可。
- 主要剧情支持逐拍推进的舞台式场景：环境动作、说话人和对白分开呈现，最后才显示角色化选择；未迁移事件继续兼容原有事件卡。
- 第四天旧车站叙事切片：A与B在不同时间看见时钟退回十一分钟，分别面对认可撤回与约定对象缺席；含可替换场景背景和三段角色化选择。
- 完整计划本/相册界面，以及双通过、仅A通过、仅B通过、均未通过四种第七天审核结局。
- 可持久保存的全屏、主音量和减少转场位移设置。
- 内容引用校验和 A/B 七天达到 12 份认可的可完成性模拟。
- 统一空间系统：街道正面进入九个室内，再以横版舞台选择物件近景；室内支持在场居民对话、时间成本、关系记忆和计划本回写。
- 扩展玩法宿主：听懂你、拼贴书信、老棋友和夜海观景台已经接入同一进入/退出/完成协议，完成后回到原室内并写回主存档。
- 烹饪、声音授权、摄影、空间错觉与公共档案均已拥有专属操作：火候、授权时间线、取景曝光、视角投影和来源交叉索引，同时继续使用同一剧情结算接口。

## 运行与测试

```bash
godot --path /Users/imokokok/Documents/100game
godot --headless --path /Users/imokokok/Documents/100game res://scenes/system_smoke_test.tscn
godot --headless --path /Users/imokokok/Documents/100game res://scenes/content_validation_test.tscn
godot --headless --path /Users/imokokok/Documents/100game res://scenes/seven_day_simulation_test.tscn
godot --headless --path /Users/imokokok/Documents/100game res://scenes/tarot_mechanic_test.tscn
godot --headless --path /Users/imokokok/Documents/100game --script res://tests/integration/test_interactive_spaces.gd
godot --headless --path /Users/imokokok/Documents/100game --script res://tests/integration/test_native_modules.gd
```

在进入页面选择“开始新游戏”，再选择 A 或 B。目标是在两条平行的七天路线中安排时间、赴约、认识居民，并让每个人分别取得 12 份有效确认。

## 主要内容入口

- 主菜单：`scenes/main_menu.tscn`
- 小镇日程：`scenes/town_day.tscn`
- Solmere 塔罗牌桌：`scenes/tarot_table.tscn`
- 玩家状态：`scripts/core/game_state.gd`
- NPC 日程：`data/npcs/demo_npcs.json`
- 十二名核心居民资料：`data/npcs/core_residents.json`
- 地点：`data/world/locations.json`
- 街道—室内—物件配置：`data/world/interactive_spaces.json`
- 塔罗牌库：`data/tarot/major_arcana.json`
- 牌桌案件：`data/tarot/cases.json`
- 后续玩法模块登记：`data/gameplay/modules.json`
- 七天时间配置：`data/story/calendar.json`
- A/B 人物资料：`data/story/characters.json`
- 剧情事件：`data/story/events.json`
- 章节切换文本与临时画面：`data/story/transitions.json`
- 结局分支文本：`data/story/endings.json`
- 地点路线：`data/world/travel_routes.json`
- 玩法叙事与结算数据：`data/gameplay/module_prototypes.json`
- 画风参考：`art/reference/`
- 美术替换约定：`docs/ART_REPLACEMENT_GUIDE.md`
- 第一天与核心居民开发说明：`docs/FOURTH_STAGE_FIRST_DAY.md`
- 第二天饭店切片说明：`docs/FIFTH_STAGE_RESTAURANT.md`
- 第三天声音采样说明：`docs/SIXTH_STAGE_SOUND_SAMPLING.md`
- 第五天代写委托说明：`docs/SEVENTH_STAGE_GHOSTWRITING.md`
- 第七天动态结局说明：`docs/EIGHTH_STAGE_ENDING_ECHOES.md`
- 进入页面背景：`art/ui/title-screen-background.png`

正式文本和美术进入项目后，应保持数据 ID 稳定，逐步替换展示文字、人物模型、场景模型、材质、动画和声音。章节切换卡片可在 `transitions.json` 的 A/B 记录里添加 `image_path`，逐张换图而不改交互与章节推进。

## 当前边界

这是已经能够从第1天推进到第7天，并把九个室内、五个原生生活玩法、四个独立扩展、塔罗和完整声音唱片链连回主存档的可运行整合版。100 位居民拥有稳定 ID；其中十二位已有专属人物层，其余居民仍使用可替换的通用日程与情境交流。真正的跨玩家公共唱片库需要单独部署后端和内容治理，因此当前明确保持 Local Mode，不会伪上传或阻塞单机流程。工程结构说明见 `docs/SECOND_STAGE_SKELETON.md`，新空间与扩展协议见 `docs/INTERIOR_AND_EXTENSION_SYSTEM.md`。

## 独立观景台原型

[夜海观景台源码与运行说明](prototypes/observatory/README.md)：包含照片轮播、星图观察和收藏；可运行版本已由河岸公园的夜海观景台接入，收藏至少一个星座后写回主游戏。

## 独立原型：听懂你

[听懂你源码与运行说明](prototypes/hear-you/README.md)：菜市场场景中的双人图形记忆对话；可运行版本已由潮汐饭店室内接入，完成三段对话和六次交换后写回关系日记。

## 独立原型：老棋友

[老棋友源码与运行说明](prototypes/elder-board-game/README.md)：围棋（9/13/19 路）、五子棋与国际象棋的本地 AI 对弈，棋后分支对话，以及文字/涂鸦教学、A/B 共享本地棋谱和已学规则对弈。可运行版本已由河岸棋社接入；完成一局后生成共享棋局作品。实时读图对话仍需配置模型服务。
