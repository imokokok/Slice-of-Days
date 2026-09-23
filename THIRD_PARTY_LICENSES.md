# 实际包含资源的许可索引

更新：2026-09-24。这里索引已在仓库发现的来源与许可记录，不为整个项目追加一个统一开源许可，也不是所有历史素材都已完成授权审查的声明。

本轮第三方融合方案候选**均未导入**，见 [接入核对](docs/third_party_integration_20260924.md)。未使用的候选不列为已包含依赖。

| 已包含内容 / 路径 | 作者、来源与许可记录 | 修改和范围 |
| --- | --- | --- |
| Godot 运行依赖 | Godot Engine contributors；[官方 MIT 许可](https://github.com/godotengine/godot/blob/master/LICENSE.txt) | 工程依赖，不表示本项目美术/剧本也获得 MIT 许可。引擎及导出模板的随附声明继续保留。 |
| `extensions/myriorama_tarot/assets/audio/` 中的 Kenney 纸牌采样及派生 WAV | Kenney Vleugels；[Casino Audio](https://kenney.nl/assets/casino-audio)；仓库原文 [Kenney-License.txt](extensions/myriorama_tarot/assets/audio/Kenney-License.txt)：CC0 | 包含纸牌动作采样及裁短 WAV；实际来源说明见 [ASSET_NOTES.md](extensions/myriorama_tarot/ASSET_NOTES.md)。不把此目录中的许可推广到纸牌图像。 |
| `extensions/observatory/assets/nebulae/` 的天文照片、结构数据及派生场景 | NASA、ESA/Hubble、Chandra 等；按文件见 [SOURCES.md](extensions/observatory/assets/nebulae/SOURCES.md) 及 `casa_import_manifest.json` | 原记录含照片署名、CC BY 4.0 与 NASA/Chandra 来源政策、变换及校验值。保持逐文件区分；派生文件继续沿用来源条件，不宣称全部原创。本轮只索引旧记录，未重新审定整个目录。 |

## 项目美术和来源待明确的内容

- 已确认的 UI 生成记录保存在 [UI 美术记录](docs/art/ui_coast_20260923.md)、[UI 修订记录](docs/art/ui_review_20260923.md)、[棋桌记录](docs/art/chess_table_20260924.md)。它们不应误标成 Little Chef、Cila 或 Venba 提供的素材。
- 用户提供的场景、剧本、图像仍按各自来源处理。特别是 Myriorama 原记录已指出牌背/桌布参考图未建立第三方商用再分发许可；保留该事实，见上方 `ASSET_NOTES.md`。
- 旧 `prototypes/` 的许可继续在各自目录保留。本索引不改变其适用范围。

## 后续实际采用时补齐

每个条目记录上游版本/提交、逐文件来源与哈希、原始 LICENSE 路径、作者、修改说明、实际使用位置和发布方式。MIT 代码提取需要随附对应版权和许可原文；要求署名的素材还需进入玩家可见 Credits。只有阅读或设计参考的条目放入 [REFERENCE_LOG.md](REFERENCE_LOG.md)。
