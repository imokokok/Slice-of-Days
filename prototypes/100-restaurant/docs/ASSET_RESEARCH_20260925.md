# 厨房美术与开源代码筛选

检索日期：2026-09-25。以下是作者发布页与仓库许可的核对结果，不把“免费下载”等同于“允许公开再分发源文件”。本轮实际新增的是经用户授权、以团队原画为参考生成的切面，以及局部台面补片；没有把候选第三方整包混入工程。

| 候选 / 原始发布页 | 已核实许可与内容 | 本项目处理 |
| --- | --- | --- |
| [Little Chef 作者素材包](https://hello-erika.itch.io/cute-cozy-cooking-game-assest) | 作者明确说是自己为 Little Chef 绘制的全部 sprites；允许个人/商用，不强制署名，同时明确禁止转售/再分发素材 | 风格相关，但原始包不能直接上传公开源码仓库。没有下载或提交；要公开原始素材，需要解决该条款与游戏页 CC0 描述的冲突 |
| [Little Chef 游戏页](https://truebiger.itch.io/little-chef) | 游戏页曾把 sprites 描述为 CC0；其旧素材链接失效，实际作者页见上行 | 不单凭游戏页标签覆盖作者更具体的许可说明 |
| [Haiyoooo Cosy Kitchen Pack](https://haiyoooo.itch.io/cosy-kitchen-pack) | 150+ 手绘透明 PNG，厨房、食物、餐具；允许商用，须署名 Haiyoooo | 是较贴近当前二维手绘风格的补充候选。页面未明确原始包公开再分发许可，尚未纳入源码 |
| [KayKit Restaurant Bits](https://kaylousberg.itch.io/restaurant-bits) | 免费部分 140+ 低多边形 3D 模型，有生/熟/切开状态；CC0、可商用、无需署名。额外 75+ 内容与 blend 源文件属于付费版本 | 许可适合，形态为 3D；当前不为凑数量引入异质画风。没有购买或下载付费包 |
| [Kenney Food Kit](https://kenney.nl/assets/food-kit) / [作者 itch 页](https://kenney-assets.itch.io/food-kit) | 200 件 3D 食物；CC0，可商用、无需署名 | 可作为未来三维版本资源，当前不导入 |
| [OpenGameArt CC0 Food Icons](https://opengameart.org/content/cc0-food-icons) | CC0 食物图标汇编，含原始来源列表；16/24/32 像素风 | 许可合适，像素画风不匹配当前厨房；不导入 |
| [AliceProject Food Assets](https://aliceproject.itch.io/food-assets-1-5) | 页面有 CC0 标记，也附有禁止 NFT / AI 训练的额外说明 | 条款不能概括为无限制 CC0；不导入，也未作生图参考 |
| [SoloByte godot-polygon2d-fracture](https://github.com/SoloByte/godot-polygon2d-fracture) / [LICENSE](https://raw.githubusercontent.com/SoloByte/godot-polygon2d-fracture/main/LICENSE) | Godot 4 多边形切割/碎裂；MIT，Copyright 2021 David Grueneis，使用代码须随附版权及许可文本 | 现有刀线切割已能保留质量、原画和谱系；没有为替换已工作的核心引入依赖。本轮没有复制其代码 |
| [godot-antialiased-line2d](https://github.com/godot-extended-libraries/godot-antialiased-line2d) | MIT，抗锯齿线条插件 | 现有画笔使用引擎绘制，可作将来笔迹质量优化候选；未导入 |
| [godot-sprite-slicing](https://github.com/lupoDharkael/godot-sprite-slicing) | 较旧的 Godot 3 切割示例 | 与当前 Godot 4.7.2 集成成本不相称；未导入，也未对其许可作采用承诺 |

当前音效仍使用已核验的 CC0 实录库，见 [AUDIO.md](AUDIO.md)。本轮抹布复用其中的擦拭录音，没有新增程序合成拟音。

素材适配顺序：团队手绘原作 → 授权生成的派生切面 → 画风匹配且许可覆盖目标发布方式的第三方补充。切面来源、完整提示词与哈希见 [CUT_ART_GENERATION_20260925.md](CUT_ART_GENERATION_20260925.md)。
