# 后续编辑与直接推送

仓库：https://github.com/imokokok/Slice-of-Days

分支：`main`。项目：`prototypes/town-sound/project.godot`。

## 以后改这里

在当前电脑的 `outputs/Slice-of-Days/prototypes/town-sound/` 工作副本里编辑。不要继续改旧交付包的 `outputs/TownSound/` 或解压出来的 v0.1/v0.2 副本；它们不会自动同步到这个 Git 工作副本。

可把整个 `Slice-of-Days` 文件夹作为 Codex 项目打开。Godot 则单独导入本目录 `project.godot`。这份本地工作副本采用 Git sparse checkout，主要检出本原型；仓库内其他原型和主游戏仍完整保存在 GitHub。

## Windows 一条命令提交并推送

在本项目文件夹中用 PowerShell 执行：

```powershell
./Push-TownSound.ps1 -Message '修复选区剪辑'
```

脚本只暂存本原型的修改，创建提交，取得远程更新，再 rebase 和普通 push。没有变化时也会推送尚未上传的本地提交。不使用 force push。其他目录有未提交修改、分支不对或出现冲突时会停止，保留现场供处理。

也可以在仓库根目录手动执行：

```shell
git add prototypes/town-sound
git commit -m "Update Town Sound"
git pull --rebase origin main
git push origin main
```

开始一轮编辑前，建议在干净工作区执行 `git pull --rebase`。本地 `main` 跟踪 `origin/main`，仓库级 `pull.rebase=true`、`push.default=simple` 已配置。

## 凭据与边界

当前电脑通过 Git Credential Manager 使用已有 GitHub 凭据，源码和脚本不含 token。只要账号权限和登录继续有效，就可以直接 push。换电脑需要重新克隆并登录有写权限的 GitHub 账号；不能保证凭据永久不过期。

修改不会未经命令自动上传。运行上面的脚本，或明确让 Codex 提交推送，即会同步到 GitHub。

Godot `.godot/`、本地生成的 `build/`、EXE/PCK/ZIP、日志和 `.env` 已忽略。玩家录音及存档在 Godot `user://`，不位于仓库内。

## 编译与验证

用 Godot 4.7.2 打开本项目运行。导出 Windows 前创建 `build/` 目录并安装对应免费导出模板：

```shell
godot --headless --path prototypes/town-sound --editor --import --quit
godot --headless --path prototypes/town-sound --script res://tests/test_arrangement.gd
godot --headless --path prototypes/town-sound --script res://tests/test_audio_settings.gd
godot --path prototypes/town-sound --script res://tests/test_flow.gd
godot --headless --path prototypes/town-sound --export-release "Windows Desktop"
```

最后两项分别需要真实图形驱动和已安装的导出模板。EXE 会生成到 `prototypes/town-sound/build/`，不会提交到源码仓库。
