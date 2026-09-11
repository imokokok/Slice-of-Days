# Solmere 美术替换指南

## 当前原则

现阶段界面使用暖色手绘背景、奶油纸卡、陶土红、灰蓝和鼠尾草绿完成可玩版本。正式美术接入时保留数据 ID、节点职责和结果结构，只替换图片、图标、字体、材质、动画和声音。

## 可以直接替换的资源

### A / B 主角立绘

人物方向与资源入口位于 `data/story/characters.json`。正式立绘到位后，为对应角色填写：

```json
"portrait_path": "res://art/characters/a/portrait_default.png"
```

`role`、事件 ID 和记忆意象不用随画稿改动。可以先更换默认立绘，之后再在事件 `presentation` 中扩展表情或场景专用图；当前空路径不会造成资源加载错误。

当某日未单独配置开场插图时，界面会优先使用对应角色的 `portrait_path`，再回退到现有小镇占位图。

### 每日角色开场

配置文件为 `data/story/day_openings.json`。在任意一天的 A 或 B 条目中添加：

```json
"image_path": "res://art/openings/day_01_a.png"
```

建议使用接近方形的横幅插画，安全构图比例约为 13:12。界面会以裁切填满方式放入左侧画框，文字、按钮和章节状态不会受影响。

### A B 章节切换

配置文件为 `data/story/transitions.json`。在 `roles.A` 或 `roles.B` 中添加：

```json
"image_path": "res://art/transitions/day_04_a_photo.png"
```

建议输出 16:9 图片。系统会继续负责卡片移动、边缘对齐、章节推进和自动保存。

### 单场剧情插图

在 `data/story/events.json` 对应事件的 `presentation` 中添加：

```json
"image_path": "res://art/events/day_03_a_dinner.png"
```

插图会以低透明度铺在事件卡内，继续保留标题、对白、花费和选择按钮。若最终希望采用立绘对话框，可继续复用同一资源字段，只替换该显示组件。

包含 `presentation.beats` 的舞台式事件会把同一张图放在左侧主画框中，建议主体不要贴近右边缘，并为人物对白保留安静区域。当前示例资源为 `art/locations/old_station/old_station_long_evening_v01.png` 与 `art/locations/print_shop/print_shop_morning_v01.png`。

十二名核心居民的视觉母题保存在 `data/npcs/core_residents.json` 的 `recurring_image`。这是概念设计提示，不绑定具体文件路径；正式立绘确定后可以增加 `portrait_path` 或场景专用表情路径，继续保留居民 ID。

### 生活玩法工作台

配置文件为 `data/gameplay/module_prototypes.json`。玩法根节点可以添加：

```json
"background_path": "res://art/gameplay/cooking/workbench.png"
```

每个操作项可以添加：

```json
"icon_path": "res://art/gameplay/cooking/lemon.png"
```

建议背景按 16:9 输出；操作图标使用透明背景正方形。烹饪材料、句子纸片、声音片段、棋子、照片和空间记录都可逐项替换，不改变选择记录与结算。

这 8 个工作台当前由独立制作流程继续深化；主线内容填充只引用稳定的 `launch_module` ID，不改动其内部交互。

### 分支结局

配置文件为 `data/story/endings.json`。任一 `variants` 分支都可以添加：

```json
"image_path": "res://art/endings/both_passed.png"
```

建议使用 16:9、四周保留文字安全区的环境插画。结局标题、双角色结果卡、关键选择回声和返回按钮会继续由界面生成。

## 建议暂缓到美术规格确定后再做

- 角色逐帧动画、骨骼比例和碰撞区域。
- 2D、2.5D或轻量3D之间差异较大的镜头与遮挡。
- 空间错觉玩法的最终旋转模型、深度判定和相机操作。
- 依赖最终字体尺寸的逐字动画和复杂文本框排版。

## 接入检查

每次替换资源后，应检查 1280×720 与 1600×900 两种窗口尺寸，确认裁切主体、按钮可读性、中文字体、颜色对比度和存档读取均正常。不要修改居民、事件、玩法、章节和作品的稳定 ID。
