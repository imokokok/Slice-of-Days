# 全局声音采集 · 2026-09-26

本系统已经接入根目录的 Solmere 主游戏，源码只有一份。右侧口袋录音机贯穿街区、室内、原生小游戏和扩展小游戏。A、B 都可使用录音，B 仍保留自己的手账与日程；各自录音按角色隔离。主菜单、结局、过场不显示采集入口。

## 玩家操作

1. 点右侧磁带图标，按圆键开始录音。默认收集游戏的环境、背景、脚步和实际互动音效；需要人声时再选择麦克风。
2. 收进口袋继续走路、进屋或做饭。右侧仍显示计时、实时像素画面和停止保存键。单段最多 60 秒，到时自动保存。
3. 再按圆键或右侧保存键，声音直接进入本地收藏。可试听、起名、搜索，按今天/地点筛选和回放 MV。
4. 进入唱片店的声音手作桌，拖动选择区段剪辑、调音量、变速；接着选系统封面或本地照片，命名、压片、装内袋/纸套/透明外袋，最后竖放到唱片架。

小游戏中的实体声音（下锅、翻拌、洗切、翻纸牌、拼贴纸张等）进入 TownWorldSoundEffects，环境与世界配乐进入 TownWorldMusic。界面按钮、录音试听和唱片制作反馈留在监听通道，避免录进自己刚才的试听。像素 MV 的类型来自实际动作事件，波形频谱控制运动强弱；不会靠播放额外素材来伪装“录到现场”。

## 本地恢复与协作

RecordingSession 是唯一音频采集会话；GlobalRecorder 是全局入口；RecorderScreen 只作为唱片店宿主。收起和更换场景不会销毁采集器。

录制期间约每 5 秒保留恢复草稿；正常停止立刻保存，失败则保留原始 WAV 和稳定编号，重试不重复写入。意外退出通常能恢复最近的检查点（最后不足 5 秒可能丢失）。主菜单/结束旅程/关闭窗口先尝试保存，保存失败会留在可重试界面。角色与旅程分别保存。改名/删除遇到主存档失败会回滚，已被声音工程或作品使用的录音受保护。录音容量从 20 段扩到 256 段；每段仍限制 60 秒。

Windows 数据目录：`%APPDATA%/Solmere_Playable_Meta`。录音、照片与个人存档不进 Git。`prototypes/town-sound/Push-TownSound.ps1` 支持本轮全局接口、依赖和测试文件；普通 fetch/rebase/push，不使用强制推送。

## 筛选参考与实际复用

| 来源 | 采纳内容 | 许可 / 范围 |
|---|---|---|
| [SEASON 官方](https://www.play-season.com/) | 将拍摄、录音和记忆收集留在探索路线上，采集后回收藏整理 | 玩法参考，不复制商业美术 |
| [TOEM 官方商品页](https://store.steampowered.com/app/1307580/TOEM/) | 随身工具、明确任务和地点收藏的连续操作 | 玩法参考，不导入其角色、画面或音轨 |
| [Lucide](https://github.com/lucide-icons/lucide) | 实际接入磁带、声音、麦克风、剪刀、地点和播放六个 2D 线描图标 | ISC / Feather MIT；完整许可在 third_party/licenses/lucide/LICENSE。固定提交 66d8f9fc394b8530377e5f6112f0b8908ba01280；仅将 currentColor 改为统一棕墨色 |
| [Godot Sound Manager / Nathan Hoad](https://github.com/nathanhoad/godot_sound_manager) | 实际改编播放器的获取、回收和复用，加入 12 路上限、尾部淡出与世界音频路由 | MIT；完整许可在 third_party/licenses/godot_sound_manager/LICENSE。固定提交 1c041582db806a0d0edad77111d1fb7a009346ef |
| [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio)、[Impact Sounds](https://kenney.nl/assets/impact-sounds) | 复用仓库已有 CC0 翻纸、锅和木击音，挂接到真实互动；火焰等来源见 art/town_sound_cc0/SOURCES.md | CC0，保留逐文件来源与摘要；未重复下载同一资源 |
| [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | 评估后保留现有轻提示音，避免叠加另一套按钮声音 | 候选，未安装 |
| [Sonniss GDC](https://sonniss.com/gdc-bundle-license/) | 音效候选；原始素材再分发限制不适合本次公开源码素材目录 | 未下载、未纳入 |

保持原有场景、角色和厨房美术；不混入 3D 或写实照片风格资源。新增资源均在下表明确许可，不将整个项目的历史素材统称为可自由再分发。

## 回归入口

使用 Godot 4.7.2，仓库根目录执行，实际音频测试必须使用桌面音频驱动：

```
godot --path . --script res://tests/integration/test_global_recording.gd -- --isolated-save
godot --path . --script res://tests/integration/test_recorder_movement.gd -- --isolated-save
godot --path . --script res://tests/integration/test_recording_retry.gd -- --isolated-save
godot --path . --script res://tests/town_sound/test_sound_desk.gd -- --isolated-save
godot --path . --script res://tests/town_sound/test_flow.gd -- --isolated-save
godot --path . --script res://tests/town_sound/test_packaging.gd -- --isolated-save
```

全局回归覆盖真实进门换景、非静音 PCM、同步 MV、界面/试听隔离、复音回收、断点恢复、重复提交防护、失败回滚、超过 20 段收藏、实际做饭火声、取消活动保留录音。麦克风权限拒绝走既有错误提示；本轮不把机器上的自动音频测试当作真人说话验收。MV 仍是本地同步绘制，不导出视频。
