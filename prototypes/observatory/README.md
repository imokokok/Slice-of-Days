# 夜海观景台

独立 Godot 4.5+ 原型：2D 海边观景台、用户照片轮播、飞鸟和鲸鱼星图观察、发现反馈与本地收藏。此目录保留独立 `project.godot`，没有接入 Solmere 主游戏场景或共享其 GameState。

## 运行

安装 Godot 4.5 或更高版本，在项目管理器中导入本目录的 `project.godot`，按 F5。也可在仓库根目录运行：

```sh
godot --path prototypes/observatory
godot --editor --path prototypes/observatory
```

本源码不包含 Godot 可执行文件、`.godot` 缓存、个人存档或截图。`prototypes/.gdignore` 防止主工程导入独立原型的脚本和全局类；它不影响单独打开此子工程。

## 当前功能

- 16:9 观景台，以增强版背景等比裁切显示。
- `assets/slideshow` 内的两张用户照片按名称循环播放，停留 5 秒、交叉淡化 1 秒，并映射至幕布四角。原始照片不做修改。
- 飞鸟、鲸鱼使用独立 Resource；以三维星点的屏幕投影归一化误差判定，稳定 1.25 秒后发现。
- 发现后逐段连接并发光；支持解锁、重访、拍照和本地收藏。
- 固定星图模式：水平/垂直按钮每次调整一档，相机和背景完全固定；鼠标拖动、滚轮与惯性均不参与控制。背景共 1000 颗星，批量渲染。
- 2D/3D 往返时轮播和环境音持续运行；发现及收藏状态保存在 Godot `user://` 中。

星图采用虚拟投影计算，并立即更新固定深度平面上的关键星点；没有镜头旋转、平移、缩放或星点位移动画。水平、垂直各有 −12 至 +12 档。对准后的判定仍基于实际显示投影，等待 1.25 秒后逐段连线发光。

## 文件入口

| 路径 | 用途 |
| --- | --- |
| `scenes/Main.tscn` | 场景切换及常驻观景台 |
| `scenes/ObservatoryDeck.tscn` | 背景、幕布、望远镜热点 |
| `scenes/StarGazing3D.tscn` | 星空、相机和观测界面 |
| `scripts/` | 轮播、相机、投影判定、音频与存档 |
| `resources/` | 飞鸟及鲸鱼可编辑星图 |
| `assets/` | 背景、两张轮播照片、合成音效占位素材 |
| `shaders/` | 星点、幕布透视及夜景色调 |
| `tools/regenerate_depths.gd` | 星图深度生成工具 |
| `tests/integration.gd` | 隔离环境集成检查 |
| `README_中文.md` | 原型开发说明与参数说明 |
| `BACKGROUND_ENHANCEMENT.md` | AI 背景增强来源与提示词 |

## 验证

PowerShell 中指定本机 Godot 控制台可执行文件：

```powershell
./prototypes/observatory/run_tests.ps1 -EnginePath 'C:/Tools/Godot_console.exe'
```

测试会创建临时项目副本和独立用户存档目录，不修改玩家存档。检查包括照片读取与淡化、场景切换、固定背景、按钮逐档调节、输入屏蔽与焦距锁定、错误/正确投影、持续判定、连线发光及解锁状态。

背景由用户提供的原图经内置图像工具增强，包含 AI 补绘；原 JPG 与增强 PNG 同时保留。音效为合成占位版本。素材没有额外附加再分发授权声明。
