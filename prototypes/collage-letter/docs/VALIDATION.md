# 验证记录 · 2026-09-26

最终桌景、书页弯曲、书写笔、墨色与纹理缓存接入后，已重新运行 9 项独立游戏检查，全部通过且无引擎错误。Godot 4.7.2 主游戏子视口也完成 678 项素材集成检查。

## 已有自动化证据

本机日志位于工作区 `outputs/`，不将测试缓存、数据库或玩家身份打入发行包。

| 检查 | 已有结果与范围 | 日志 |
| --- | --- | --- |
| 素材库 | PASS；678 条目，渲染结果不同，逐项实际裁剪；中文原创印刷文案比例约 80.3% | `drawer-final-qa/library_test.log` |
| 来源与字母 | PASS；216 项来源文件 SHA-256；大写 F、小写 f 与原图保留像素逐一比对，无缺失彩色像素块 | `drawer-final-qa/asset-audit.txt` |
| 纸张 | PASS；24 款 A4 底纸、存档和信纸范围 | `drawer-final-qa/letter_paper_test.log` |
| 写信 | PASS；实际 TextEdit 插入、墨色切换保留光标、笔尖跟随、删除不落墨、停笔抬起、存档与寄出 PNG 墨色检查 | `drawer-final-qa/letter_writing_test.log` |
| 布局 | PASS；中英文 × 3 种窗口大小 × 8 种工具，共 48 组，检查实际控件尺寸及重叠 | `drawer-final-qa/ui_layout_test.log` |
| 委托与绘画 | PASS；逐字对话、暂停和记录、追问及附件，纸面与材料绘画边界 | `drawer-final-qa/paint_dialogue_test.log` |
| 素材册 | PASS；新弯曲纸页向前／向后翻动、纸声、动画退场，百叶窗开合和存档；预览翻页另由布局测试覆盖 | `drawer-final-qa/office_book_test.log` |
| 收信与回信界面 | PASS；中英文、收件阅读、正文／作品切换、翻页和回复入口 | `drawer-final-qa/bottle_dock_ui_test.log` |
| 漂流瓶 | PASS；卷纸、拔塞、连续插入、塞回和入海；含中间状态保存与失败重试 | `drawer-final-qa/bottle_ritual_test.log` |
| HTTP 服务端 | 8 项测试通过；真实 HTTP 双玩家、并发、回复义务、分页、重启、认证与幂等 | `server-final-agent/test-service.log` |
| 丢失响应重试 | PASS；真实 Godot HTTP 客户端对接 Waitress；首次响应丢失后仍只产生一封信，注册不自动重复，重试有上限 | `server-final-agent/test-client-retry.log` |
| 完整网络流程 | NETWORK PASS；真实 Waitress 服务与两个 Godot 玩家身份，寄信、回复及回复义务检查 | `drawer-final-qa/network-full.log` |
| 实体封信 | PASS；折信、连续遮挡入封、拖翻盖、划火柴、点蜡烛、融蜡、不可逆倒蜡判定、盖章、信箱、保存与下一委托 | `drawer-final-qa/finishing.log` |
| 主游戏集成 | PASS；Godot 4.7.2 实际 GPU 子视口，678 素材渲染、裁剪、声音与宿主布局 | `drawer-final-qa/host-final.log` |
| 纹理缓存 | PASS；48 张共享缓存、纸纹最长边 1024、照片 2048；52 字母与原导入像素一致；缓存移除不破坏已持有图片 | `asset-memory-agent/cache-library.log` |
| 便携 Python | PASS；包内 Python 3.13.7 的 SQLite、SSL、HTTP 依赖及 Waitress 初始化；服务端 8 项测试通过 | `server-final-agent/bundled-python-import.log`、`bundled-python-service.log` |
| 更新后启动 | PASS；资源元数据指纹使新增／修改素材重新导入；忽略导入缓存，失败不更新标记也不启动游戏 | `server-final-agent/import-signature.log` |

678 表示可用材料条目，不是 678 张独立下载原图。216 表示当前 open-pack 来源清单项数，不包括后续独立桌景美术的来源记录。字母的白色内部细节保留；本次不以换色数量代表新增独立原图。

## 可见画面与修复复验

已查看最终 GPU 截图中的书桌、打开的素材本、弯曲纸页、笔尖与墨色，并更新 `docs/preview.png`。翻页初次出现的退化四边形破面已改为独立三角面并复验无渲染错误；桌面分区绘制修正了下方物件落在桌沿上的问题。百叶窗拉绳的交互区避开右上声音按钮。

已真实启动并切到前台的 Windows 可玩窗口显示新桌景和打开的素材本。检测到用户正在操作后保留该窗口，没有继续注入测试输入。程序化测试覆盖原生编辑器的插入、光标、墨色与导出；本轮不声称已人工验证 Windows 中文候选窗的完整输入过程。先前的内存分配失败通过显示尺寸纹理缓存处理，最终素材库、纸张与完整封信流程均重新通过。

同步远端已有主游戏改动后，书信模块内容保持一致，并补跑主游戏子视口快速集成复验：`host-after-rebase.log`，PASS，24 项抽样素材。

## 验证边界

当前证据来自本机，未完成公网部署或独立第三方玩家联机；没有声称完整试玩 Kind Words 或 Paper Sky 原作。音频采用实录资源，但未完成所有音频设备的听感验证。保留的历史日志只用于追溯，含错误的日志不算通过，即使其中也出现 PASS 字样。4 张新桌景／书册／文具插画为图像工具制作，并非商业参考游戏提取物，也不标为 CC0，见 [制作记录](../assets/illustrated_office/PROVENANCE.md)。

便携包由 `work/update_journal_package.py` 与 `work/zip_journal.py` 生成：保留引擎、启动入口和运行时，只清除明确列出的 5 个旧照片 PNG；ZIP 只纳入当前源码、运行时及发行元数据。最终 `VERSION.txt` 和 `source-manifest.json` 记录实际 Git 提交与每个源文件 SHA-256。源码有未提交修改、缺失文件或与便携目录内容不同，打包检查会停止。
