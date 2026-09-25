# Town Sound / 小镇声音与唱片制作

已接入 Solmere 主游戏，请打开仓库根目录 `project.godot`。

当前全局录音、统一收藏、跨场景恢复和资源接入见 [全局录音说明](GLOBAL_RECORDING.md)。

完整操作、参考游戏、素材许可与测试说明见 [本轮版本说明](RELEASE_20260926.md)。

- 实际随身工具栏的录音工具：`scripts/residency/recorder_lite.gd`。
- 唱片店入口：`scripts/town_sound/record_shop/RecordShop.gd`；工作台和本地唱片架均可进入。
- 录音、编曲、照片封面、像素 MV 与压片代码：`scripts/town_sound/`。
- 本地收藏详情：`scripts/residency/paper_overlay.gd`；保存声音可连同 MV 回放。
- 素材授权：`art/town_sound_cc0/SOURCES.md`；没有复制商业参考游戏素材。
- 保存位置：Windows `%APPDATA%/Solmere_Playable_Meta`，录音按当前旅程/角色筛选。主存档控制唱片交付与收入去重。
- `prototypes/town-sound` 仅放文档和推送脚本，没有第二份游戏源码。

默认录游戏声音，真实麦克风须主动选择。去不同地点采集，再到唱片店编排、选封面、制作与入库。唱片制作沿用主游戏的时间及角色规则，声音委托根据实际成品自动验收。

后续修改推送见 [GIT_WORKFLOW.md](GIT_WORKFLOW.md)。公共联网唱片库未配置时保持本地模式；MV 为同步渲染，不导出视频文件。

唱片包装结构与真实拖动修订见 [PACKAGING_V2.md](PACKAGING_V2.md)。

明亮的声音手作桌、常驻 MV、基础剪辑与逐步引导见 [SOUND_SCRAPBOOK_UI.md](SOUND_SCRAPBOOK_UI.md)。
