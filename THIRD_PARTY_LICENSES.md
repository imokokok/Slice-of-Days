# 实际包含资源的许可索引

更新：2026-09-26。这里索引已在仓库发现的来源与许可记录，不为整个项目追加一个统一开源许可，也不是所有历史素材都已完成授权审查的声明。

后续逐文件引用/备用分类、UI 兼容修复和真实声音入口复核见 [运行审查](docs/third_party_runtime_audit_20260924.md)，不将安装数与功能完成数混同。

本轮已从四个官方免费包安装 84 个选用文件，并适配两处 MIT 代码。逐文件原路径、原始/安装后 SHA-256、音频转换与循环范围见 [资源清单](data/presentation/resource_manifest.json)，实际使用与分发方式见 [接入交付](docs/resource_integration_delivery_20260924.md)。

| 已包含内容 / 路径 | 作者、来源与许可记录 | 修改和范围 |
| --- | --- | --- |
| B 的随身本 / `art/ui/fonts/xiaolai/` | LXGW、Nozomi Seto；[Xiaolai v3.126](https://github.com/lxgw/kose-font/releases/tag/v3.126)；SIL OFL 1.1，[完整许可](art/ui/fonts/xiaolai/OFL.txt) | 原字体未经修改，随成品与许可分发，用于日程和手写待办；[来源与校验值](art/ui/fonts/xiaolai/SOURCE.md)。 |
| Godot 运行依赖 | Godot Engine contributors；[官方 MIT 许可](https://github.com/godotengine/godot/blob/master/LICENSE.txt) | 工程依赖，不表示本项目美术/剧本也获得 MIT 许可。引擎及导出模板的随附声明继续保留。 |
| Little Chef / `art/licensed/kitchen/`（本地安装） | hello erika；[官方素材页](https://hello-erika.itch.io/cute-cozy-cooking-game-assest)；[随包 ReadMe](third_party/licenses/little_chef/ReadMe.txt) | 10 张选择性厨房图层，原包完整留在本地缓存。官方页允许个人/商业项目、禁止素材转售/再分发；随包 ReadMe 自称 CC0 又附原样转售限制，两者均保留，不将其简化为无限制公共领域。 |
| `art/ui/third_party_adapted/solmere_pot_front.png` | 基于上述 hello erika 的锅前景，用图像编辑生成适配版 | 蓝色花朵锅改为更宽矮的海绿锅、陶土手柄与两条米白装饰带；见 [改造记录](docs/art/third_party_adaptations_20260924.md)。 |
| `art/ui/kitchen_open_redraw/*.png` | 本作新生成的透明 PNG；轮廓拆分参考 [ScratchIO 2D Vegetables](https://opengameart.org/content/2d-vegetables) 与 [KayKit Restaurant Bits](https://github.com/KayKit-Game-Assets/KayKit-Restaurant-Bits-1.0)（均为 CC0），风格参考用户已提供且已接入的厨房素材 | 2 张切配状态图集和 1 张珐琅锅；没有把开源原图或 Venba 素材直接打包。逐格映射、生成提示和透明通道验证见 [厨房补图记录](docs/art/kitchen_open_redraw_20260924.md)。 |
| Cila / `art/licensed/ui/`（本地安装） | Cila；[官方页](https://nacila.itch.io/paper-stylized-ui-ready-for-development) | 18 张基础纸页/符号；允许项目使用与修改，要求署名，禁止素材转售/再分发。选免费包 PNG，未导入 Unity 工程。署名保存在本索引和随成品分发的许可目录；游戏内致谢按用户要求留空。 |
| R4orce / `art/licensed/audio/ui_*.wav`（本地安装） | [官方页](https://r4orce.itch.io/cute-ui-sound-pack)；[随包完整许可](third_party/licenses/cute_ui/License.txt) | 14 个采样转为 16-bit PCM；保持采样率。许可允许商用作品/编辑，禁止公开原始文件下载、独立资源分享/转售。仅随游戏成品分发，公开代码使用官方安装器恢复。 |
| HuntSounds / `art/licensed/audio/` 中 ambience、step、foley、bird（本地安装） | [官方页](https://huntsounds.itch.io/cosy-sfx-volume-1)；[页面条款记录](third_party/licenses/official_page_terms.md) | 42 个环境/脚步/物件/鸟声采样；个人与商业项目免版税；无额外包内 LICENSE。原包不公开再上传，随成品保留作者和许可记录。 |
| `scripts/ui/solmere_motion.gd` | Rock Gementiza，Godot UI Animation Library，MIT；上游提交 `62230b14300c44a6a7decb8ad052b2b29b416a67`；[完整许可](third_party/licenses/godot_ui_animation/LICENSE) | 适配 Control 缩放调用，增加中断处理、恢复原缩放、减弱动效设置与现有按钮挂接。不安装第二套 EditorPlugin 或存档框架。 |
| `scripts/town_sound/audio/SignalSpectrum.gd` | Godot Engine contributors，官方 demos，MIT；上游提交 `a3b5c113112f77291d5f3d1360f33a882fdc52f7`；[完整许可](third_party/licenses/godot_demos/LICENSE.md) | 适配 `audio/spectrum/show_spectrum.gd` 的频段强度与 dB 归一化；另加本地 WAV 分析。没有复制示例音乐或示例 UI。 |
| `extensions/myriorama_tarot/assets/audio/` 中的 Kenney 纸牌采样及派生 WAV | Kenney Vleugels；[Casino Audio](https://kenney.nl/assets/casino-audio)；仓库原文 [Kenney-License.txt](extensions/myriorama_tarot/assets/audio/Kenney-License.txt)：CC0 | 包含纸牌动作采样及裁短 WAV；实际来源说明见 [ASSET_NOTES.md](extensions/myriorama_tarot/ASSET_NOTES.md)。不把此目录中的许可推广到纸牌图像。 |
| `extensions/observatory/assets/nebulae/` 的天文照片、结构数据及派生场景 | NASA、ESA/Hubble、Chandra 等；按文件见 [SOURCES.md](extensions/observatory/assets/nebulae/SOURCES.md) 及 `casa_import_manifest.json` | 原记录含照片署名、CC BY 4.0 与 NASA/Chandra 来源政策、变换及校验值。保持逐文件区分；派生文件继续沿用来源条件，不宣称全部原创。本轮只索引旧记录，未重新审定整个目录。 |

## 2026-09-26 新增且实际接入

| 内容 | 上游与许可 | 实际适配 |
| --- | --- | --- |
| `art/ui/open_sketch/`，38 张 PNG / 39 个语义映射 | Deface Games / Amanz，[Skymon 官方页](https://defacegames.com/product/skymon-icon-pack-free/)，[作者上传的 CC0 声明](https://opengameart.org/content/skymon-icon-pack-free)；v250329；[随包说明](third_party/licenses/skymon/readme.pdf) | 原 PNG 字节不变，在游戏中染为低饱和墨绿/棕色；设置、返回、保存、结账、通知与拼贴工具采用原有控件接口。其余映射是备用，不声称每张均同时显示。 |
| `audio/open_foley/interface/` 与 `rpg/`，25 个 OGG / 21 个提示映射 | Kenney / Kenney Vleugels，[Interface Sounds](https://kenney.nl/assets/interface-sounds)、[RPG Audio](https://kenney.nl/assets/rpg-audio)，CC0；[界面许可](third_party/licenses/kenney_interface/LICENSE.txt)、[RPG 许可](third_party/licenses/kenney_rpg/LICENSE.txt) | 原 OGG 字节不变；在已有总线上调整音量，补充按钮、纸页、滑杆、录音开停、收钱、切菜、锅具与门声。保留既有环境声。 |
| `scripts/town_sound/audio/cue_pool.gd` | Nathan Hoad，[Godot Sound Manager](https://github.com/nathanhoad/godot_sound_manager)，MIT，提交 `1c041582db806a0d0edad77111d1fb7a009346ef`；[完整许可](third_party/licenses/godot_sound_manager/LICENSE) | 适配 `abstract_audio_player_pool.gd` 的播放器准备、回收和 finished 连接；增加 8 声部上限、提示优先级、立即占用和总线清理。没有安装第二套全局声音系统。 |
| `scripts/ui/ui_sound_bindings.gd` | Maaack，[Godot UI Sound Controller](https://github.com/Maaack/Godot-UI-Sound-Controller)，MIT，提交 `4ae5fd97b363b8236abfe616179226aa03ded0cd`；[完整许可](third_party/licenses/maaack_ui_sound/LICENSE) | 适配原生控件信号注册；改用实例 ID 延迟连接，复用 WorldSound，忽略隐藏控件、程序刷新和重复连接。 |

每个新资源的归属、原包成员名、安装路径、SHA-256、下载地址和音量见 [open_ui_manifest.json](data/presentation/open_ui_manifest.json)。[安装脚本](tools/import_open_ui.py)按固定哈希校验下载；运行游戏完全使用本地资源，不需要联网。新包许可允许商用和修改，但不将这个判断扩大到所有历史图片。Skymon 是独立手绘图标包，没有证据证明它来自某个已发行游戏。

## 项目美术和来源待明确的内容

- 已确认的 UI 生成记录保存在 [UI 美术记录](docs/art/ui_coast_20260923.md)、[UI 修订记录](docs/art/ui_review_20260923.md)、[棋桌记录](docs/art/chess_table_20260924.md)。它们不应误标成 Little Chef、Cila 或 Venba 提供的素材。
- 用户提供的场景、剧本、图像仍按各自来源处理。特别是 Myriorama 原记录已指出牌背/桌布参考图未建立第三方商用再分发许可；保留该事实，见上方 `ASSET_NOTES.md`。
- 旧 `prototypes/` 的许可继续在各自目录保留。本索引不改变其适用范围。

## 后续实际采用时补齐

每个条目记录上游版本/提交、逐文件来源与哈希、原始 LICENSE 路径、作者、修改说明、实际使用位置和发布方式。MIT 代码提取需要随附对应版权和许可原文；要求署名的素材继续保留作者许可，并随游戏成品提供可见的第三方声明；不得因为游戏内致谢留空而删除许可。只有阅读或设计参考的条目放入 [REFERENCE_LOG.md](REFERENCE_LOG.md)。

## 2026-09-26 全局录音新增

- Lucide 六个线描图标：`art/recording_icons/`；ISC / Feather MIT，完整许可 `third_party/licenses/lucide/LICENSE`。
- Nathan Hoad Godot Sound Manager 音效池改编：`scripts/town_sound/audio/WorldAudioPool.gd`；MIT，完整许可 `third_party/licenses/godot_sound_manager/LICENSE`。
- 固定版本、采纳范围及未采用候选见 [全局录音接入记录](prototypes/town-sound/GLOBAL_RECORDING.md)。
