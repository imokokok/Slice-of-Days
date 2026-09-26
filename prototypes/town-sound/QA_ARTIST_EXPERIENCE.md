# 声音创作者体验验证 · 2026-09-26

环境：Windows、Godot 4.7.2、NVIDIA OpenGL Compatibility、实际桌面音频驱动。测试顺序运行并传入 `--isolated-save`，不会覆盖正式旅程。

## 已通过的回归

| 测试脚本 | 本轮结果与覆盖 |
|---|---|
| tests/town_sound/test_sound_poetry.gd | 23 项 / 0 失败：10 种实际渲染图像各不相同、时间动画、回退帧一致、不同录音构图、静音静止、单双声道一致、源时间/事件/seed、裁剪与变速、不计已剪掉的委托声源、1024/1280/1600 内容宽度 |
| tests/integration/test_global_recording.gd | 37 项 / 0 失败：跨场景真实 PCM、游戏音源、试听隔离、持久会话、稳定 ID、草稿与事务、实际厨房火焰事件 |
| tests/integration/test_pocket_roles.gd | 48 项 / 0 失败：A/B 录音、B 手账、角色切换与保存恢复 |
| tests/integration/test_ui_reference_review.gd | 16 项 / 0 失败：录音、现场 MV、收起继续录、保存试听、命名去重、声音收藏及已有档案入口 |
| tests/integration/test_recording_retry.gd | 通过：保存失败仍可重试，录音不重复 |
| tests/town_sound/test_recorder.gd | 通过：游戏音源默认、PCM 文件和异常数据处理；麦克风错误路径 |
| tests/town_sound/test_arrangement.gd | 通过：波形片段移动、修边、循环和音频编排 |
| tests/town_sound/test_sound_desk.gd | 通过：无中间 motion 事件的快速拖选、剪掉中段、撤销、音量、变速和制作入口 |
| tests/town_sound/test_music_journey.gd | 通过：实际火/风声音事件、采集到成品的委托验收 |
| tests/town_sound/test_pocket_media.gd | 通过：相机购买、快门去重、冲洗取片、相册和封面来源 |
| tests/town_sound/test_packaging.gd | 通过：不同操作手势、包装前后片遮挡与最终姿态 |
| tests/town_sound/test_flow.gd --photo-cover --save-retry | 通过：长标题、照片封面、失败重试、三层包装、命名/书脊、竖立入架、成品音频及可见 MV、暂停同步 |
| tests/town_sound/test_visual_composition.gd | 通过：保留旧几何构图兼容路径 |

## 实际窗口检查

使用 Windows 原生鼠标在 1280×720 游戏窗口检查。声音手作桌快速拖出 1.1–2.4 秒范围，剪掉后显示两个保留片段，撤销恢复；修复之前快速拖动未收到中间 motion 事件导致范围坍缩的问题。店内三个物件入口与纸片引导可以完整显示。包装完成时，玩家唱片以与相邻唱片等高、同基线的窄书脊入架；点击书脊展开实际命名封套，封面位于透明膜下。测试截图也覆盖内袋、纸套、外袋与封口阶段。

图像回归发现并修复了小尺寸星形及火焰轮廓在像素取整后出现的多边形三角化错误。现场和回放改为同一 PCM 分析，避免现场画面增益重复放大。唱片架改为左右分区，长列表不再把 MV 推出屏幕，播放画面保持 16:9，长标题与底部提示有显示边界。

成品唱片架还完成实际鼠标检查：在保存后的唱片上继续播放，进度与画面前进；点击进度条后画面定位，播完后可再次播放。1280×720 下封面、纸页、播放按钮和 MV 均在窗口内。

## 复现与交付

从仓库根目录，用 Godot 4.7.2 运行上表脚本：`Godot --path . --script <测试路径> -- --isolated-save`。音频及 GPU 图像测试应使用可渲染、有音频驱动的窗口，不能用 Dummy 音频替代音频验收。完整流程的 `--manual-sleeve` 和 `--manual-shelf` 可保留最终窗口供检查；图像测试的 `--manual` 可保留唱片店窗口。

推送后会对 main 再运行关键回归；可玩包内 `VALIDATION.md` 和 `BUILD.json` 记录最终提交、远端核验、导出资源检查和复测结果。完整需求及商业许可取舍见 [ARTIST_EXPERIENCE_REVIEW.md](ARTIST_EXPERIENCE_REVIEW.md)。

以上验证有明确范围，不代表整个项目在所有设备上无缺陷。真人麦克风说话、未配置的公网唱片服务、其他操作系统和长期存档压力尚未作为本轮通过项。
