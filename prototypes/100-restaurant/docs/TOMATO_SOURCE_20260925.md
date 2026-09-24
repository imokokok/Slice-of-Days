# 追加番茄原画（2026-09-25）

用户追加 `df995921916e28abe9a9c7634fd6bc34.jpg`，按普通食材 `tomato` 的原画替换素材接收。它实际为 1079 × 1527 的 RGB JPEG，白底不透明。

原件字节一致地保存为 `supplied_assets/20260925-tomato/tomato-original.jpg`，来源、尺寸与 SHA-256 见同目录 `manifest.json`。版权仍归提供原画的团队。

**尚未完成游戏内替换**：本次使用内置 imagegen 尝试只去白底，但输出重新描绘了局部笔触，因此未采用，没有放进运行时清单，也没有替换现有番茄。不把近似生成图称为用户原图。已提出透明原图或确定性程序去底两种途径，等待用户回复；前一批的 13 张黑底 JPEG 也仍待处理。

尝试的提示词：`Use case: background-extraction. Edit target: the supplied team-drawn tomato JPEG. Remove ONLY the flat white background, output a genuine transparent-alpha PNG, not a checkerboard baked into RGB. Preserve the exact original tomato artwork: irregular faceted silhouette, orange-red painted upper plane, dark rusty red lower shading, dark green asymmetric stalk, pale yellow highlight on the right, every brush mark. Do NOT redraw, restyle, smooth, relight, rotate, add detail, add shadows, or change colors. Preserve original object proportions and small asymmetries. Crop away excess empty canvas while keeping a modest transparent margin. This is preservation/extraction of an existing copyrighted-by-user game sprite, not generation of a new tomato. Only background removal.`

验证范围：原件 SHA-256 与提供文件一致，格式/模式/尺寸已核对。本次只归档素材与说明，未修改游戏代码或构建，未重复计入此前游戏回归结果。
