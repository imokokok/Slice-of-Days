# 夏日配色 · 2026-09-24

依照用户要求，只调整显示颜色，保留现有背景贴图、场景美术、角色、布局和界面。参考 SUMMERHOUSE 官方画面的暖白、橙色屋顶、绿植与蓝色环境关系，不导入或复制参考游戏的美术。

官方参考：https://store.steampowered.com/app/2533960/SUMMERHOUSE/ 。

## 实现

- `summer_palette.gdshaderinc` 为海岸背景、建筑、角色、房间提供共用色彩映射：暖白亮部，偏橄榄的绿植，更清楚的海蓝，压低紫红色荧光感。保留原图的 UV、透明度、轮廓和细节，不添加噪点、模糊或色阶断层。
- 夜景使用连续变化的冷蓝环境色，并继续使用原有灯光位置；黄昏的天空与云层偏金橙。现有时间缓动和雨天切换机制不变。
- 室内使用较轻的配色强度，保留贴图本身已经画好的灯光，避免再次按室外时间压暗。HUD、菜单和对话 UI 不参与场景调色。
- 同步前保留了 main 上新增的厨房打磨提交 793f8a5。

## 检查

- 275 个已有美术文件与本轮开始时的 SHA-256 完全一致，清单见同名 JSON。
- 时间连续性回归：15 项，0 失败；包括较大时间消耗、切场景、雨天渐变。
- A/B 家入口、原图透明区、唱片店老板及真实对话交互回归：31 项，0 失败。
- 源码与最终 Windows PCK 各捕获 12 个实际场景画面，0 失败，均使用隔离测试存档。
- 对照检查白天、黄昏、夜晚、雨天、唱片店和 A/B 室内，并打开最终打包资源的原生游戏窗口核对显示。
- 对比页：`ui_reference_review/summer-palette.html`。调整前截图来自提交 28cc691 的实际场景；调整后截图来自最终打包资源。

复现：

    Godot --path . --script tests/integration/test_atmosphere_transition.gd -- --isolated-save
    Godot --path . --script tests/integration/test_supplied_home_and_owner.gd -- --isolated-save
    Godot --path . --script tools/capture_summer_palette.gd -- --isolated-save

打包检查在最后一条增加 `--main-pack .runtime/windows/Solmere.pck`。环境变量 `SOLMERE_QA_CAPTURE_DIR` 须设为可写的绝对目录，可加 `--keep-open` 留下实际可操作窗口。
