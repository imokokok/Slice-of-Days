# 美术与录音来源

逐文件来源、许可和 SHA-256 存于 `sources.json`。来源数量与游戏中的排版条目数量分别统计。

- 100 个 Nieobie CC0 图案；13 张 Leschge CC0 扫描纸纹，另有 CC0 旧纸扫描。纸张不是只有变色，也采用不同大小、边缘、纹理及印刷形式。
- 6 幅 Met 公共领域画作。6 张小镇照片卡使用用户项目既有场景美术，不宣称为 CC0；其原文件保留，显示时按内容取景。
- 52 个字母来自用户提供的两张 JPEG。按原始 8 像素轮廓拆分、移除外侧白底；保留字母内部白色与不透明像素的原 RGB，未重新生成字形。这些用户美术不宣称为 CC0。
- 17 乐谱剪片来自 Wikimedia 上现有的 Scott Joplin《Original Rags》完整排印 PDF。原作品与所用排印文件在来源页声明为公有领域；这是现有真实乐谱的剪片，不是程序随机画音符，也不冒充古纸实物扫描。
- [Papers / Pavel Kutejnikov](https://opengameart.org/content/papers)：CC0 手绘图集，使用其中空白信封区域，翻盖与蜡印仍独立互动。原图集及许可原样保留。
- [Light wood / qubodup](https://opengameart.org/content/light-wood-1024x1024)：CC0 木纹，运行时用低对比色洗与原有 CC0 笔触木纹共同形成桌面。无 3D 模型、法线或 PBR 材质。
- Caveat、Libre Baskerville 为 OFL；Special Elite 为 Apache-2.0。许可在 `assets/fonts/`。中文根据系统可用字体选择楷体、仿宋、宋体及黑体，不再把所有材料印成一种字体。
- 14 个 CC0 音频文件，包括纸张、刀剪、铅笔、胶带、火柴、印章与点击。铅笔采用 OpenGameArt 的 Pencil Sounds；胶带采用 Freesound crookedletter 的 packing tape 录音。部分其他动作复用录音，不宣称每一个动作都有专门录音。

本项目创作广告、促销、票据文案及版式；小镇店铺为虚构内容。CC0 无需玩家署名；其他代码与字体许可随源码保留。完整工具功能和互动层次不依赖贴图本身。

## 新增纸张来源

- `paper/fibre-kraft.png`：plaggy 的 Paper02 颜色纹理，CC0；来源 https://opengameart.org/content/cc0-pbr-paper-02-texture-paper02albedopng 。
- `paper/watercolor_*_0.jpg`：PuzzleAndy 的 12 张数字水彩，CC0；来源 https://opengameart.org/content/cc0-watercolor-textures 。用于流纹、水墨、海雾、盐花等不同纸面，也作为水粉笔沉积颗粒采样。
- 24 款底纸使用这些原图及既有扫描纸纹；描图纸通过透明度表现，叶纹压痕、咖啡渍线、帘纹和航空边是游戏叠绘。它们不是 24 种真实工艺纸的实物扫描，不将数字水彩称为手工原作。

截至本次版本，清单共 212 个文件，逐项核验 SHA-256。用户字母和既有场景资产不被重新标注为 CC0。
