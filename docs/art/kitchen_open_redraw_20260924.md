# 厨房缺图重绘与玩法接入记录

日期：2026-09-24

## 边界与来源

- 主风格来源：用户提供并已接入 `art/ui/kitchen_supplied/` 的食材、调味料和怪食材。它们继续是厨房的主资产，没有被开源包替换。
- 结构参考：[ScratchIO 2D Vegetables](https://opengameart.org/content/2d-vegetables)（CC0）的整菜/切片对照；[KayKit Restaurant Bits](https://github.com/KayKit-Game-Assets/KayKit-Restaurant-Bits-1.0)（CC0）的 raw/chopped/cooked 状态划分。
- 交互参考：[Venba 官方 presskit](https://venbagame.com/press/)所呈现的温暖厨房和料理主题。只学习步骤聚焦、食物状态清楚、动作即时回应、摆盘承担叙事结果；没有导入截图、角色、音乐、剧情、具体菜谱或 UI 构图。
- Little Chef 官方页允许项目使用、禁止把素材当素材包再分发。本轮新增锅具不依赖 Little Chef 本地安装；已有可选本地包的边界继续按 `THIRD_PARTY_LICENSES.md` 处理。

开源参考的原始 PNG、模型与贴图都没有进入仓库。仓库只保存按本作风格新生成并经透明通道复核的输出。

## 输出与映射

- `art/ui/kitchen_open_redraw/prepared_common_atlas.png`：1254×1254、真透明；4×3，依次为蘑菇、土豆、胡萝卜、甜菜根 / 茄子、西葫芦、柠檬、面包 / 奶酪、番茄、香草、鱼块。
- `art/ui/kitchen_open_redraw/prepared_peppers_atlas.png`：1774×887、真透明；4×2，依次为黄、紫、橙、深紫 / 铜、白、红、绿甜椒。
- `art/ui/kitchen_open_redraw/enamel_pan.png`：1254×1254、真透明；顶视角空锅，留出足够内圈供实时食材叠放。

两张图集由 `scripts/ui/components/cooking_ingredients.gd` 按格裁取；锅由 `scripts/ui/components/cooking_pot.gd` 使用。用户原图仍用于货架、选材和未处理状态，重绘图只在切配后、入锅和装盘阶段出现。

## 生成方式与提示记录

使用内置图像生成工具，以“编辑/参考图重绘”模式制作；每张输出都使用用户食材作为风格参考，并对伪棋盘背景继续执行背景移除，直到 PNG 报告真实 alpha。

- 通用切配图集：要求 4×3 独立格，按上述食材顺序，沿用用户素材的简化轮廓、克制高光与略不规则手绘边缘；用 CC0 切片图只帮助确定切法；无盘子、无文字、真透明背景。
- 甜椒切配图集：要求 4×2 独立格，保留八种甜椒的颜色差异，全部显示成可辨识的椒圈/椒条；无容器、无文字、真透明背景。
- 珐琅锅：要求顶视角、暖白内壁、深海蓝绿色锅沿、双耳、空锅、留出食材叠放区域；匹配用户食材的手绘剪纸感；无餐具、无食物、无文字、真透明背景。
- 背景移除：只保留主体像素，锅外与把手孔的 alpha 为 0，不重绘主体。

## 从 Venba 学习但保持本作自己的实现

1. 切配不是文字标记：常用蔬菜和甜椒有真实的切后轮廓，怪食材继续使用美术给出的专属处理态。
2. 下锅不是瞬间替换：最后加入的食材从上方落入，翻拌时围绕锅心运动。
3. 火候不是只看分数：刚好、可挽回、粗糙以及过热会改变食材的暖色/焦色表现，同时保留原有可恢复、无硬失败设计。
4. 摆盘不是一句结果：留白、丰盛、分食三种选择会即时重排玩家实际做的三样食材；悬停/键盘聚焦先预览，确认后保留成菜。
5. 焦点跟随步骤：备料看案板、烹饪看锅、装盘看成菜；原料顺序、处理方法、翻拌次数和摆盘仍写入同一份料理记录。
6. 同一素材贯穿过程：案板会完整显示专门绘制的切配图，不再二次裁碎；右侧实时菜谱用小图记录实际下锅顺序；尝味按钮使用美术提供的芥末与盐罐提示可用调味方向。

## 验证

- `godot --headless --path . --script res://tests/integration/test_kitchen_supplied_art.gd -- --isolated-save`：通过。
- `godot --headless --path . --script res://tests/integration/test_cooking_rhythm.gd -- --isolated-save`：通过（需允许 Godot 写隔离的 `user://` 临时存档）。
- 有渲染窗口的截图验收覆盖备料、切配完成、入锅、尝味和分食装盘；运行时截图在 `.runtime/kitchen-art-pages/`，该目录按项目约定不提交。
