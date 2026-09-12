# 验证记录

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
