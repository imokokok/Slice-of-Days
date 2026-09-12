> 仓库源码版请先阅读 README.md。此目录不附便携引擎，原型开发记录中提到的便携启动脚本不随源码提交。

# 夜海观景台原型

这是按需求文档实现的 Godot 4.x 第一版原型：2D 海边观景台、照片轮播，以及通过观察角度拼出飞鸟和鲸鱼的独立 3D 星空。观景台已换成用户提供的 JPG 场景原图；照片占位图、音效和星图轮廓均可继续替换。

## 运行与操作

解压完整包后，双击 `Observatory/Start.cmd`。包内附 Godot 4.5.2 Windows x64 运行环境，无需安装。首次启动会先导入资源，稍等数秒。双击 `OpenEditor.cmd` 可编辑项目；已有 Godot 时也可以导入本目录的 `project.godot`，按 F6 运行单场景，按 F5 运行完整项目。

- 点击右侧黄铜望远镜进入星空。
- 默认低动态模式：按住鼠标左键缓慢微调，松手即停，焦距锁定；关键星点不可拖动。
- 飞鸟提示为两只鸟朝中央亮星飞。靠近正确投影时旋转稍慢、星点稍亮，停留约 1.25 秒即可发现。
- 发现后可以拍照收藏，再点击“寻找鲸鱼”。鲸鱼发现后可继续安静观赏，也可重访飞鸟。
- “观测册”显示收藏数量，点击打开本机照片文件夹。
- ESC 或左上角按钮返回海边。轮播和海浪持续运行，发现与收藏状态保留。

开发时如需要快速定位：飞鸟参考 yaw=-0.16、pitch=0.08；鲸鱼 yaw=0.20、pitch=-0.07，单位为弧度。这只是编辑参考数据，正式判定仍使用屏幕投影误差。玩家界面不展示答案或调试数值。

## 素材替换

所有 `res://` 路径相对于本项目文件夹。

| 内容 | 具体位置及操作 |
| --- | --- |
| 2D 正式背景 | 在 `scenes/ObservatoryDeck.tscn` 选中 `ObservationDeckArt`，替换 Texture。当前为 AI 清晰度增强版 `assets/background/observatory_scene_hd.png`，尺寸 1961×802；原图 `observatory_scene.jpg` 保留备用。替换其他比例的图片时同步调整场景根节点的 `artwork_size`。背景等比铺满 16:9，裁切宽图两侧，偏右取景保留幕布和望远镜；幕布和热点跟随同一画布。根节点 crop_alignment 可调整取景位置。 |
| 幕布位置 | 同一场景的 `PhotoScreen`，通过 anchors 调整相对位置与范围。无需修改背景图尺寸相关代码。 |
| 望远镜点击区域 | 同一场景的 `TelescopeHotspot`，调整 anchors 匹配正式美术。 |
| 轮播照片 | 将 JPG、JPEG 或 PNG 放入 `assets/slideshow/`，重新启动或在 Godot 中重新运行，自动扫描。默认文件名排序；支持空文件夹、单张、多张。 |
| 轮播参数 | `PhotoScreen` Inspector：`hold_seconds=5`、`fade_seconds=1`、`random_order=false`。图片等比放大裁切，不拉伸。 |
| 海浪音效 | `assets/audio/soft_waves.ogg`；不存在时自动使用 `soft_waves_placeholder.wav`。两者均缺失时保持静音继续运行。 |
| 望远镜声音 | `assets/audio/telescope_click.ogg`；缺失则使用轻声占位音。 |
| 发现音效 | `assets/audio/constellation_found.ogg`；缺失则使用 `chime_placeholder.wav`。 |
| 飞鸟 / 鲸鱼星图 | `resources/bird_constellation.tres`、`resources/whale_constellation.tres`；可编辑模板、三维坐标、大小、主星、临时连线、参考角度和判定参数。 |
| UI | `scenes/StarGazing3D.tscn` 的 `UI` 和观景台场景内标签、按钮；`assets/ui/` 预留正式图形。 |

照片目录已加入用户提供的两张照片：`01_seaside.jpg`（海边日光）和 `02_night_towers.jpg`（夜间尖塔），按此顺序循环播放。可以继续加入自己的照片。空目录保留原图中的幕布内容；放入照片后以斜边映射覆盖幕布，正式照片无需更改脚本。运行过程中加入新照片需要重新启动，当前版本不实时监听目录变化。此交付是源工程加便携引擎；若之后导出 PCK，要在导出设置中保留轮播目录的原始 JPG/PNG 文件，或改用外部照片目录。

## 文件职责

| 文件 | 职责 |
| --- | --- |
| `project.godot` | 主场景、自动加载、1920×1080 设计分辨率、1536×864 默认窗口与等比例适配、兼容渲染器。 |
| `scenes/Main.tscn` / `scripts/main.gd` | 维持 2D 场景常驻，管理独立 3D 场景和 0.8 秒黑场淡入淡出，正常退出时保存和停止音频。 |
| `scenes/ObservatoryDeck.tscn` / `scripts/observatory_deck.gd` | 2D 背景、幕布、入口与文字；不包含星图判定。 |
| `scripts/slideshow_controller.gd` | 扫描图片、排序或随机、裁切、双层交叉淡化及播放索引。 |
| `scripts/telescope_hotspot.gd` | 透明点击区域、手形光标、轻提示及入口信号。 |
| `scenes/StarGazing3D.tscn` / `scripts/star_gazing_controller.gd` | 鼠标相机、阻尼、FOV、流程、发现反馈、拍照和返回。 |
| `scripts/star_field.gd` | 固定深度背景星和关键星的三维渲染；不负责判定。 |
| `scripts/constellation_data.gd` | 可编辑星图 Resource，参考相机变换和射线深度生成函数。 |
| `scripts/constellation_projection_checker.gd` | `Camera3D.unproject_position()`、平移与均方根尺度归一化、平均对应点误差、持续时间及吸附强度；不控制 UI 或音频。 |
| `scripts/constellation_lines.gd` | 发现后 1.4 秒逐段绘制柔光连线；保持对准时持续发光，转离后淡出，再次对准恢复。 |
| `scripts/game_state.gd` | 自动加载，发现、收藏、照片索引和存档。 |
| `scripts/audio_manager.gd` | 自动加载，海浪无缝循环、进出星空的音量淡变和反馈音。 |
| `resources/*_constellation.tres` | 飞鸟 15 点、鲸鱼 18 点；图案数据与控制逻辑分离。 |
| `shaders/star_glow.gdshader` | 三维星点柔光。 |
| `shaders/subtle_shimmer.gdshader` | 观景台海面极弱亮度变化。 |
| `assets/background/*` | 用户提供的 JPG 场景原图及保留备用的两张 SVG 占位图。 |
| `assets/audio/*_placeholder.wav` | 合成海浪及单音占位素材，不含外部录音。 |
| `tools/regenerate_depths.gd` | 重新生成并保存星图三维深度。 |
| `tests/integration.gd` / `run_tests.ps1` | 在隔离项目副本中验证流程，不修改玩家存档。 |
| `Start.cmd` / `OpenEditor.cmd` | 启动游戏 / 打开编辑器。 |

## 视差与数据编辑

相机绕观察中心做半径 14 的小幅轨道观察，并随轨道朝向旋转。仅原地旋转相机不会使固定星点产生与深度有关的视差，因此这里同时改变观察位置；玩家仍只操作观察视角。星点在游戏中始终固定。默认低动态模式下，远处背景星幕固定于相机作为视觉参照；关键星图仍是固定三维点，场景没有地面和建筑。

模板使用以中心为原点、向右为 X 正、向下为 Y 正的二维坐标。生成器按透视射线缩放 X/Y，并分配 19～52 的深度，保证从参考 Camera Transform 看仍得到目标投影。编辑模板或参考角度后，在工程目录执行：

```powershell
..\GodotRuntime\Godot_console.exe --headless --path . --script res://tools/regenerate_depths.gd
```

这一命令会覆盖两个 `.tres` 中的三维坐标，请先保留你想要的手动排布。`error_threshold` 默认 0.008，`hold_duration` 默认 1.25 秒，`attraction_strength` 默认 0.2。误差按对应点关系比较，不做旋转归一化，且拒绝相机后方或屏幕外的点。靠近时只降低拖动速度，不替玩家自动转到答案。

## 状态与照片

`user://observatory.json` 保存两种发现状态、两种收藏状态及上次轮播文件名。Windows 默认位于 `%APPDATA%/Godot/app_userdata/夜海观景台/`。照片保存在其 `album/bird.png` 和 `album/whale.png` 中，重拍覆盖对应照片。拍摄时暂时隐藏按钮和文字，保留发光星图连线，保存实际星空截图。

2D / 3D 切换时，幕布节点和音频节点不销毁，照片播放时间与过渡持续前进。退出重启后恢复上次照片，单张的停留时间从头计算。海浪在星空中由 -25 dB 淡到 -33 dB。

## 已验证与当前限制

使用 Godot 4.5.2 检查资源导入和 GDScript 编译，并运行隔离集成测试：空照片目录、JPG/PNG 扫描、排序、交叉淡化、望远镜进出、鼠标事件处理、星点不移动、飞鸟解锁鲸鱼、正确/错误角度、持续判定、相机后方拒绝、调焦归一化、轮播持续和重新进入后的发现状态。最终集成测试零失败、无退出资源错误。

使用 NVIDIA OpenGL 实际渲染检查 1280×720 与 960×540 画面，并保存两种星图的 PNG 照片。正确视角平均归一化误差约为飞鸟 4.2×10⁻⁷、鲸鱼 2.3×10⁻⁷；测试错误视角约为 0.171 和 0.144，均高于阈值。

当前背景为用户提供的场景图；UI、合成音效、星图轮廓仍为可运行占位版本。还没有进行真人试玩难度调优，也没有人工听音验收；后续可按体验微调星点大小、阈值、音量和两种轮廓。未引入 NPC、战斗、计分或其他玩法。

便携引擎来自 Godot 官方 4.5.2 Windows 构建。Godot 使用 MIT 许可证，见随包 `GodotRuntime/LICENSE.txt` 和 `GodotRuntime/COPYRIGHT.txt`；引擎介绍与源码见 https://godotengine.org/ 。

场景更新：`shaders/photo_perspective.gdshader` 将照片等比裁切后映射到原图幕布四角。背景原文件保持不变，未添加图片重绘；原占位海面 shader 暂停应用，避免影响插画。已检查实机背景渲染、幕布覆盖和右侧望远镜热点对齐。

星空更新：背景星增至 1000 颗，使用 MultiMesh 批量渲染，星点含清晰亮核、轻微光芒、不同色温与独立闪烁。起始视角随机偏离目标，旋转范围增加，吸附与误差容限收紧；成功仍由归一化屏幕投影判定，保持时间 1.25 秒。新增连线出现检查，实机验证两种星图可连线和收藏。

清晰度更新：界面基准 1920×1080，默认窗口 1536×864，3D 开启 4× MSAA；星点与连线实时绘制。背景现使用内置图像生成工具增强后的 1961×802 PNG，增强过程包含细节重建，并非从原图无损恢复真实细节。

密度调整：背景星为 1000 颗（分布于整个可观察空间，并非同屏全部可见），分格随机采样避免局部拥挤，减少大亮星，背景亮度降至此前的 70%。星图关键点、判定难度和连线发光保持不变。

幕布融合更新：照片在运行时降低饱和度与对比度，加入夜景环境底色、轻微边缘渐暗和静止的细微幕布颗粒；边缘柔化约 1～2 像素。原始照片不变，不使用模糊滤镜。参数位于 photo_perspective.gdshader。

背景清晰度更新：使用内置 image_gen 对用户原图进行清晰度增强，保留整体布局、夜景配色和手绘风格，实际输出 1961×802 PNG（非 4K）。幕布和热点随增强图重新对齐；原始 JPG 保留。生成要求与约束见 `BACKGROUND_ENHANCEMENT.md`。

低动态模式：`comfort_mode=true` 默认开启。背景星幕随相机保持固定构图，拖动灵敏度为 0.001（原先 0.003），取消惯性和松手漂移，锁定 FOV。目标角度附近只允许水平 ±0.22、垂直 ±0.15 弧度的微调，起始角度也相应缩小；保留投影判定、1.25 秒保持和成功连线。不保证消除所有人的不适。当前修改完成后保持游戏关闭，由用户自行决定何时运行。
