# 拼贴书信 v2 · 独立源码项目


此目录仅包含源码与必要素材，不含引擎、Python 运行时、玩家数据或发布 ZIP。已验证环境为 Godot 4.5.1、Python 3.13.7；与仓库根目录的 Solmere 主项目独立运行。

## 从源码运行

先安装 Godot 4.5.1+ 与 Python 3.10+。将 Godot 加入 PATH（命令名 godot 或 godot4），或设置 GODOT_BIN 为引擎可执行文件的绝对路径。

从本目录运行：

```sh
python server/launch.py
```

这个命令会启动所需的本机邮局和游戏。也可以用 Godot 编辑器导入本目录的 project.godot，运行 server/app.py 后按 F5 开始游戏。Windows 的 .cmd 脚本使用 Python 的 py -3 启动器；其他系统使用上述命令。中文显示需要 Microsoft YaHei、Noto Sans CJK SC 或 PingFang SC 等系统字体。

```sh
python server/test_service.py
python server/launch.py --demo
```

已移除胶棒，工具改为刻刀；素材扩展为 33 份，新增可部署的漂流瓶联机系统。

- 双击 **Start-Game.cmd** 启动最新版和本机邮局。
- 双击 **Start-Two-Players.cmd** 用两个独立身份演示互发、互回。
- 双击 **Open-Editor.cmd** 查看完整 Godot 项目。
- 游戏右上角进入 **海边 · 漂流瓶邮局**。

发出一封新的漂流瓶后，需要回复一封其他寄信人的信，才能再次自由发信。规则与历史信件由服务端保存。

阅读 [完整操作说明](GUIDE.md) 和 [服务器部署说明](server/README.md)。当前为已验证的本机联机版，可部署到局域网或自己的服务器，尚未开通全网公共服务。

原版草稿可恢复。请先关闭旧版窗口，再打开新版。
