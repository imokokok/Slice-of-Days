# 验证记录

## 2026-09-25 玩家手动切菜与完整流程复查

- Godot 4.7.2 真实鼠标及键盘专项 `test_manual_cutting.gd` **18 项通过**：刀柄经过食材、提刀返回、转刀本身不切；顺向完整刀线切出两片；R 与滚轮调整后横切成小块；偏心落刀得到重量小于整件四分之一的薄片；每次分切质量守恒。
- 原有刀具 **20 项**、操作舒适性 **90 项**、切块整批入锅 **42 项**、切片受热及摆盘连续性 **37 项**、切配清洁分享 **86 项**、餐厅集成 **124 项**通过。顾客评价专项 **35 项**通过，增加同瓶六滴不误判、70 ml 过量应提醒的用例。
- 以固定 24 FPS 跑通生产场景完整流程，并在 Apple M4 / OpenGL 实际渲染录制 **1248 帧、52 秒**，见 [新完整视频](qa/20260925-manual-cutting-full-cooking.mp4)。录像脚本检查手动横切确实产生小块，切块入锅、敲蛋、蛋熟、挤酱、摆盘和出餐评价。抽查切菜、入锅、加热与顾客评价关键帧；终局不再称同瓶小量番茄酱为六份调料。

## 2026-09-25 手动敲壳与壳片动画

- `test_egg_cracking.gd` **14 项通过**：完整蛋直接落锅不破壳；第一下只留下裂纹；第二下才分出蛋液与两片蛋壳；两部分质量守恒、来源 ID 相同；壳片停在锅外台面；清理时计入废料。`capture_egg_cracking.gd` 用真实柜格取物和鼠标事件通过同一流程。
- 受影响回归通过：`test_kitchen_interactions.gd` 35、`test_visual_spatial_consistency.gd` 36、`test_reaction_kitchen.gd` 32、`test_material_physics.gd` 333、`test_integration.gd` 124、`test_stock_volume_recipe.gd` 25、`test_seasoning.gd` 155、`test_recorded_audio.gd` 151、`test_slice_cooking_continuity.gd` 37。Godot 4.7.2 无头启动 120 帧退出 0；macOS 系统 CA 证书提示不是脚本错误。
- 同一空间专项在 Apple M4 / OpenGL 图形环境下 **41 项通过**，包含实际锅壁遮挡像素与手持/陈列尺度复查。
- Apple M4 / OpenGL 实际图形录得 [敲蛋短片](qa/20260925-egg-cracking.mp4) **163 帧 / 24 fps / 6.79 秒**，以及 [更新后的完整烹饪录像](qa/20260925-full-cooking.mp4) **1195 帧 / 24 fps / 49.79 秒**，均合成 Godot 当次实录音频。逐帧查看裂壳后的鸡蛋、蛋液下落、锅中蛋与锅左侧两片壳、锅中挤酱和 **92 分**出餐评价。完整录像的拍照步骤未录入：Movie Maker 下异步 `frame_post_draw` 不可靠，拍照沿用独立 GUI 测试。以上是自动化 QA 操作和图形目视检查，未冒称人工自由试玩。
- 仍为二维近似：两次锅后沿点击代表接触施力；蛋液、蛋黄与壳片的连续性有质量及来源记录，但蛋白/蛋黄没有独立流体物性或搅散状态。壳片飞行由动画引导，落地后交给刚体。系统鼠标长期自由玩法尚待人工验收。

## 2026-09-25 厨房空间与完整烹饪二次优化

- Godot **4.7.2** 无头启动 120 帧、退出 0，无脚本错误。定向回归通过：`test_reference_layout.gd` **40**、`test_shelf_pages.gd` **260**、`test_visual_spatial_consistency.gd` **36**、`test_kitchen_interactions.gd` **35**、`test_knife_drag.gd` **20**、`test_seasoning.gd` **155**、`test_stock_volume_recipe.gd` **25**、`test_material_physics.gd` **333**、`test_reaction_kitchen.gd` **32**、`test_thermal_reactions.gd` **20**、`test_cut_clean_share.gd` **86**、`test_recipe_guide.gd` **40**、`test_handdrawn_assets.gd` **227**、`test_slice_cooking_continuity.gd` **37**、`test_integration.gd` **124**。锅柄和热状态夹具已改为依据当前锅变换与真实接触，不再用旧绝对坐标或会绕过热模型的计时加热。macOS 系统 CA 证书提示与厨房脚本无关。
- Mac Apple M4 / OpenGL 下重新抓取并目视检查 [厨房全景](qa/20260925-storage-compositing.png)：锅口在木架前沿下方留出间距；五格瓶底进入沟槽；左侧五瓶显示和命中区域彼此分开；奇物落在层板上，标签处于木前沿；刀完全在菜板内。布局测试同时断言架子、锅、刀、奇物底线及左侧调料区域。
- 完整录像已在后续敲壳更新中重录为 **1195 帧 / 49.79 秒**，详情见上节。摄像脚本断言蛋熟、挤酱入锅、摆盘物件在盘内；录制时清空番茄酱格原生 tooltip，正式游戏提示未改。
- 当前背景仍是一张图；局部层板前沿重绘不等于完整深度场景。鸡蛋的后续敲壳实现见上节。不同批次素材的光照、视角和笔触仍需逐件美术验收。

## 2026-09-25 素材贴合、遮挡与质量关系

问题清单及实现边界见 `VISUAL_SPATIAL_AUDIT_20260925.md`，证据目录 `qa/20260925-visual-spatial/`。

- 完整 `tools/test.ps1` **36 个入口全部通过**，退出 0，无 SCRIPT ERROR / ERROR / FAIL；97 张素材 alpha 审计 0 错误。日志 `regression.txt`。新增空间专项 headless **36 项**，实际 GPU **41 项**通过（`spatial-gpu.txt`），覆盖落锅固体接触、按可见轮廓选取、锅沿像素遮挡、十件调料尺寸、搬运状态、1000 次微量出料及挂酱质量/体积连续性。
- 查看四张空间 GPU 图及生产热变化图。最后仅调整工具提示纸底样式后，操作舒适性 **90 项**与生产热变化 GPU **37 项**复验通过，日志 `comfort-final.txt` / `reaction-gpu.txt`。GPU 为 RTX 4050 / OpenGL，截图来自隔离 QA 菜谱库，不含玩家私人纸页。
- 实际 Windows 鼠标验证：进入练习、橄榄油取出/放回、番茄和鸡蛋同点落锅后分离、抬锅携带食材、胡萝卜放到固定菜板并用刀切开、番茄拖到餐盘、进入摆盘并移动番茄。各步均重新观察真实窗口。短按出油未达到持续倾倒人工验收，持续出料由原有 155 项调料输入专项覆盖。
- 外部录音文件审计 **35 来源 / 49 WAV / 32 分组 PASS**，见 `audio-audit.json`；本轮没有加入新音效，也没有完成人耳逐条试听。
- 最终源码及 Windows 导出包分别 headless 120 帧启动退出 **0**，无脚本错误（`smoke-source.txt` / `smoke-export.txt`，`smoke-export-errors.txt` 为空）。Windows Release 导出成功，包含新增锅几何、水面及出料层脚本，保留 MIT/OFL 许可；QA 图、文档和测试资源不进入试玩包。EXE SHA-256：`ed2656591960b23bd812fc618a96d459598304ca0f5213ba448076d18b27eb07`。
- 最终导出重新打开，PID **38560**，标题 **100饭店**，Responding=True；经原生窗口工具重新查看练习厨房及浅色底深色字的翻层提示。窗口留给用户试玩。实际窗口中的既有玩家菜谱没有保存或上传；操作记录见 `live-check.txt`。

本轮修复不等于商业成品验收。二维刚体/热变化和水面仍是近似；素材批次笔触差异、尚未透明接入的 13 张黑底蔬菜 JPEG 与白底番茄、全食材专属切面、长时间多客人压力试玩等仍列为缺口。

## 2026-09-25 锅内热变化与质量连续性

实现、问题清单及近似边界见 `THERMAL_REACTIONS_20260925.md`；证据目录 `qa/20260925-thermal-reactions/`。

- 最终 `tools/test.ps1` **35 个入口全部通过**，退出 0，`regression-final.txt` 无 SCRIPT ERROR / ERROR。包括新热模型 19、生产厨房 31、材质 333、录音 151、手绘 227、集成 124、跟做 40、刀物理 35、切片连续性 37、厨房交互 35、DIY 76、纸面存档 30 等；全目录 alpha 审计 97 张、0 错误。新 runner 同时检查错误文本和成功标记，不以退出 0 掩盖脚本报错。
- 回归过程中修复：旧夹具直接加秒数绕过锅温；旧已熟实体迁移丢失焦色；无水油膜错误发滋响；木勺统一密度；DIY 丢失热/酱色；StringName 键及 JSON 浮点整数导致保存/重开拒绝。测试仍验证物理结果，没有删除原熟度/焦化要求。旧加热测试现推进真实锅温与水浴；冷锅和空水没有偷偷预热。
- 最终实际 GPU 运行厨房专项 **37 项通过**，RTX 4050 / OpenGL，`gpu-final-errors.txt` 为空。查看 `kitchen-sauce.png`、`kitchen-plated.png`、`kitchen-butter.png`；覆盖真实锅内附着、装盘同色、黄油融化与面包润湿，截图来自独立 QA 菜谱库。修正了截图夹具在 drop 后立即重定位被 deferred transform 覆盖的问题，额外验证截帧时食物仍在锅中；没有为截图移动系统鼠标。
- 完整回归后，交付检查额外修复“吸附完的空酱汁仍占配方条目”和“表面褐变抬高生心品质分”。最终复验热模型 **20**、厨房 **32**、domain **552**、集成 **124**、录音 **151**、调料 **155**、锅铲 **29**，全部通过（`thermal-final.txt` / `final-affected.txt`）；最后 GPU 37 项及源码 smoke 也重新执行。
- 五类热变化排列图 `progression.png` 使用生产状态模型和 FoodArt，5 组前后图像差异通过，并实际查看；画面已知黄油包装随固体部分一起消失的素材缺口没有隐瞒。该图不是人工操作录像。
- 外部录音审计 **35 来源 / 49 WAV / 32 分组 PASS**（`audio-audit.json`）。实际 Godot 音频总线捕获 34.763 秒，峰值 0.137848、0 削波样本，末段静音采样为 0；分段测量见 `mixer-analysis.json`，状态时间线 `mixer-timeline.json`。各可听阶段非零，不等于已完成人耳混音验收；完整 WAV 留在本机 `work/reaction-qa/actual-mixer.wav`，不重复纳入源码仓库。
- 最终源码及 Windows 导出包分别 headless 120 帧启动退出 0，无脚本错误（`smoke-source.txt` / `export-smoke.txt`，`export-smoke-errors.txt` 为空）。Windows Release 导出退出 0，包含 thermal/snapshot/reactions 脚本及既有 MIT/OFL 许可；导出明确排除 QA 截图与测试资源。EXE SHA-256：`2354a4a6da21b74b38c9d33b1d6e94778d07912cd02256ddeab38c648700dd26`。
- 重新打开最终 EXE，PID **36548**，窗口标题 **100饭店**、MainWindowHandle 非零、Responding=True；实际查看该进程生成的生产 viewport 图 `work/reaction-qa/live-final.png`，欢迎页与厨房正常，窗口留给用户试玩。图中含本机已有玩家纸页，只留本地；没有上传它。

已验证范围是自动回归、引擎输入事件、受控 GPU 场景与实际混音输出；尚未人工长时间试玩或人耳逐条试听。不声称不存在其他 bug，不声称完整流体/柔体或绝对现实。

## 2026-09-25 手写订单与纸面创作

报告 `PAPER_CRAFT_20260925.md`，证据目录 `qa/20260925-paper-craft/`。

- 新专项 headless 38 项、GPU 44 项通过（`test.txt` / `gpu.txt`，`gpu-errors.txt` 为空）。原生文本编辑、中文换行与首行稳定、结束前后同变换、双击/取消/清空、撤销重做、草稿隔离、实际用料、真实摆盘照片和同源菜谱展示均有断言。
- 12 个受影响回归入口通过：菜谱 DIY 76、共享工具 30、GUI 输入 68、胶带 75、拼贴 39、纸面存档 30、集成 124、跟做 40、切配/清洁/分享 86、窗口/操作舒适性 90，加海报持久化及存储 smoke。原始结果在 `regression-editor.txt` / `regression-flow.txt`。
- 实际查看五张生产场景 GPU 图：`final-order.png`、`final-order-open.png`、`final-writing.png`、`final-desk.png`、`final-reader.png`。早期画面纹理过重、原生灰色滚动条和海报底栏问题修正后复验。所有提交图均来自隔离测试库。
- GPU 原生拖放的自动注入受系统鼠标位置影响：完整落点断言在 headless 执行；GPU 使用生产 drop 入口的显式坐标做视觉检查，没有移动系统鼠标，也没有将它标成人工拖放。Windows 中文 IME 候选窗和长时间人工创作仍未手工验收。
- 最后的 IME 提交次序调整后复验专项 38 项、GUI 输入 68 项、GPU 44 项及源码 120 帧 smoke 均通过；原生合成提交先保持文字首行锚点，再结束编辑。Windows release 导出成功，最终 EXE 120 帧 smoke 退出 0 且错误输出为空。EXE SHA-256：`54c7ca2d797155ede23b13a516b703688b137abe4cb18704d95d29fd69f5a66c`。OFL 字体许可随导出资源及 Windows 包附带。
- 已重新打开最终 EXE（PID 27296，窗口标题“100饭店”，Responding=True）并查看生产 viewport 截图 `work/paper-final-live-export.png`；厨房和欢迎页正常。该图含本机既有玩家作品，仅留本地，不上传仓库。

## 2026-09-25 材质物理与容器反馈

证据目录 `qa/20260925-material-physics/`，实现及开源取舍见 `MATERIAL_PHYSICS_20260925.md`。

- `tools/test.ps1` 完整 32 个入口执行完成：材质专项、切配/清锅/分享、手绘、柜层、引导、录音，以及原有 26 个后段入口全部通过；`regression.txt` 无脚本错误，97 张素材 alpha 审计 0 错误。新专项在该轮为 312 项。
- 最后补充零出料、溢出质量守恒和 19 种容器持续出料朝向后，专项 **333 项通过**（`material-final.txt`）。同一圆形测试碰撞体、同高度实际 Godot 刚体落地，石头材质回弹 1.014 px、网球材质 39.011 px；该控制夹具隔离材质，不宣称现场实测物理常数。也验证等重力、差异滑动、油膜摩擦、受热软化、轻重食材锅铲响应、局部压缩/喷口固定/回弹、低余量出料及数值衰减。
- 最后的影响范围复验：锅容量/库存/同源菜谱 25 项、录音路由 150 项、手绘 227 项、调料输入 **155 项**、完整流程 126 项通过。修复持物旋转与素材适配器重复翻转导致部分瓶口朝上的旧问题；19 种容器由实际生产更新函数推进，另有 7 组引擎输入事件检查持续出料朝向。最初 GPU 夹具的合成鼠标位置被当前系统鼠标覆盖，改为显式传入测试目标点，不接管系统鼠标，不将该夹具称为人工拖动。
- 实际 GPU 最终运行专项 **333 项通过**，`gpu-final.txt` 确认 RTX 4050 / OpenGL。已逐图查看 `material-packaging.png`（油瓶保持刚性，番茄酱/芥末/牙膏局部凹陷，瓶盖未整图缩放）、`material-kitchen.png`（真实主场景中的番茄、胡萝卜、豆腐独立切块与固定菜板）、`material-dispensing.png`（番茄酱持续出料时瓶口朝下，流束连接瓶口）。包装对照图直接使用生产 FoodArt 渲染器设置三种状态；动力学另有时间推进断言，静态图不冒充操作录像。出料图中的既有台面溢出来自容量测试夹具，不表示挤压两下就会溢出。
- 最终源码与 Windows EXE 均 headless 120 帧启动通过、退出 0，无脚本错误，见 `smoke-source.txt`、`export-smoke.txt`（错误输出为空）。Windows release 导出退出 0，包含新物性 JSON、响应脚本及 MIT LICENSE/NOTICE。EXE SHA-256：`96d0aa03add9b85afbd5c1e4a371610794db4fbe9197372993b90046cc051b51`。
- 已重新启动最终 `AfterHoursKitchen.exe`，确认窗口标题“100饭店”、Responding=True（PID 31068），从导出包生产主场景抓取并查看 `work/material-live-export.png`，正常显示当前厨房与营业入口。该图含本机既有私人作品，仅留本地；提交的 GPU 图来自独立测试状态。
- 已实现但未人工验收：系统鼠标连续多客人乱操作、逐录音人耳混音。近似实现与尚未实现的软体、自由液面、破碎等范围见专项报告；没有声称“绝对仿真”。

## 2026-09-25 切配、残味清洁与单页菜谱

本轮证据目录：`qa/20260925-cut-clean-share/`，具体修复与边界见 `CUT_CLEAN_SHARE_20260925.md`。

- 最终 GPU 专项 **89 项通过**：48 张切面资源读取（42 有效、6 备用），实际连续切割与酱汁守恒，落板位移/转角/暂停/停稳，有限残味转移到下道菜及评价，关火与空锅检查，实际擦拭接触及冲洗，输入事件拾取/移动/释放抹布，菜谱食材身份，分享注入转义、单页私密隔离、独立库重新导入。日志 `gpu-final.txt`。
- 后段完整回归 **26 套件全部通过**（`regression-final.txt`）：domain 552、integration 126、high fidelity 15、knife 35、knife drag 20、cut batch 42、slice continuity 37、layout 18、stock/pan/recipe 25、collage 39、collage input 68、paper recipe 30、DIY 75、tape editing 75、tape tools 30、seasoning 148、spatula 29、heat 23、interactions 35、reviews 33、free pan 9、workstations 17、comfort 90，另存储、海报存储和 97 张图 alpha 审计（0 错误）。
- 首段回归中手绘 227、柜层 260、引导 40、录音 150 均通过，交付前补留完整输出 `assets-and-guide.txt`。首轮 domain 因旧目录数量断言失败，按当前 97 个定义 / 95 个可用及四分类更新后复验通过；未删除功能检查。原始首轮日志 `regression-first.txt` 保留失败及修复背景。
- 最后纸页背景融合改动后重新跑 5 个相关套件：切配/清洁/分享 86、引导 40、DIY 75、拼贴 39、拼贴输入 68，全过。GPU 的额外 3 项涉及正常 DIY 页输出及修订后 JSON；不累计重复执行的检查数。见 `final-affected.txt`。
- GPU 证据 `proof-board.png`、`proof-clean.png`、`proof-recipe.png`、`cut-faces.png` 逐图检查。修正了图集相邻格串图问题，运行时按 alpha 范围提取独立纹理。新纸页不再把白色编辑纸框生硬叠在旧纸上。
- `proof-page.html` 是独立测试存档的实际导出页，已在浏览器查看图文；内嵌 JSON 经过提取和引擎导入断言，`proof-recipe.json` 与最终纸页一致。没有上传玩家私人菜谱。
- 源码与 Windows 导出包各 headless 120 帧启动通过、退出 0，无脚本错误，见 `smoke-final.txt` 和 `export-smoke.txt`。Windows Release 导出退出 0；导出记录确认包含 3 张新 PNG、recipe_share、cleaning_cloth、pan_residue。EXE SHA-256：`63f06b57dbca784d295c5f77db359bc953812bd29252cce31a2932c15175af11`。
- 已启动最终 `AfterHoursKitchen.exe`，重新查询确认窗口标题“100饭店”、Responding=True（PID 11044），并从该导出包生产主场景抓取 `work/qa-cut-clean-share/live-export.png` 查看实际画面。抹布、菜谱及材料层入口正常显示。该图包含本机既有私人作品，只留本地；提交的截图均来自独立测试存档。
- 验证方式是 Godot 场景方法、引擎输入事件、GPU 实际帧以及浏览器页面；没有接管系统鼠标，没有宣称人工连续营业或逐条人耳试听。二维物理、有限残味标签与做法推断属于近似。

## 2026-09-25 追加番茄素材归档

核对 `df995921916e28abe9a9c7634fd6bc34.jpg` 为 RGB JPEG、1079 × 1527、白底；归档 SHA-256 为 `682335f386a407c78cd7141c0049c4e9c37c2f83cd019be4cb2eeba17cd0bea9`，与提供原件字节一致。去底生成候选因改变笔触未采用；未更新运行时清单、试玩包，也未将旧回归数写成本次验证。游戏替换尚待透明原图或程序去底方式确认。

## 2026-09-25 第二批素材：6 件奇物与柜层

- **当前范围**：本批 19 件中，后 6 张透明 PNG 已接入；前 13 张 RGB 黑底 JPEG 仅原样归档、尚未替换，等待透明原图或用户允许程序去黑底。完整映射与限制见 `HANDDRAWN_BATCH2_20260925.md`。
- 10 组定向回归 **998 项通过**：手绘接入 227、柜层与共享库存 260、调料 148、库存/体积/菜谱 25、布局 18、整批切块 42、切片烹饪 37、菜谱引导 40、DIY 75、完整流程 126。全目录 **97 张 alpha 审计 0 错误**。日志 `qa/20260925-batch2-assets.txt`、`20260925-batch2-pages.txt`、`20260925-batch2-regression.txt`。
- 原画校验覆盖 19 件已接入团队 PNG 的文件 SHA-256 和运行时区域像素一致；每件均从实体柜格拿取、变空、放回及再取，身份不变；牙膏与其他容器验证实际瓶口变换、出料量和来源身份。
- 柜层测试通过真实页面按钮的信号遍历全部普通与奇物，确认无遗漏/重复；测试拿走后跨页仍留空、不可见原位不能误收、回原位与食材柜再取仍为同一物体。测试由引擎场景与输入信号驱动，不冒充系统鼠标人工流程。
- GPU 手绘套件 **235 项通过**、柜层套件 **262 项通过**；RTX 4050 / OpenGL 实际渲染 `qa/20260925-batch2-*.png` 共 9 图。检查厨房陈列、两页原画总览、食材柜及第二层，修复了长名称/大质量数值与缩略图重叠，改为图文上下分区，并对柜格长名省略。原有蘑菇切片/热表面/摆盘/实际照片同时回归。
- 源码和导出 EXE 各通过 headless 120 帧启动，无脚本/缺失资源错误；日志 `20260925-batch2-smoke.txt` 与 `20260925-batch2-export-smoke.txt`。Windows release 导出退出码 0，更新原试玩路径；归档 JPEG 所在 docs 目录不进入发布包。
- 已重新打开导出版本“100饭店”（PID 38008，Responding=True），从生产主场景捕获并检查 `../../work/batch2-live-export.png`：新奇物与翻层入口在最终包内实际显示。该图含本机既有菜谱，仅保留本地，未上传；提交的 9 张 QA 图使用独立测试存档。
- 系统鼠标全流程、人耳音效、所有奇物的长时间组合未逐项人工验证。凸包支撑、热表面和牙膏整管形变仍为二维近似；卷纸展开、袜子软体、肥皂溶解起泡未实现，详见专项说明。

## 2026-09-25 用户手绘原图（13 件）

- 本轮 9 组定向测试共 **662 项通过**：手绘接入 151、调料操作 148、切片状态连续 37、整批切块 42、布局/清洁海绵 18、库存/体积/同源菜谱 25、菜谱引导 40、DIY 75、完整流程 126。另进行全目录 **94 张素材 alpha 检查，0 错误**。日志 `qa/20260925-handdrawn-tests.txt` 记录首轮，`qa/20260925-handdrawn-recheck.txt` 记录最终受影响复验；不累计重复测试数。
- 首轮完整流程失败是旧测试将奇物数量写死为 24；新增 6 件后，改为核对目录中的完整奇物名称集合与实际筛选结果，复验 126 项全过。未删除类别筛选检查。
- GPU 真正发现并修复两个显示问题：摆盘初次尺寸未就绪导致食物偏到左上角；凸包边线横跨手绘蘑菇的透明缝隙。增加初次布局后的盘内位置检查，切面边线按原画 alpha 限制。取空格默认禁用色块一并移除。
- RTX 4050 / OpenGL 执行 `tests/test_handdrawn_assets.gd`，**158 项通过**，保存厨房、出料、切片、摆盘、摄影、13 件总览共 6 图；逐张查看了实际画面。GPU 日志 `qa/20260925-handdrawn-gpu.txt`，图片 `qa/20260925-handdrawn-*.png`。柜格事件和生产操作方法驱动取物、拆分和装盘，热量由测试 `session.tick(8)` 推进；不是人工系统鼠标全流程。
- 源码与 Windows 导出版本各通过 headless 120 帧启动，退出码 0，无脚本/缺失资源错误。日志 `qa/20260925-handdrawn-smoke.txt`、`qa/20260925-handdrawn-export-smoke.txt`。Windows Release 导出成功，13 张图片资源及映射清单均在导出记录内。
- 已打开最终导出的“100饭店”窗口（PID 9560），保留运行供用户试玩。通过可选 `--preview-capture=绝对路径` 启动参数从该生产主场景读取当前 GPU 视口，查看本地 `../../work/handdrawn-live-export.png` 确认导出包里实际显示了新素材；该参数只截当前画面，不接管鼠标、不替换场景，不是只根据进程名称判定画面成功。此张含本机既有菜谱的截图仅留在本地；提交仓库的 6 张 QA 图使用独立测试存档。
- 接入范围、原作保护、版权及近似/缺失内容见 `HANDDRAWN_ASSETS_20260925.md`。奇物的材料行为、瓶身形变仍为简化；未制作开盖动画、毛线解缠或海绵孔隙模拟，未完成逐音效人耳验收。

## 2026-09-25 厨房手记与跟做

- 7 组定向回归 **514 项通过**：recipe guide 40、recipe DIY 75、stock/volume/shared recipe 25、collage GUI 68、paper recipe 30、recorded audio 150、integration 126。原始日志 `qa/20260925-recipe-tests.txt`。未把此前全部检查计入本次。
- 新测试通过引擎鼠标事件点跟做，再使用生产取物、切割、整批拖动、热量/吸水、摆盘方法检查完整链条。水量和水温由夹具设置，20 秒热量通过 session.tick 推进；没有声称手动完成接水和全程烹饪。
- 首次测试直接调用摆盘内部方法，未走实际入口的关火逻辑，故完成断言失败；改从 `_interact("plate")` 进入后通过。长标题测试确实发现面板被撑宽/撑高，修复为标题栏省略并保留右页完整换行，再复验通过。
- GPU 使用 RTX 4050 / OpenGL，检查目录、做法前后页、实际成品照片、底部引导、收班页、60 字菜名及 1152×681 小窗口，共 8 张 `qa/20260925-recipe-*.png`。实际照片来自生产摆盘/摄影代码，食材未换成预制成品图。
- 系统鼠标完整人工操作和逐音效人耳试听未验证。做法推断、宽松用量和过程图近似详见 `RECIPE_GUIDE_20260925.md`。
- 最终源码和导出 EXE 均通过 headless 120 帧启动，无脚本/素材错误；日志分别为 `qa/20260925-recipe-smoke.txt` 和 `qa/20260925-recipe-export-smoke.txt`。Windows release 导出退出码 0，已从原试玩路径打开最新“100饭店”窗口（PID 43228），直接展示厨房手记。启动状态不替代手工全流程验收。

日期：2026-09-11。环境：Windows、Godot 4.7.2 Standard、OpenGL Compatibility / NVIDIA RTX 4050。

本轮完整无窗口回归全部通过；实际鼠标事件由测试送入场景树，另运行 GPU 画面和照片检查。

| 测试入口 | 本轮结果 |
| --- | --- |
| test_collage_input | PASS: real collage GUI input, 68 checks |
| test_comfort_release | PASS comfort release: 90 checks |
| test_customer_reviews | PASS: customer reviews, 33 checks |
| test_free_pan | PASS free pan 9 checks |
| test_heat_control | PASS: heat controls, 23 checks |
| test_integration | PASS: restaurant integration, 125 checks |
| test_kitchen_interactions | PASS: kitchen interactions, 31 checks |
| test_knife_drag | PASS: real knife mouse drag, 20 checks |
| test_knife_physics | PASS: knife physics, 35 checks（含同批四块一次拖入锅） |
| test_recipe_diy | PASS: recipe DIY lifecycle, 75 checks |
| test_seasoning | PASS: seasoning input and physics, 148 checks（含瓶余量/溢出守恒） |
| test_spatula | PASS: spatula input and physics, 29 checks |
| test_tape_editing | PASS: tape editing, 75 checks |
| test_tape_tools | PASS: shared tape tools, 30 checks |
| test_domain | PASS: restaurant domain, 506 checks |
| smoke_test | STORAGE_AND_POSTER_TESTS_PASSED |
| poster_store_test | POSTER_PERSISTENCE_AND_WALL_TESTS_PASSED |
| collage_test | ADVANCED_COLLAGE_TESTS_PASSED checks=39 |
| paper_recipe_test | PAPER_RECIPE_TESTS_PASSED checks=30 |
| test_workstations | PASS workstations 17 checks |
| test_high_fidelity_state | PASS: high-fidelity state slice, 15 checks |
| capture_asset_gallery | 88 种素材全部有纹理，底色检查 0 错误；明暗背景逐项目视检查 |

## 本轮修复和验证重点

- 松手、界面上松手、失焦、打开编辑器均停止工具跟随和调料释放。
- 菜板直接切割真实刚体，切块质量守恒；没有放大菜板入口。
- 同一原料切出的碎块共享批次标识；抓住其中一块可整批拖入锅，四块仍分别登记物理 ID、质量、几何和受热状态。
- 拖锅的抓取偏移按美术比例换算；抬锅带着食物，倾倒后原食物实际落盘。
- 修复装盘后回锅的位置同步，保存火候和唯一实体身份；避免重复入账或丢失食材。
- 速度、旋转和翻炒冲量受限，连续放料后物体稳定停留在工作台；这不是对所有未测试情境的零故障承诺。
- 三把厨具均通过拿取和松手检查；锅、盘、刀、水槽、炉火、调料经过对应状态验证。
- 酱汁使用 ml、组分和来源批次；锅满溢出也扣减同一容器余量。混色是标明的加权 sRGB 视觉近似。
- 新顾客会从已保存且实际含食材的 DIY 菜谱中点单，含鱼的旧菜谱不进入订单池；餐前/餐后心情显示实际钳制后的变化量。
- 奇物箱九件一轮不重复，跨轮不连续重复，拿着物体再次点击不消耗库存。
- 等餐 120 秒，评分 19/20/80/81 等边界的餐费、赔偿与小费通过检查；焦香爱好者评分与普通客人有明显区别。
- 独立底部说明区和互斥提示；重新绘制的独立素材在厨房、切块、摆盘照片和 DIY 画纸中保持统一。
- 高、中、低火均在锅底绘制可见的橙黄火舌与蓝色气焰；画面捕获已检查火焰处于锅后、炉口前的正确遮挡关系。
- 水槽增加独立的槽壁和槽底物理边界，落入槽内的完整食材不会停在台面前沿或穿出；专项舒适性检查新增真实落槽断言。
- 水龙头移除上方重复把手，只保留下方可拖转把手；转动量继续同时控制水流、水量和水声。
- 每位顾客的聊天扩展为当天经历、往事、当下感受、习惯、口味和实际菜谱订单六轮，六轮不重复。
- 面条在水量不少于 80 ml 且水温达到 85°C 后连续吸水；接近沸点时逐渐散开、变软并扩大碰撞轮廓，冷水停止软化。渲染画面与专项状态检查已通过。

## 导出与接入

Windows exe 已于 2026-09-09 18:16 重新导出，导出命令退出码 0；随后启动可见窗口，进程 8128，窗口标题「100饭店」，`Responding=True`。导出包显式包含图集 JSON 边界数据；素材数据库仍有 88 项，其中鱼和三文鱼不会进入当前取材或点单池。

源码 ZIP 需连同全部模块资源交付，排除 .godot 缓存和私人参考截图。接入真实主游戏、在线共享、Linux CI 还没有执行，不能视作本轮已验证范围。声音为合成拟音，触发与停止经过测试，不宣称实录音色。

源码包已解压到新的 work/clean_handoff_check_* 目录，首次导入无错误，独立运行 test_comfort_release.gd 的 89 项检查通过。当前 Windows 试玩窗口已使用导出的程序启动。

后续物理补充：木勺启用三段勺沿碰撞，轻移时刚体食物随勺承托，滚轮倾斜越过勺沿后恢复重力；渲染顺序为勺底、食物、前缘。翻炒声按四种食材材质选择。水龙头单击不会出水，拖动可见把手越过阈值才开始注水，回转后水量和水声同时停止。

## 2026-09-11 回归结果

- `tools/test.ps1` 退出码 0。19 个带计数套件合计 1424 项断言通过，另有存储与海报烟雾测试通过。
- 新增 `test_cut_batch_stability.gd`：40 项通过，覆盖可拖动菜板、板上食材同步、动态切割边界、8 个同源切块一次入锅、锅内稳定和水满溢出。
- `test_kitchen_interactions.gd`：32 项通过，新增验证满锅继续接水产生溢出量；沸腾循环、单把手水龙头、拖锅和锅内状态保持继续通过。
- `test_domain.gd`：506 项通过。容量仍限制 6 种来源食材，但一个来源切出的最多 48 个物理块不会被误判为多种食材。
- `capture_asset_gallery.gd`：88 张素材，透明底审计 0 错误。
- GPU 捕获并人工检查：`work/med-kitchen-v2.png`、`work/cut-batch-fixed.png`、`work/plating-photo-actions.png`、`work/customer-feedback-paper.png`、`work/recipe-workbench.png`。未见切块飞出锅、透明棋盘底、重复水龙头把手或锅沿/水面的反向遮挡。
- `plating-photo-actions.png` 中两个拍照入口均显示；照片画面包含当前实际摆盘的番茄、鸡蛋、蘑菇、西兰花和酱汁，不使用预制成品图。
- `customer-feedback-paper.png` 中纸面头像、具体反馈、鼓励、心情变化、结算、回复输入和保存入口均正常显示。

真实音频的来源品质没有通过现场录音素材验收；当前验证只覆盖播放条件、循环互斥和停止行为。二维溢水及锅内块体重叠属于明确记录的稳定性近似。

Windows 试玩版于 2026-09-11 00:42 导出，导出命令退出码 0；测试和文档目录已从发行包排除。随后启动进程 8704，窗口标题“100饭店”，`Responding=True`。

## 2026-09-12 缺陷审计与修复回归

- 完整 `tools/test.ps1` 退出码 0：20 个带计数套件共 1442 项断言通过，存储、海报与 88 项素材透明底审计也通过。高拟真状态测试现已纳入默认完整测试入口。
- 未装盘直接出餐的捷径已移除；集成测试确认锅内料理不能绕过实际装盘，装盘后才可结算。
- 摆盘页按 `batch_uid` 合并同一次切出的碎块，并提供“全部装盘”；玩家不再需要逐块点击大量切片。
- 锅倾斜超过锅沿时水量从锅中扣除；水槽上方进入下水，其他位置生成有来源、有体积且可擦除的水渍。清理工作台和下水操作会清除相应残余溢水状态。
- 菜谱食材记录上限从 24 个物理块调整为与厨房一致的 48 个；48 项保存、重载和导入通过，49 项仍被拒绝。
- DIY 工具栏不再把整间厨房的视口截图伪装成菜品照片；没有有效摆盘照片时会明确引导回装盘台。
- GPU 捕获 `work/audit_plating.png` 已检查：批量装盘入口、实际四种食材、盘内酱线、照片动作和弹窗边界均正常，无透明棋盘底。
- 仍未完成：完整厨房的 WASD 位置/距离系统、有限库存与补货、连续二维流体分布、实地录音拟音。这些属于明确的规格缺口，不计入已完成缺陷修复。

## 2026-09-25 最新参考图交付

- 完整 `tools/test.ps1` 25 个脚本全部通过，22 个计数套件共 1498 项断言；另有存储/海报无计数检查与 88 项素材 alpha 审计（0 错误）。记录：`qa/20260925-tests.txt`。
- 此后快速取材改用实际鼠标按下事件坐标，避免读取已移动的系统指针；受影响的 integration（126）及 kitchen interactions（33）重新通过。最终 comfort release（90）也再次通过；全新发布目录完成 --import、启动和这三个套件，记录见 qa/20260925-clean-copy.txt。
- GPU `capture_cooking_states.gd` 的三类食材四种火候，共 9 组相邻图像比较通过；人工检查真实渲染结果。不是只检查材质参数。
- GPU 主厨房截图检查原位调料台、五格备料格、竖放厨具、菜谱架、槽体与固定炉灶；空锅画面不残留背景锅或刀。
- `--headless --path . --quit-after 120` 通过。Windows release 导出退出码 0，已启动窗口“100饭店”（PID 11092，Responding=True）；这只证明启动响应，不替代最终系统鼠标全流程验证。远程提交状态由交付消息确认。
- 用户通过 Esc 中止系统鼠标控制后未继续调用电脑控制工具。最终布局仍缺系统鼠标全流程复验；引擎输入、物理/状态回归及 GPU 绘制已验证。
- 仍不是完整现实仿真，音频仍是合成拟音；具体模型与缺失录音见 `REFERENCE_KITCHEN_20260925.md`。

## 2026-09-25 柜格、菜谱与锅容量纠正

- 26 个脚本分段回归通过，23 个带计数套件共 1524 项断言；另外存储/海报无计数检查与 88 张素材 alpha 审计 0 错误。
- 原始三段日志保留在 qa/20260925-stock-tests-first.txt、qa/20260925-stock-tests-middle.txt、qa/20260925-stock-tests-last.txt。前两段包含旧测试夹具失败：菜谱视图从模态里的独立画布迁移为内外共用画布；库存改为一件；满锅改为真实容量后，移动锅的出料测试先排水再验证接料。相应断言更新后通过，未把旧失败隐藏或当成通过。
- 新的 test_stock_volume_recipe.gd 25 项通过；真实引擎鼠标取物/切配 comfort 90 项，持续按压调料 148 项，厨房取放/移动锅 34 项，DIY 存档与继续编辑 75 项通过。底层刀切、热量、勺铲、照片、菜谱存档和纸面编辑回归也通过。
- 已检查四张 GPU 实际渲染截图：qa/20260925-stock.png、20260925-book.png、20260925-small-sauce.png、20260925-full-pan.png。分别展示柜格留空、共用菜谱扉页、10 ml 小量不溢出、总量超过 1500 ml 后只溢出超量部分。截图中的满锅水量由测试设置，出酱和溢出经过实际生产代码。
- headless 启动无脚本错误，记录 qa/20260925-stock-smoke.txt；Windows release 导出退出码 0，已启动“100饭店”（PID 38988，Responding=True）。未进行系统鼠标下的完整人工操作验收。
- 容积/密度/流体仍是明确记录的二维近似；跨班库存存档、采购补货和实录音频尚未实现。详见 STOCK_RECIPE_PAN_20260925.md。

## 2026-09-25 固定菜板回归

- 菜板空白处向锅内拖拽的引擎鼠标事件不再移动菜板、切割区域或板上的食材；移除了整个菜板拖动入口及旧操作提示。
- `test_cut_batch_stability.gd` 42 项、`test_knife_drag.gd` 20 项、`test_slice_cooking_continuity.gd` 37 项、`test_integration.gd` 126 项，共 225 项通过。覆盖菜板固定、刀刃实际切割、8 块同源食材一次入锅、切片烹饪与装盘连续性。日志：`qa/20260925-fixed-board-tests.txt`。
- `--headless --path . --quit-after 120` 通过，无脚本错误。此次执行上述定向回归，没有将旧版本的全套结果计入本次。
- 运行 GPU 捕获并检查 `qa/20260925-fixed-board.png`：切块在锅内，菜板保持右侧备菜区位置。截图通过生产切割及入锅代码布置，不代表系统鼠标手工试玩。
- Windows release 导出退出码 0，更新了原试玩路径。系统鼠标完整人工流程本次尚未验证。

## 2026-09-25 实录音效回归

- 下载/授权：35 个源页面逐条核对 CC0；49 个剪辑文件均有来源、加工区间与 SHA-256。`tools/audit_recorded_audio.py` 通过，输出 `qa/20260925-audio-asset-audit.json`；检查解码、非静音、幅度、循环边界与哈希。删除旧生成 WAV 与生成脚本。
- 定向引擎回归：recorded audio 150、kitchen interactions 35、spatula 29、seasoning 148、knife drag 20、recipe DIY 75、comfort release 90、integration 126，共 **773 项通过**。日志 `qa/20260925-recorded-audio-tests.txt`。旧测试“干米在无油锅中必响滋滋声”已改为不制造湿煎声；新套件分别验证有油、含酱、冷水、沸水、空瓶、工具类别、密集接触、暂停/失焦/静音。
- 新测试首次在旧实现上因缺少录音库接口失败；接入后初次夹具未等待父节点帧同步，世界仍未开火，七项状态断言失败。改为等待实际状态同步后通过；没有通过放宽声音条件掩盖失败。
- 真实 GPU/WASAPI 引擎混音捕获 `qa/20260925-kitchen-audio-preview.wav`，34.752 秒，48 kHz 双声道；配套 `.wav.json` 标注各段。脚本布置实际厨房状态，使用生产播放器和引擎音频总线，未用静态拼接冒充运行音频。
- 混音审计 `qa/20260925-audio-mix-audit.json`：15 段声音非静音，最大绝对幅度 0.158844（未削波），最后静音段 RMS=0。数值审计不代表人耳认可音色；逐素材人工听感与系统鼠标完整试玩尚未完成。
- 已知近似与素材缺口详见 AUDIO.md：采集到的是公开压缩版本；部分工具/肉类材质借用相近的真实录音；没有声称完成逐食材声学仿真。
- 最终源码 headless 120 帧启动无脚本错误；Windows release 导出退出码 0，导出的 EXE 再以 headless 120 帧启动退出码 0、无缺失素材错误。随后已打开最新可玩窗口“100饭店”。这证明打包和启动，不代替系统鼠标及人耳完整验收。
