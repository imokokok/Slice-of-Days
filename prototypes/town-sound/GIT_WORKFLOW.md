# 修改后直接推送

仓库：https://github.com/imokokok/Slice-of-Days
分支：main（跟踪 origin/main）。

## 唯一工作目录

在本机 outputs/Slice-of-Days 工作副本中编辑：

- 主 Godot 项目：仓库根目录 project.godot。
- Town Sound 运行代码：scripts/town_sound/。
- 相册和相机也在该目录，没有另一份独立实现。
- 小镇入口：scripts/ui/town_day.gd。
- 测试：tests/town_sound/。

旧 outputs/TownSound 和早期 ZIP 是快照，不会自动同步。prototypes/town-sound 仅保留文档和推送脚本。

## 一条 PowerShell 命令

从仓库根目录运行：

```powershell
./prototypes/town-sound/Push-TownSound.ps1 -Message '调整录音与相册'
```

脚本会暂存本系统和对应主游戏入口/配置修改，commit、fetch、rebase、普通 push。遇到其他模块未提交修改、分支错误或冲突时停止，保留现场；不强制覆盖远程。如果修改的是其他系统，可以自己用标准 Git 命令提交相应文件后 push。

```shell
git add scripts/town_sound scenes/town_sound tests/town_sound prototypes/town-sound scripts/ui/town_day.gd project.godot README.md
git commit -m "Update Town Sound"
git pull --rebase origin main
git push origin main
```

本机沿用 Git Credential Manager 的已有凭据，首次推送已实际成功。只要账号权限与登录有效，就可继续直接推送；不会把 token 写入源码。换电脑需要重新克隆并登录有写权限的账号。

本工作副本采用 sparse checkout；主游戏所需 art、scenes、scripts、data、docs、tests 和 Town Sound 文档都已检出，其他原型仍保存在远程。修改不自动上传，只有运行推送命令或明确要求 Codex 推送才会上网提交。

验证命令见 README.md。玩家录音、照片、工程与成品均位于 Godot user://，不会进入 Git 提交。