# Solmere 随身物 UI

2026-09-20。视觉按用户的蓝／暖白／柠檬黄文件夹与申请要求页参考：蓝色装订边、伸出的实体双语标签、轻纸纹；申请要求上方为介绍与海边贴纸照片，下方为五栏。文字、导航和编辑控件均为原生 Godot 元素，图片不包含文字或点击区域。

- H / J：私人随身本。F：申请档案。G：相册。C / R：拿起相机／录音机。
- 所有一级物件共用居中、自适应缩放的文件夹。只有作品集有七日分页。
- 白纸保存素材位置、旋转、缩放、层级、文字与画笔笔画。素材可点击或拖入，选中时出现变换工具。
- 私人随身本不进入申请快照；申请提交后档案封存，私人记录仍可写。
- 探索隐藏常驻信息，时段变化短暂淡入。心理文字逐字沿轻微曲线流动，并尊重减弱动效设置。

## 生成素材

使用内置 image_gen（不是 CLI），根据用户提供的参考生成；保留原始 alpha 并复制进入仓库。运行时用 AtlasTexture 去掉文件夹的透明外边距，没有把 UI 渲染成图片。

- `art/ui/living-folder.png`：参考 `e2dd2846da98549af7e1ef008e3ee237.jpg`。提示词：制作一张透明底、正面横向空白文件夹纸页，严格保留参考的暖白纸纹、细海蓝装订边、窄白接缝、轻微不规则描边与圆角。去除所有标签、文字、logo、照片、印章和装饰。16:9，一张空白纸，细微近白纸纹；不用真实皮革、商业面板、重阴影。
- `art/ui/living-postcard.png`：参考 `d9e8a3626c26b76b318f2f836c490298.jpg`。提示词：单独提取并重绘参考中的海边贴纸照片，透明底、微逆时针旋转的暖白照片边框；2D 水粉蓝色海湾、奶油色小镇、赭色屋顶、柏树、远山、一只白帆船，右上角一小条柠檬黄和纸胶带。严格保持参考配色与画风；无文字、logo、额外 UI、写实感或重阴影。

标签、线稿图标和控件均为项目内代码绘制，便于独立响应、缩放及键盘焦点。共享主题为 `art/ui/solmere_ui.tres`。

## 验证

`tests/integration/test_living_ui.gd -- --isolated-save` 验证分页约束、拖拽、绘画、旋转缩放层级移除、存档往返、提交封存和隐私隔离、实际场景的低 HUD 与关闭后释放操作。加 `--screenshots` 可在非 headless 模式输出实机截图到 user 目录。`test_walking_journey.gd` 验证行走与章节流程。


## Shared street and shop interface

`PaperLanguage` applies the blue ink, warm paper, lemon hover/focus, handwritten type and fine paper fibres to controls created by shops, minigames, film/audio tools and secondary sheets. Floating thoughts keep their own animated renderer. Scene speech uses transparent surfaces and outlined text; a `scene_speech` group marks event and room dialogue. Native ingredient selections use the same yellow selected state after updates.

The shop is a shelf with original line sketches and a receipt at the right. Purchasing still goes through EconomySystem's transaction/save handling and double-click guard. The bag is an object page inside Notebook, opened with B or I; items and quantities come from the real inventory. J and legacy journal routes now open the same Notebook instead of the old dashboard. Map and minigame headers no longer repeat money/time totals. Observatory return controls are frameless and use memory-oriented wording.

Validation: `tests/integration/test_world_ui.gd -- --isolated-save` checks purchase amount, inventory, serialization, double-click guard, receipt, backpack route, scene/event speech and selected-state styling. Add `--screenshots` with the compatibility renderer for shop, bag, scene speech, event and cooking captures.
