# 素材接入与适配验收 · 2026-09-24

环境：Godot 4.7.2、Windows、Compatibility / NVIDIA OpenGL、WASAPI。所有自动化游戏流程使用 `--isolated-save`。表中最终日志均扫描过，无 `SCRIPT ERROR` 或 `ERROR:`。

| 验收 | 实际结果 |
| --- | --- |
| Resource integration | RESOURCE_INTEGRATION: 204 checks, 0 failures |
| Exported PCK resources | RESOURCE_INTEGRATION: 204 checks, 0 failures |
| Five-day production flow | FIVE_DAY_FLOW: PASS checks=218 failures=0 |
| Shopping, recipes, fishing and kitchen | HANDMADE LIFE: 55 checks, 0 failures |
| Collage, map and live recorder UI | UI_REVIEW: 20 checks / 0 failures |
| Fresh-process UI reload | UI_REVIEW_RELOAD: 4 checks / 0 failures |
| Recording failed-save retry | RECORDING_RETRY failures=0 |
| Actual audio bus isolation | WORLD_CAPTURE_TESTS: PASS |
| Merged cooking decisions and outcome | COOKING_RHYTHM_TEST: PASS failures=0 |
| Merged native module routes | NATIVE_MODULE_TEST: PASS failures=0 |
| Merged procurement and inventory | V3 ECONOMY PASS: 51 checks |
| Pocket objects and complete cooking controls | POCKET_OBJECTS: 57 checks / 0 failures |

## 实窗验证

- 新主菜单：地图不覆盖按钮；鼠标点击制作人员可以看到真实作者署名和滚动页面。
- 厨房：实际窗口选择柠檬、面包和奶酪，点击砧板逐项备料、点食材移到锅边、点击改造锅具下锅；锅口和菜谱记录同步。首次单步版本曾实窗确认出餐；合并后完整备料、下锅、翻拌、尝味、装盘和出餐由真实控件测试另行覆盖。修正后的火候说明已重启检查，不再挤进食材栏。
- 录音：实际录制数十秒，真实场景、波形、六频段色块随采样更新；停止显示已保存，回听入口启用。
- 独立导出 EXE：实际启动、重新识别窗口并截图检查主菜单。PCK 内容单独用同一资源/音频/料理测试验证，未用源项目目录冒充打包资源。

## 本轮修复中发现的问题

1. TextureRect 在设置忽略原图尺寸之前已被原图撑大：改为先设扩展模式，再指定地图大小。
2. 改造锅具的原后景层悬浮：按新锅口重新定位并保留前景遮挡。
3. 纸页样式从 StyleBoxFlat 切到 StyleBoxTexture 后，继承页强制转换导致空页面：移除不成立的类型假设。
4. 快速换页释放按钮后，延迟动效挂接仍携带失效 Object：改为延迟解析实例 ID，并验证 25 个当帧释放的按钮及完整五日流程。
5. 发布前合并 main 的料理节奏更新：将锅具层绑定到真实分步状态，调整汽泡/热气在新锅口的位置，移除料理中的脚步占位音，更新旧单步回归。火候长句上移，避免落入食材栏。

早期无声 headless 启动不具备真实录音驱动；实际录音验收均显式使用 WASAPI。五日唱片封面步骤需要真实渲染，因此完整五日测试使用图形窗口。这些早期不适用的运行未计入通过结果。

安装器已从本地官方 ZIP 重新安装并校验 84 文件；公开代码包含固定哈希，作者更新包后会明确停止而非悄悄替换版本。所需音频均以实际采样验证，不声称人工逐个听审每一条采样。

待办：Odds & Ents 免费纸纹理领取所需邮箱仍未提供；未取得该包。候选文档的其他新增玩法没有借本次导入冒称完成。功能范围与分发说明见 [交付报告](../resource_integration_delivery_20260924.md)。
