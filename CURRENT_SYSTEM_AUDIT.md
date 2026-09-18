# V3 工程审计 · 2026-09-17

运行环境：Godot 4.7.2 stable，OpenGL Compatibility，1600×900；正常入口为 `scenes/main_menu.tscn`。审计基于当前工作树及真实场景验收，不以文件存在代替运行结果。

| 系统 | V3 开始时状态 | 实际调用链 / 缺口 |
|---|---|---|
| Time / Money / Save | REAL_IMPLEMENTATION | GameState 推进分钟、余额和账本，SaveManager 原子保存；保留 |
| 横版移动 | REAL_IMPLEMENTATION | WalkStage A/D；已修复录音挡走动与 Tab 焦点吞键 |
| NPC / Dialogue | REAL_IMPLEMENTATION | TownDay / InteractiveSpace → DialogueSystem → ConversationPanel；摊主及争吵后两人测试通过 |
| 地图 | PARTIAL_IMPLEMENTATION | Tab → PaperOverlay → TravelSystem → SceneRouter → SaveManager；步行/打车/到达已验证，V3 还需 ETA、机会、捷径 |
| 六份文件 / Portfolio | REAL_IMPLEMENTATION | 新游戏 → 社区柜台 → 领取 → F 六份纸张 → 七页；读档与防重复已验证 |
| Residency 硬要求 | PARTIAL_IMPLEMENTATION | V3 新增收据数量/用途、四圈认可、三种探索与贡献放置门槛 |
| 采购 / 报销 | MISSING | 现有库存与真实扣款可复用；缺 line_items、报销状态及厨房交货链 |
| Camera / Gallery | PARTIAL_IMPLEMENTATION | 真实 PNG 捕获与角色隔离已工作；缺 24 张胶卷、冲洗、领片 |
| Recorder | REAL_IMPLEMENTATION | TownWorld 真音频 → WAV → Field Book / 音乐；移动与标记验收通过 |
| Inner Voices | PARTIAL_IMPLEMENTATION | 真实 dialogue_line_presented → 候选 → 可见 UI、持久冷却已验证；V3 需五个正式必现点 |
| Marginalia / Living Town | REAL_IMPLEMENTATION | 地点资格判断、分波旁注、日程与有限离线状态；继续回归再访行为 |
| 每日引导 | MISSING | 缺常驻单条 NEXT、Today Must / Opportunities、行动前成本预览 |
| 3D Memory / 原有小游戏 | REAL_IMPLEMENTATION | 保留既有第一人称记忆与结尾；新增资源链需回归原入口 |
| 98 位真实参与者内容 | PARTIAL_IMPLEMENTATION | coverage 可检查；真实投稿缺项保留在 MISSING_CONTENT.md，不虚构身份 |

补实现基线：`test_patch_travel`、`test_patch_residency`、`test_patch_npcs`、`test_patch_voices` 均通过。V3 新增项以最终 TEST_RESULTS.md 为准。
