# 第三方资源与代码融合 V1：接入前核对

核对日期：2026-09-24。代码基线：`372e7b521214fdb8f935df46b7ac524266abc50f`。

输入：用户提供的《SOLMERE_第三方资源与代码融合方案_V1.docx》。本次读取文档正文和资源链接，并核对官方页面、上游 LICENSE、项目配置与现有代码。文档中的接入建议不等于这些资源已经安装，也不代表其中新增玩法已经交付。

本次交付是资源、兼容性和来源记录；**新增第三方资源文件 0 个，复制上游代码 0 行，运行时改动 0 项**。没有下载付费包、导入 Unity 工程、修改存档或恢复已取消的玩法。

## 1. 当前工程约束

- `project.godot`：Godot 4.7 功能版本，GDScript，Compatibility 渲染器，1600×900 视口；沿用当前 Godot 4.7.2 运行环境。
- 原生 Theme 为 `art/ui/solmere_ui.tres`，现有 `PaperLanguage`、纸页组件和已确认的 `art/ui/pocket_doodles/` 图集继续作为 UI 基线。
- 继续使用现有 `SaveManager`、`GameState`、`EconomySystem`、`ScheduleSystem` 等服务。外部 demo 的项目配置、autoload、输入表、存档和桌面 UI 不进入正式工程。
- 五日制、已有美术与可用小游戏仍为基线。文档的 NPC 四片认知/签名描述列为尚未实现的扩展，不能自动变成新的通关门槛。
- 用户明确排除之前“功能打磨完整包”中的参考图。它们未参与本次参考、提取或生成。厨房方向继续参考 Venba；保留现有切菜等交互。

## 2. 官方来源与处置

下表是页面核对，不是下载包内所有文件的许可审计。未取得的包内 LICENSE、具体文件清单、版本和哈希不填成“已验证”。

| 候选 | 本次查到的内容 | 接入结论 |
| --- | --- | --- |
| [Little Chef / hello erika](https://hello-erika.itch.io/cute-cozy-cooking-game-assest) | 作者开放游戏精灵用于个人及商业项目；署名非强制；禁止素材转售/再分发。不是 CC0。 | 仅保留为个别食材/工具候选。现有厨房图集先保留。公开源码中提交可提取的原素材不能从“可商用”直接推定获准；明确对应分发权利后再选用。 |
| [Paper Texture Backgrounds / Odds & Ents](https://oddsandents.itch.io/paper-texture-pack) | 13 张 JPG；允许商业项目及编辑，禁止作为原样图库素材转售。页面有免费领取入口。 | 暂未导入。只在现有纸页确有缺口时选少量纹理，保持浅底、清晰字和克制的纹理。素材开放仓库再分发须核对完整条件。 |
| [Cila Paper UI](https://nacila.itch.io/paper-stylized-ui-ready-for-development) | 美术配 Unity package、prefab 和动画；允许商用及修改；要求署名，禁止素材转售/再分发。页面区分免费包与付费包。 | 不是可直接装入 Godot 的 UI 插件。仅可评估缺失的基础美术控件；保留现有布局和图标。未购买、未导入；不能把 Unity 动画标为已兼容。 |
| [Godot UI Animation Library](https://godotengine.org/asset-library/asset/4033) / [上游](https://github.com/rockgem/godot-ui-animation-library) | 资产库标注 1.2、Godot 4.0、MIT；上游提供 Control 的弹出、缩放、滑入及按钮动画。[LICENSE](https://github.com/rockgem/godot-ui-animation-library/blob/main/LICENSE) 为 Rock Gementiza。 | 可作为独立动效候选。尚未运行兼容测试或抽取源码。若采用，固定提交、保留许可，先验证中断/关闭/重开及容器布局；不引入测试场景或第二套 UI。 |
| [Free Cute UI Sound Pack / R4orce](https://r4orce.itch.io/cute-ui-sound-pack) | 页面允许个人及商用，禁止原始文件再分发/转售；完整条款在包内 LICENSE.txt。40 个单声道 WAV，48 kHz / 24 bit。 | 尚未取得包内 LICENSE。软点击/翻页可作为试听候选；不把奖励类音效整包接入，也不将“免版税”写成“公共领域”。 |
| [Cozy SFX Vol. 1 / HuntSounds](https://huntsounds.itch.io/cosy-sfx-volume-1) | 页面提供环境、自然、脚步、UI 与音乐循环；48 kHz WAV，可用于个人及商业项目，无强制署名。 | 尚未下载/试听。页面的项目使用说明不足以自动确认公开原始素材包分发权限；实际选用前记录所选文件及完整条款。 |
| [Godot 官方录音教程](https://docs.godotengine.org/en/4.7/tutorials/audio/recording_with_microphone.html) / [官方 demos](https://github.com/godotengine/godot-demo-projects) | 录音教程要求启用输入，展示录音、回放与 WAV 保存；4.7 页面自身注明内容尚未更新。demo 根 [LICENSE](https://github.com/godotengine/godot-demo-projects/blob/master/LICENSE.md) 为 MIT。 | 用于 API 和行为核对。当前项目已经启用输入并使用 AudioEffectCapture；不替换为 demo UI。复制示例时仍需保留对应版权/许可，并核对单独资源条款。 |
| 官方 GD Paint / GUI Drag and Drop | 文档给出的部分地址是宽泛的资产库筛选页，不能据此确定下载版本和文件。尝试打开具体 GitHub 目录未成功；只确认了官方 demo 仓库级 MIT。 | 仅列候选，未声称已审计具体模块源码。现有拼贴工具继续保留；后续补齐准确目录、固定提交与文件级许可后再决定是否提取。 |
| [andrew-wilkes/godot-chess](https://github.com/andrew-wilkes/godot-chess) | 当前 main README 要求 Godot 4 和 Go，架构包括 GUI、UDP 服务、外部 UCI 棋引擎；另有 Godot 3 分支。自身 [LICENSE](https://github.com/andrew-wilkes/godot-chess/blob/main/LICENSE) 为 MIT。 | 不整合整套工程。项目现有纯 GDScript 规则已覆盖当前对局。外部棋引擎的条款不能从此仓库 MIT 推定；不引入 Go 服务或引擎二进制。 |

## 3. 对应现有实现与未完成边界

| 领域 | 已有挂载点与实际代码 | 本次结论 / 后续真实验收 |
| --- | --- | --- |
| 录音 | `scripts/town_sound/audio/AudioRecorder.gd` 从游戏总线或隔离的麦克风采集 PCM；`RecorderScreen.gd` 负责录制流程；`scripts/ui/components/live_sound_window.gd` 为实时窗口。 | 保留。实时声波/游戏画面不能称作“声音语义识别并生成 MV”。新文档的六种自动化参数也不能凭存在录音器就判完成。应逐项验证实际音频变化、导出和重载。 |
| 音频总线 | `scripts/town_sound/audio/WorldSound.gd` 已有 TownWorld、TownWorldMusic、TownWorldSoundEffects，UI 使用 SoundEffects，麦克风独立静音总线。 | 新方案建议的 UI/Foley/Ambience/Music 是职责目标，不能直接重命名现有总线。尤其不能让按钮音、试听或麦克风回授进入游戏采样。 |
| 拼贴与写信 | `extensions/collage_letter/workshop/workshop.gd`、`paper_object.gd` 及现有纸张/工具代码。 | 已有流程继续使用。新增工具行为须从入口完成操作，并在保存/重开后复原几何、层级和物品状态；“有一个绘图 demo”不是剪刀、折纸、封蜡完整实现。 |
| 棋类 | `extensions/elder_board/scripts/chess_rules.gd`、`grid_rules.gd`、`match.gd`，已有 Solmere 棋桌及棋子图集。 | 保留现有规则与画面；未完棋局的保存/恢复仍按独立缺口处理，不能通过换 UI 或引入 UCI 工程宣称解决。 |
| 厨房 | 现有原生厨房/经济/菜谱逻辑和 `art/ui/pocket_doodles/kitchen_objects.png`、`edible_food.png`。 | 文档要求的订单、自由配比、顾客反馈和库存应沿当前状态链逐项补齐；不能由 Little Chef 精灵包替代。 |
| NPC 认知与签名 | `scripts/core/relationship_system.gd` 已有见面事件、确认与身份记忆；`data/npcs/resident_staging.json` 规定场景内站位。 | 不等于每人 4 片认知和现场签名已完成。需作者内容、真实 trigger_id、A/B 来源、存档迁移与第五日去重；此轮未增加虚构片段或进度。 |

## 4. 后续单项接入的交付要求

1. 明确实际缺口和正式入口；以现有可用功能为对照。
2. 记录所选文件、上游地址、版本/提交、原文件与改后文件哈希、包内许可和改动内容。限制原文件分发的包不直接公开提交；不能靠改名/重绘抹去来源。
3. 只接入必要模块。沿用项目 Theme、输入、音频路由及存档；记录实际挂载文件。
4. 通过玩家入口验证操作、反馈、关闭/重开、失败恢复和持久化。音频须检查真实输出；视觉须检查实际窗口。每项结果单独记录，未完成明确写未完成。
5. `THIRD_PARTY_LICENSES.md` 记录实际包含的依赖；`REFERENCE_LOG.md` 记录仅评估/参考的内容。两者不互相冒充。

## 5. 本次验证范围

已核对官方资源页面、MIT 原文、现有项目配置及上述实现文件；补充文档并检查本地链接和 Git 差异。本次没有改变游戏代码，因此没有重跑游戏回归，也没有新的美术、动效、音效或新增玩法验收声明。此前 NPC/开局验证见 [独立记录](qa/resident_spaces_20260924.md)，其结果不作为本方案全部完成的证据。
