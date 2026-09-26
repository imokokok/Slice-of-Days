# 追加番茄原画与接入（2026-09-25 至 2026-09-26）

用户追加的 `df995921916e28abe9a9c7634fd6bc34.jpg` 是 1079 × 1527 的白底 RGB JPEG，作为普通食材 `tomato` 的团队原画。原件按原字节保存在 [`supplied_assets/20260925-tomato/tomato-original.jpg`](supplied_assets/20260925-tomato/tomato-original.jpg)，SHA-256 为 `682335f386a407c78cd7141c0049c4e9c37c2f83cd019be4cb2eeba17cd0bea9`；版权仍归提供原画的团队。

此前内置 imagegen 去白底候选重新描绘了局部笔触，因此被拒绝，没有接入。2026-09-26 用户明确批准**仅程序去白底并替换**。本次用可复跑的 [`prepare_tomato_art.gd`](../tools/prepare_tomato_art.gd) 从原 JPG 裁取 `(417,472,198,176)`，只根据像素与白色的距离生成 alpha，所有 RGB 像素保持原样。输出的 [`tomato.png`](../modules/restaurant/assets/derived/tomato.png) SHA-256 为 `a272899150076014d879f3c58068e848f4e1675690237d8cdc113965ea5e663e`。为避免 Godot 导入时改写透明边缘的 RGB，该素材单独关闭 `fix_alpha_border`；导入后逐像素比较，原图裁切区域的 RGB 差异为 0。来源与派生参数也保存在 [manifest](supplied_assets/20260925-tomato/manifest.json)。

`sprite_library.gd` 的共用 `tomato` 入口现在优先加载此透明原画派生图。冰箱第一页、手持与物理轮廓、切块保留的表皮、受热、锅内、摆盘、拍照及菜谱插画沿用同一入口。切面内部仍使用此前**以该团队原画为参考**生成的 `cut_states/roots.png`；它是另行标记的派生切面，不冒充原画本身。照片仍由实际摆盘截图获得。

[实际厨房截图](qa/20260926-tomato-replaced-kitchen.png) 显示冰箱首格的新番茄；[实际菜谱截图](qa/20260926-tomato-replaced-recipe.png) 显示取番茄步骤和纸页，同时验证冰箱标签没有再盖在菜谱上。`test_tomato_art.gd` 无头 12 项、GPU 16 项通过，覆盖原图哈希、全部 RGB 像素、透明边缘、物理轮廓、冰箱、切配与菜谱；完整回归见 [验证记录](qa/20260926-tomato-regression.txt)。

[更新后的完整做饭视频](../../../demo/100Restaurant_Kitchen_Flood_Rack_Full_Cooking_20260926_CN.mp4) 已重录并替换 `demo/` 中的上一版：Godot 正式场景自动操作 3960 帧、24 FPS、165 秒，含原生游戏音轨，覆盖淹水、新番茄取材切配和入锅、敲蛋、调味、摆盘、出餐、翻菜谱以及汤碗补充片段。独立导出的游戏 PCK 已成功载入新番茄贴图（198 × 176，透明背景和不透明主体均正常）。

本项目对 JPG 边缘的透明度采用白底阈值近似，不能从原 JPG 恢复不存在的原生 alpha；未使用任何重绘番茄版本。其余未补齐的食物原画状态另见团队素材记录。
