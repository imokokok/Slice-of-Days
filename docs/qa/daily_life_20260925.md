# 主体机制验收 · 2026-09-25

按用户确认的《主体机制-系统设计.docx》执行开发。没有更换原场景、人物和背景；275份原美术文件逐项SHA-256校验未变。合入 main 上合作者的 e62b7cb、c6b97e7 厨房更新后重新测试。

## 实际验证

- DAILY_LIFE: 74 checks / 0 failures
- FIVE_DAY_FLOW: PASS checks=223 failures=0
- ARCHITECTURE_AUDIT: PASS checks=42 failures=0
- DAILY_LIFE: 74 checks / 0 failures
- DAILY_LIFE_CAPTURE: 4 pages / 0 failures

新机制测试实际操作厨房的切菜、火候、翻拌、尝味与装盘按钮，分别完成90分钟早退班和240分钟完整班；检查取消恢复、工资只付一次、换班不吞掉另一班次、人物事件防重复、读档和双角色来源隔离。五日回归包含真实游戏录音与WAV制作、拼贴信封与火漆、棋局、身份会面、跨领域活动和独立账目。

验证新纸页的四个实际窗口画面，检查文字、长列表滚动和入口；关键的重组/等待放在列表上方。最终截图从导出的 PCK 运行获得，不是网页仿制。

机制范围、数值与具体玩法见 `docs/DAILY_LIFE_SYSTEM.md`。这一版每位居民有两段短事件与一次后续认可；没有声称包含无限分支或新的完整NPC长篇剧情。新页面以中文文案交付。

## 复现

    Godot --headless --path . --script tests/integration/test_daily_life.gd -- --isolated-save
    Godot --path . --script tests/integration/test_five_day_flow.gd -- --isolated-save
    Godot --headless --path . --script tests/integration/test_architecture_alignment.gd -- --isolated-save
    Godot --path . --main-pack .runtime/life-windows/Solmere.pck --script tests/integration/test_daily_life.gd -- --isolated-save
    Godot --path . --main-pack .runtime/life-windows/Solmere.pck --script tools/capture_daily_life.gd -- --isolated-save

最后两项使用引擎加载最终资源包；测试脚本不打包进正式游戏，作为外部脚本运行。截图目录由环境变量 `SOLMERE_QA_CAPTURE_DIR` 指定。测试存档和正式玩家存档隔离。
