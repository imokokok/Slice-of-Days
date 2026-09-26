# 观景台用户素材替换 · 2026-09-26

## 接入

- `lookout_platform_supplied.jpg`：平台、台阶、栏杆、长椅、遮阳伞、灯具和望远镜，替换主游戏的简化观景台绘制。
- `lookout_screen_supplied.jpg`：独立放映屏，实际照片轮播区域按画面内边缘定位。
- 主游戏、观景台扩展入口页面和独立原型均接入；照片轮播与望远镜入口采用新素材坐标。
- 原始 JPEG 完整保留，仅在 Godot 显示时去掉白色画稿背景；栏杆、长椅和电线之间的白底使用明确坐标处理，望远镜浅色涂装保留。
- 原有海岸路线、人物落脚线和 21:00 开放规则继续使用。

## 原文件 SHA-256

- 平台：`fe721c595a34784d3892ad0bed8d0f12dbe67c7d8b805654bbde1a0010ad436f`
- 放映屏：`128fa56d636da50a16e3e2596c2808d4779f2648ca8763a17ef1951eb2f92296`

已与两份剪贴板附件比对一致。

## 实际窗口验证

- `day.png` / `night.png`：主游戏 11:00 / 21:00 原生 Godot 截图；画稿白底、人物比例、屏幕边缘与轮播内容检查通过。
- `extension.png` / `prototype.png`：两处独立观景台页面加载、播放区域和望远镜按钮定位检查通过。
- `entry.log`：21:00 门禁开放、当前 A 角色 21:10 空闲时段进入真实 3D 望远镜并返回小镇通过。
- `git diff --check` 通过。

旧 `test_observatory_hours.gd` 在 21:00 请求活动，与当前 A 角色空闲时段不匹配，未通过其旧版完整回归；本次使用当前日程单独验证门禁、素材热点、3D 进入和返回。未改动日程或 3D 观星内容。

复现主游戏素材预览：

```sh
godot --path . --script res://tools/preview_lookout_art.gd -- --isolated-save --capture
godot --path . --script res://tools/preview_lookout_art.gd -- --isolated-save --night --capture
```

## 放映屏位置调整

按用户箭头标注移到两张长椅中间的后方，屏幕与照片播放区域共用位置坐标；主游戏、扩展和独立原型同步。实际窗口截图为 `screen-position.png`，主游戏素材预览与 `git diff --check` 通过。

最终按用户反馈将屏幕再向右微调 30 个世界像素，与遮阳棚留出间隙；照片区域同步移动，三处布局均使用 `SCREEN_OFFSET = Vector2(180, -150)`。最终截图为 `screen-position-right.png`。
