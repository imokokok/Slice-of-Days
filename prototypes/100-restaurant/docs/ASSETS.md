# 资源与授权记录

| 文件 | 来源 | 许可 / 处理 |
| --- | --- | --- |
| `modules/restaurant/assets/fonts/noto_sans_sc.ttf` | Google Fonts / Noto Sans SC | SIL Open Font License 1.1；同目录保留 OFL.txt |
| 项目图标、纸张与程序贴纸 | 本项目程序绘制 | 提供绘制源码 |
| 食材、厨具、顾客与历史厨房图集 | 内置图像生成工具生成 | 参见 SCENE_ART.md，不是商业参考游戏提取素材 |
| kitchen_reference_playable.png | 内置 image_gen 编辑用户提供的厨房图 | 保留布局，移除可移动道具；见 REFERENCE_KITCHEN_20260925.md |
| docs/kitchen_*20260925.jpg | 用户提供的视觉参考 | 来源权利未另行核验，不据此宣称原创或转授许可 |

字体来源：https://github.com/google/fonts/tree/main/ofl/notosanssc

未将私人聊天截图、头像、群成员名字、用户电脑路径或商业参考游戏素材放入交接包。

本项目未替团队确定项目整体的开源许可。公开发布前由团队决定整体代码与自有美术的授权范围。字体自带的 OFL 许可应继续保留。

若使用独立 Windows 演示包，其中 Godot 运行时为 MIT 许可，随包保留引擎授权文件。

## 音效

`modules/restaurant/assets/audio/*.wav` 为本项目原创分层合成拟音，生成脚本在 `tools/generate_kitchen_audio.py`。不含参考游戏提取、私人视频音轨或第三方录音。它们是可替换的开发素材，事件接口和已接入清单见 `docs/AUDIO.md`。
