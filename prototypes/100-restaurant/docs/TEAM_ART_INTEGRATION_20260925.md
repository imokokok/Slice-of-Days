# 团队食材原画与补画接入 · 2026-09-25

## 本轮实际接入

- 压缩包 7 张奇物与单独提供的 12 张透明 PNG 已在此前接入；本轮重新核对压缩包 7 张与项目文件 SHA-256 完全相同，不重复导入，也不覆盖原件。
- 第二批 13 张黑底 JPEG 原画按原字节复制到 `modules/restaurant/assets/team_jpeg_originals/`；原先 `docs/supplied_assets/20260925-batch2/` 的存档不动，双份均可按 `team_jpeg_manifest.json` 的 SHA-256 核验。运行时按像素亮度生成透明边缘并裁掉大画布，不保存修改版作为原画。缩放、透明边缘和 JPG 黑边是二维显示近似；深色甜椒已在浅色背景对照检查。
- 土豆、胡萝卜、洋葱、茄子替换现有整件食材。西葫芦与 8 种颜色／形状的甜椒各作为可单独取用的食材加入冰箱、物性目录与菜谱库。由 97 个定义增至 106 个，禁用的鱼／三文鱼不变，可用 104 个。洋葱和西葫芦的身份、甜椒是否应合并为单品的外观版本，仍按此前暂定映射；已向用户询问，可按答复调整。
- 切配继续由实际刀线、真实质量和碰撞几何驱动。西葫芦沿用浅绿瓜切面，彩椒使用已生成的空心甜椒切面并按对应颜色适配。受热表面、手持、摆盘、照片、菜谱与柜格都从 `sprite_library.gd` 取图，不做另一张预制成品图。
- 缺画的鸡蛋、米饭、面条、面包补绘成 4 格独立透明贴图，放在 `modules/restaurant/assets/supplementary/staples.png`，与团队原件分目录、分 manifest。面条由整份图逐渐过渡到已有受热散开的线条绘制；鸡蛋破壳后仍进入原有蛋液状态。

## 补画来源

采用 image_gen 生成新的游戏补充素材，不把它们标为团队手绘原件。第一版偏写实，被否决且未接入。采用的第二版提示词：

> STRICT FLAT HAND-DRAWN GAME ART, NOT REALISTIC. Make a single PNG sprite sheet with TRUE TRANSPARENT ALPHA, exactly 2x2 equally sized cells, four separate isolated 2D food shapes: upper-left whole chicken egg, upper-right little pile of cooked white rice, lower-left loose nest of wheat noodles, lower-right small bread roll. An original indie cooking game's art direction: broad irregular opaque painted polygons and gouache cut-paper shapes; 3 to 5 flat tones per food; sparse short dry-brush marks; slightly crooked handmade edges; minimal detail; a few white hard-edged highlights; NO photographic texture, NO realistic grain shading, NO 3D, NO glossy lighting, NO smooth gradients, NO soft shadows, NO outlines around each object. Think simplified children's hand-painted sticker illustrations with flat imperfect shapes. Keep recognizable silhouettes and warm colors. Each item centered in one quadrant with lots of clear transparent space; no plate, props, text, labels, or background. Alpha outside objects must be zero.

`staples.png` SHA-256：`c96b4dbc479f6c604f804b9bc4d30f1516ec2b950c15ee0bcdfa7759ec30c3e0`。运行时按 `supplementary_manifest.json` 的四个边界取图；不修改生成原件。团队提供的 JPEG 仍归团队原作者，本补画属于本项目新增派生/补充视觉资产。

## 验证与边界

**已实现并验证**：13 张 JPG 与原件 SHA-256 一致；19 张既有透明 PNG 未改；13 件 JPEG 与 4 件补画均能从共同入口取得带透明边缘的图；9 个新食材从实际冰箱翻层取出、归还并保持身份；106 图素材审计 0 错误。`tests/test_team_food_art.gd` 121 项、原画 227 项、柜层 287 项、材质 360 项、切配/清锅/分享 140 项、空间 37 项、菜谱 DIY 81 项、集成 126 项通过。按 `tools/test.ps1` 的清单在 macOS 上运行 38 个 Godot 入口，全部通过；本机没有 PowerShell，不声称运行了脚本本身。

**导出验证**：Godot `--export-pack` 成功；从独立 `/private/tmp` 位置加载临时 PCK 并逐张读取 17 件新接入图，无缺图错误。Windows EXE 未生成：本机缺 Godot 4.7.2 Windows 导出模板。最新可用工程为源码，不能把旧 EXE 称作本轮更新版。

**近似实现**：JPEG 的黑底通过运行时亮度阈值和边缘渐隐处理，不保证达到原生透明 PNG 的逐像素边缘精度；彩椒切面为同画风生成图的颜色适配。其余尚未补画的普通食材继续使用旧图集，未声称 106 件全部换完。未逐项人工实测长时烹饪和全部食材在真实系统鼠标下的操作。

对照图：`docs/qa/20260925-team-food-gallery.png`（浅色背景下 13 张团队 JPEG 与 4 张补画）、`docs/qa/20260925-team-food-kitchen.png`（实际 Godot 厨房画面）。
