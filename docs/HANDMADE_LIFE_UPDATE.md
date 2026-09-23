# 手绘生活界面与海边垂钓 · 2026-09-22

这次将货架、菜筐、食材、价签、小票、料理台和菜谱接入同一套原创蜡笔 / 水粉素材。所有商品、数量、价钱、列表、按钮和编辑操作由原生 Godot Control 实现；图片是单独物件，不是完整 UI 截图或透明热点。

## 明确参考与取舍

- [Venba 官方介绍](https://venbagame.com/) 和 [官方 press kit](https://venbagame.com/press/)：以食物、手边器具和菜谱作为操作中心；参考料理与记录的关系。Solmere 的食材顺序、火候、采购和工资仍来自现有玩法。
- [Tiny Bookshop 官方网站](https://tinybookshopgame.com/)：将存货直接摆进实体陈列空间。本次杂货使用三层货架，蔬菜使用摊位菜筐；点击独立商品后看价签、放入购物篮。
- [DREDGE 官方介绍](https://www.team17.com/games/dredge/)；[钓鱼机制资料](https://strategywiki.org/wiki/DREDGE/Fishing)：选择定时收线作为玩法参照。Solmere 实现了等候咬钩、及时提竿、指针区间、命中加速、失误松线与从容模式。没有移植对方代码、图像、音效或完整界面。
- 颜色、轮廓、手绘素材全部为本项目生成并审阅。画面刻意采用有限的海蓝、暖白、柠檬黄、草绿；没有采用现成 icon 库。

## 实际操作

杂货店或菜摊 → 点货品 → 查看真实库存/价格 → 放进购物篮 → 打开篮子 → 调整数量/取出 → 结账。结账只生成一笔流水、一张分项小票；“买过的东西 / 小票”可以回看。物品进入随身包，小票进入生活记录。未结账购物篮跨关闭、保存和读取保留。缺货、余额不足、店铺收起、空闲时间不足都接现有规则。

混合购物篮按行保留分类。采购报销只覆盖订单需要的一份食材，私人用品和多买的数量不会被报销。旧单件购买入口仍保留，B 的第一次小票反馈也沿用原逻辑。

料理台 → 取三样实际可用食材 → 为每样选择一种备料方式 → 自由决定实际下锅顺序并重新看火 → 自选手法与翻拌次数 → 尝味调味 → 选择装盘 → 选择出餐。冷食材会带走锅温，偏差改变过程记录但不强制倒掉整锅，后续动作可以补救；原班次和工资逻辑保留。菜谱包含店主原有页面、玩家页面、朋友页面。玩家能编辑菜名/署名/说明并画线稿；退出或切页时保存草稿，存盘失败则留在原处。正式保存的备料、实际顺序、火候、翻拌手法、调味、装盘、文字与笔迹都能读取。长说明独立滚动。详细状态与素材交接见 `docs/COOKING_GAMEPLAY_REFINEMENT.md`。

朋友菜谱当前使用 **.solmere-recipe 文件交换** 和现有公共资料库。导出文件交给朋友、导入后查看并照着做；没有伪造在线玩家或在线菜谱流。导入验证食材、坐标、大小、火候并以内容散列隔离外来 ID。

海边钓位目前位于公交站、杂货店所在海岸、观景台（白天也能钓）。靠近提示后交互进入；每竿消耗 10 分钟，随时可收竿。浮漂会轻晃和下沉，收线命中有动作/声音反馈。鱼获可带回厨房或放生，两者都留记录；待处理鱼获先保存，收竿重开不会丢失。首批两种鱼：沙丁鱼、金鳍海鲷。鱼获进入现有背包、生活材料和料理食材。

声音整理、照片构图、局部空间错觉、档案核对的原生工作台也换用同套生成的器具与纸页。波形、指针、投影辅助线属于实时交互图形，玩家笔迹来自真实输入。

## 数据与组件

- `EconomySystem` / `GameState` / `SaveManager` 继续作为钱款、库存、时间与保存的唯一入口。
- `artifacts.economy.carts[shop_id]` 为未结账购物篮；receipts / collections 继续使用原数据。
- `artifacts.recipes` / `shared_state.world_artifacts.recipes` 保存菜谱；`artifacts.recipe_draft` 保存未完成页面。
- `artifacts.fishing` 保存 pending、catches、relaxed；每条鱼获拥有独立 catch_id、鱼种、长度、日/时间、地点、角色与去留。
- `HandmadeAssets` 缓存纹理，`HandmadeItem` 提供独立商品交互，`GoodsCard` 将同一素材用于背包。真实文字独立渲染。
- 使用现有字体与 Theme / SolmereButton，保留 hover / pressed / focus / disabled / selected。钓鱼快捷动作走 Input Map；鼠标、键盘焦点与原生 ui_accept 均可操作。
- 所有素材均随仓库提交，可离线运行；运行游戏不需要 imagegen、Python 或源图路径。

## 美术生产记录

工具：Codex 内置 `image_gen.imagegen`。首版物件过于体积化，被放弃；随后要求更平面、简化、蜡笔轮廓。最终导出透明 PNG 后裁成独立资源，并在 Godot 实际渲染中校对切边、尺寸、排版与对比度。`tools/prepare_handmade_assets.py` 只裁切/清除误带入的邻格碎片，不生成绘画。

| 组 | 已采用生成文件 | 项目资源 |
| --- | --- | --- |
| 16 件货品/食材/鱼 | exec-72955414-025b-4d32-91e7-eec2a7f07f73.png | tomato、lemon、herbs、sea_beans、bread、cheese、soap、matches、star_salt、crooked_cup、hotel_307_tag、misprint_postcard、ticket_bundle、blue_stamp、sardine、sea_bream |
| 陈列/料理器具 | exec-58a39f87-d7bd-4c99-a375-60f7ecc2d54b.png | shelf、crates、worktop、basket |
| 纸张与早期鱼竿 | exec-ce21d051-bad5-411f-b687-05277611263d.png | receipt、tag、recipe_book、rod |
| 随身包布料内部 | exec-37752d92-8a73-4833-9d4a-5eb762b13038.png | tote（只采用布面内部） |
| 其余原生工作台 | exec-da2ee9d6-bad6-4901-b674-0e8583aca6dd.png | tape_workstation、photo_mat、archive_sheet、window_frame |
| 独立钓具 | exec-f2893df0-b204-4605-adba-6d5fd8c2d1fe.png | rod_clean、float、tackle_mat |

生成源文件保留在本机 Codex generated_images 会话目录；运行时使用的独立 PNG 均在 `art/ui/handmade/`。不依赖源文件的绝对路径。

### 原始提示词与修改提示词

#### 货品

```text
Create a production 2D sprite sheet for Solmere, a quiet hand-painted Mediterranean seaside game. EXACT uniform 4 columns by 4 rows, 16 separate objects, one object centered in each equal cell, ample transparent gutter, true transparent alpha background. NO text, NO labels, NO grid lines, no shadow outside objects. Loose confident dark blue pencil contour with tiny irregularities, flat opaque gouache and colored-pencil hatch shading, simple charming doodles in a hand-illustrated family recipe book, NOT glossy 3D, NOT realistic rendering, NOT polished vector. Restrained sea blue, warm cream, lemon yellow, sage with muted tomato red accents. Objects row-major: row1 ripe red tomato with leaves; pair of yellow lemons; tied bundle of fresh green herbs; a short blue-and-cream sea-bean tin with a simple bean doodle on its paper label. row2 rustic round loaf bread with cuts; yellow cheese wedge; sage sea salt soap bar in paper band; small yellow matchbox with red match. row3 squat jar of star-shaped salt flakes; lopsided blue ceramic cup; brass hotel key diamond tag and ring; small seaside postcard. row4 cream bus-ticket bundle; blue rubber postal stamp; silvery blue sardine fish; sea bream fish with a yellow fin. Each silhouette large but entirely inside its cell. Texture subtly visible inside painted shapes only. Coherent simple illustration by same artist.
```

```text
Revise this sprite atlas to much simpler actual 2D DOODLE ART like quick charming gouache illustrations in an indie narrative cooking game's handwritten family cookbook. Keep exact 4 by 4 layout and same sixteen identifiable items. ELIMINATE realistic volume, rendering, shine, cylindrical perspective detail, wood texture, metallic detailing and the illustrative engraving. Each object should consist of only 2 or 3 broad flat opaque paint colors, a few sparse crude dark-blue pencil strokes, visibly asymmetrical silhouettes. Cheese: plain yellow triangle with 3 pencil holes. Tin: squat naive cream shape with blue top and 2 bean squiggles. Herbs: 8 loose leaf strokes, not botanical detail. Fish: simple flat blue silhouette, tiny eye, 3 or 4 pencil lines. Childlike naive editorial doodles but aesthetically confident. Light dry-brush texture only, lots of simple blank color. NO 3D whatsoever. True transparent alpha around every object. Keep clear gutters. This must look like little actual hand drawings, not products rendered with a pencil filter.
```

#### 器具

```text
Production illustration sprite atlas, 2 columns x 2 rows with four isolated empty furniture/prop assets for a 2D hand-painted seaside game Solmere. True transparent background alpha, no floor, no wall, no text, no UI panels, no items for sale. Same hand of a warm simple illustrated recipe book: matte flat gouache, slightly crooked dark sea-blue pencil outlines, restrained colored-pencil hatching and paper-grain inside painted surfaces. Charming everyday doodle, not rendered 3D, not realistic, not vector. Palette sea-blue painted timber, pale mint, warm cream, light honey wood, small lemon yellow details. Upper left: front-facing tall blue wooden grocery cabinet with THREE roomy empty open shelf bays, wide shelves and narrow frame, no glass, no doors, no goods, camera straight-on. Upper right: farmers market stand, three empty shallow wooden produce crates on a low tilted blue trestle table, all interiors visible, no produce. Lower left: large oval pale honey wooden chopping board and blue enamel frying pan on left half with long handle to the right, one wooden spoon near edge, orthographic overhead, pan empty. Lower right: a simple woven shopping basket with two blue handles and cream cloth lining, three-quarter view. Four individual assets entirely within four equal square cells, generous transparent gutters, no overlap, no external drop shadows. These are EMPTY furniture to hold separately interactive product sprites later.
```

```text
Redraw the attached four furniture assets as extremely simple FLAT 2D painted doodles. Keep 2 by 2 atlas with empty THREE-BAY grocery shelf top left, empty three-crate stand top right, chopping board and empty frying pan bottom left, shopping basket bottom right. NO real wood grain, NO wicker weave detail, NO 3D rendering, NO bevels, NO aged distressed texture, NO lighting gradients or shiny highlights. Limit each asset to 3 flat opaque gouache colors, minimal sparse dark-blue wobbly pencil strokes. Almost children's-book paper-cut shapes with a few loose pencil marks: handmade, witty, humble and clean. Bright muted sea blue, pale sage, lemon cream, pale honey; tiny drybrush granulation. Shelf front-facing straight-on with clear roomy empty bays. Basket drawn as simple blue and cream silhouette with at most 6 weave lines. Generous transparent gutters, each object fully inside its equal cell. True transparent alpha background. These must look DRAWN BY HAND in a cooking notebook, not realistic objects with a filter.
```

#### 纸张

```text
Create one coherent production sprite atlas, exact 2 columns by 2 rows, true transparent background. Four isolated HAND-DRAWN paper and fishing props for Solmere seaside life game. Same simple recipe-book doodle aesthetic: matte warm-white gouache fills, imperfect sea blue pencil outlines, tiny sparse lemon and sage accents, subtle paper fibers, NO realistic shading, NO 3D, NO computer-perfect vector, NO text or numbers anywhere. Top left: long blank shop receipt, warm white, gently uneven torn serrated lower edge, little lemon doodle at bottom corner, central 85% fully empty for real text. Top right: wide blank ivory hanging price tag with one punched hole and short tied blue string on the left, empty center. Bottom left: open recipe notebook viewed flat from above, two large blank cream paper pages, thin yellow cloth spine, small herb sprig doodle at bottom, no lines/no words/no ingredient illustrations, ample blank space for live game text and player drawings. Bottom right: wooden fishing rod with sea-blue reel, thin curved line, separate small red-and-cream fishing float beside it. Each isolated asset centered entirely within its own square cell, transparent gutters, no background, no cast shadows, cohesive charming hand lettering stationery feel without any actual lettering.
```

```text
Redraw all four props in this 2x2 atlas as VERY SIMPLE flat 2D doodles made with a few uneven blue pencil strokes and opaque cream paint. Top-left long blank receipt, top-right blank string price tag, bottom-left open blank recipe book, bottom-right simple blue fishing rod and float. Remove realistic volume, gradients, textures, reel mechanisms, ornate outlines, realistic paper edge shadows. No text. Few broad colors. Plain warm-white surfaces with tiny lemon doodle accents, blue loose line work. Receipt and notebook centers must stay entirely blank. Light drybrush flecks only, handmade graphic cooking-game art. True transparent alpha background. Same layout fully inside each cell with gutters. Do not add more detail, simplify dramatically.
```

#### 布包

```text
Create one single isolated flat 2D doodle of a blue and cream fabric tote bag opened and spread flat like a picnic cloth, seen from above, generous flat pale warm-cream cloth central area fully empty, tiny sea blue stripes just along the left and right edges and short looping cloth handles visible outside, overall landscape rectangular soft irregular fabric shape without rigid frames. Solmere Mediterranean seaside game art. Naive flat opaque gouache shapes with minimal dark blue wobbly colored-pencil strokes, tiny drybrush speckles, at most three colors, charming hand drawn family cookbook illustration, NO real textures, NO 3D, NO realistic rendering, NO shadows, NO objects on it, no text, no border boxes, no stitched detailed patterns, no UI. True transparent alpha background. Wide landscape composition. Intended as an empty physical surface for independently drawn game inventory objects, NOT a complete UI.
```

```text
Keep the cloth tote illustration exactly, but DELETE ALL surrounding blue-gray-black background and all halo/shadow. Output true transparent alpha outside cloth and handles, including the holes inside both handles. No glow, no shadow, no gray backdrop, no black backdrop, no checkerboard painted into the image. The only opaque pixels should be the simple cream cloth with blue stripes and the handles.
```

#### 工作台

```text
Create an ORIGINAL game production sprite atlas on TRUE TRANSPARENT background, matching the attached Solmere art's FLAT rough wax-crayon / gouache doodle technique, simple irregular dark sea-blue outlines, opaque warm-ivory, lemon-yellow, faded sea-blue, tiny sage accents. NOT a rendered product, no shadows, no bevels, no realistic materials. Four SEPARATE props spaced widely in a 2x2 grid, each fits completely inside its quadrant. These are separated cutout assets, not a screenshot or complete UI. TOP LEFT: a broad flat blue portable cassette recorder/workstation, front face mainly one large EMPTY pale cream rectangular panel in its upper two thirds (for a real animated waveform overlay), two small dark cassette reels drawn along its bottom rim, small lemon switches at far edge, NO drawn screen text or drawn UI controls. TOP RIGHT: a broad empty warm-white landscape photograph mat with a blue crayon outer edge, corner tape bits; center cutout truly transparent, a simple yellow camera resting beside one outer corner but never covering the transparent central area. BOTTOM LEFT: one empty tall cream archival sheet with two tiny blue tabs and a little yellow binder clip, at least 85 percent clear blank space, no text or fake lines. BOTTOM RIGHT: a simple EMPTY sea-blue wooden window frame, drawn as a flat handmade shape with a few uneven crayon strokes, broad rectangular opening truly transparent, no cross-bars or glass. Again flat illustrated 2D physical props for a handmade coastal town, limited colors and dry imperfect strokes, no 3D shading, not smooth vectors, NO lettering, NO extra motifs, NO checkerboard pattern, real alpha. Four unrelated props neatly separated for cropping.
```

#### 钓具

```text
Generate ORIGINAL transparent 2D game CUTOUT atlas matching the attached Solmere crayon/gouache art. EXACTLY THREE separated props on TRUE TRANSPARENT background with generous empty margins. Upper left: ONE simple fishing rod angled bottom-left to top-right, lemon ochre bamboo, loose uneven thick sea-blue crayon outlines, off-white wrapped handle, small blue guide loops. NO fishing line, NO hook, NO bobber attached. Upper right: ONE tiny separate upright fishing float / bobber: bright tomato-red tip, creamy white oval body, 1 narrow blue stripe, blue bottom eyelet. Front view, clean silhouette, NO string and NO water and NO shadow. Bottom half: ONE broad horizontal fisherman's cloth mat, roughly 3:1 ratio, plain opaque warm-cream center taking 90 percent of area, uneven double blue crayon sewn edging, one very tiny yellow knot at far bottom right only. Absolutely EMPTY center so live text and actual game controls can sit there. No artwork labels, no buttons, no text, no numbers, no fish. ALL objects FLAT handmade shapes with dry wax-crayon grain and restrained gouache fill, few colors, deliberately simplified doodle expression. NOT a volumetric realistic render, no cast shadow, no halo, no bevel, no lighting gradient, no checkered background, real alpha outside shapes. The style must stay identical to the reference art. This is artwork only, never a full UI screenshot.
```

## 验证

以 `--isolated-save` 使用隔离存档，未覆盖玩家正常存档。

- `test_handmade_life.gd`：55 项检查，包括购物篮/小票、存盘失败回滚、数量与采购报销、菜谱草稿/导入导出、鱼获保留与放生、存档读取、鱼作为食材实际消耗。
- `test_v3_economy.gd`：51 项检查，原采购 → 购买 → 报销 → 料理 → 工资链路。
- `test_native_modules.gd`：5 个原生模块均可完成、写回原结果合约。
- `test_save_failure_recovery.gd`：通过。
- `test_production_ui.gd`：0 失败，28 张运行画面。
- 另进行 OpenGL 真机截图检查与真实可玩窗口的货架/海边操作。

本地快速试玩：`Godot --path . --script res://tools/preview_handmade_life.gd -- --isolated-save`；追加 `--fishing` 从观景台钓位开始。开发预览使用隔离存档，正式游戏入口保持原样。
