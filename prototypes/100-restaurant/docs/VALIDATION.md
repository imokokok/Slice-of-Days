# 验证记录

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
