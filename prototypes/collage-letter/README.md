# Solmere · 书信事务所

平面 2D 桌面，67 项新素材，独立工具与纸片。胶棒支持翻面涂胶、覆盖量判断、压贴/揭起和完整撤销存档；保留裁切、逐字打字、折信封蜡及可部署漂流信箱。

Windows 完整包双击 `Start-Game.cmd`。GitHub 源码需 Godot 4.5.1+ 与 Python 3.10+：打开 `project.godot`，或执行 `python server/launch.py`；可通过 `GODOT_BIN` 指定引擎。第一次启动会导入素材。

- [操作说明与实现范围](GUIDE.md)
- [素材来源与许可证](workshop/open_assets/README.md)
- [服务端部署](server/README.md)

旧素材已从当前源码移除；旧玩家草稿继续保留。默认连接本机服务，公网需自行部署。引擎和 Python 运行时不放入 Git。
