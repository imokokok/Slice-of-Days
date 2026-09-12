# Town Sound v0.4 / 小镇声景采样与几何构图

现在已经接入 Solmere 主游戏，打开仓库根目录的 project.godot。

## 玩家流程

- 小镇右上角的录音图标默认采集游戏声音：当前地点的背景声及环境互动音效。按 REC 后可「收起面板 · 边逛边录」，停止时展开并命名保存。
- 真实人声是可选声源，主动选择「真实人声」后才使用麦克风。游戏采样不需要麦克风，也不会采集桌面其他应用的声音。
- 「听听身边」触发地点对应的杯碟、翻页或木面短音；移动触发脚步。声景为本地程序合成的游戏音效，不冒充现实录音。
- 相机图标为游戏内场景取景；相册图标查看本地照片。
- 相机支持放大与左右、上下构图。快门保存 PNG 和地点/日期信息，不开启电脑摄像头，不上传。
- 录完后选择街区中的「唱片店」，通过步行等方式真正抵达，再点「进入唱片店工作台」。在其他地点不能打开 Studio。
- 唱片店可进入四轨编曲、任意选区剪辑、Visual、手作唱片流程和本地唱片架。
- 封面步骤可选「程序画面」或「从本地相册选封面」，照片复制为成品封面，原相册照片不变。

## 可视化

以不等大的圆、长三角、斜向线、开放弧线与小型棋盘格组织构图，保留负空间。低频驱动圆的重量与呼吸，中频驱动线面张力，高频驱动细小节奏；同种子可复现，暂停保持当前画面。灵感参考：[古根海姆《Composition 8》资料](https://www.guggenheim-bilbao.eus/en/learn/schools/teachers-guides/composition-8)。采用程序绘制原创构图，不下载画作。

## 唯一源码位置

- scripts/town_sound/：录音、编曲、相机、相册、唱片制作运行代码。
- scenes/town_sound/Recorder.tscn：录音/唱片店面板。
- tests/town_sound/：自动测试。
- scripts/ui/town_day.gd：右上角工具入口及唱片店地点限制。

当前 prototypes/town-sound/ 仅存放说明、历史测试报告和推送脚本，不再包含第二份运行代码或 project.godot。v0.2 独立版保留在 Git 历史中。

## 本地存储与去重

存储于 Godot user://（Windows 默认 %APPDATA%/Godot/app_userdata/Solmere/）。samples 是录音，projects 是编曲工程，records 是成品，photos 是相册。照片按像素内容哈希去重，重复按同一取景快门不会产生第二张；同一界面不能重复打开录音面板。

从旧 Town Sound 独立应用迁移时，首次打开录音面板会复制 samples、projects、records。已有目标文件不覆盖，原目录不删除；成功后记录迁移标记。A/B 角色共享本机素材相册，授权费账本保留为唱片系统自己的余额，没有重复汇入主剧情钱包。

## 测试

从仓库根目录运行（Godot 4.7.2）：

```shell
godot --headless --editor --import --quit
godot --headless --script res://tests/town_sound/test_recorder.gd
godot --headless --script res://tests/town_sound/test_arrangement.gd
godot --headless --script res://tests/town_sound/test_audio_settings.gd
godot --headless --audio-driver WASAPI --script res://tests/town_sound/test_world_capture.gd
godot --headless --script res://tests/town_sound/test_project_validation.gd
godot --script res://tests/town_sound/test_visual_composition.gd
godot --script res://tests/town_sound/test_pocket_media.gd
godot --script res://tests/town_sound/test_flow.gd
godot --script res://tests/town_sound/test_flow.gd -- --photo-cover
godot --headless res://scenes/system_smoke_test.tscn
```

拍照和封面测试需要真实渲染器；测试照片、成品放到独立 user://tests/ 下，不进入玩家相册。

## 已知边界

游戏音频通道实录已通过：非静音 PCM、本地重载一致、排除试听串音、停止/退出清理。旧「月亮」录音是全静音，不能恢复其中不存在的声音。可选真实人声仍需用户对着物理麦克风试录确认。相机拍的是游戏场景，不是真实世界摄像头。素材与相册是本机共享，未做云同步。公共唱片库尚未部署；包装仍是程序化 2D 手作表现。

后续提交推送见 GIT_WORKFLOW.md。