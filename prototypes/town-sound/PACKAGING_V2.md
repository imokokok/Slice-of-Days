# 唱片结构与包装交互修订

## 现实参考

- [Precision Record Pressing：中心标签与模板](https://www.precisionpressing.com/templates)：中心标签是随 PVC 压入的纸标签，不是压完再贴的贴纸。
- [Precision：单张封套](https://www.precisionpressing.com/print/single-jackets)：单口硬纸板封套与独立书脊。
- [Precision：项目流程](https://www.precisionpressing.com/blog/guide-the-5-steps-of-your-first-project)：音频和封面提交、试压确认、生产与组装。
- [Sleeve City：透明可重复封口外袋](https://sleevecityusa.com/products/10in-resealable-3-mil-outer-sleeves-50-pack)：使用其 PP 透明膜、独立翻盖和焊缝的结构原则；游戏表现为匹配 12 英寸封套的尺寸，并非照搬 10 英寸产品尺寸。
- [Interscope：《La La Land》原声黑胶实体封面](https://interscope.com/products/various-artists-la-la-land-original-motion-picture-soundtrack-vinyl)：参考米白底、蓝色大标题、清楚的作者署名和图文留白比例。游戏继续使用玩家的 MV / 照片，不使用电影海报、剧照或原作商标。

只参考结构和流程，未下载或复制商家产品图。本轮为 Godot 原生 2D 绘制，无新增生成式位图素材。纸张轻响复用已有 CC0 音效，许可见 art/town_sound_cc0/SOURCES.md。

## 实际变化

1. 印刷纸板封套；打印时按实际出纸长度揭露图像，避免把整张封面压扁伸长。
2. 将 A 面纸标签与已装好 B 面标签的 PVC 料饼对齐；随后压制、冷却、修边。母版刻录和电铸压模属于已完成的前置工序，界面作说明。工业生产时长在游戏中压缩，不宣称是完整工业模拟器。
3. 唱片包含外缘、音槽细线、随纹路变化的反光、中心标签和中心孔。鼠标只允许拿外缘或标签区；握在音槽区会提示纠正。
4. 纸内袋从上端进片：背片 → 唱片 → 带真实镂空圆窗的前片。插入过程中袋口下方遮住唱片，圆窗仍能显示标签。
5. 装好的纸内袋从硬纸封套右侧水平插入；封面遮住已进入的部分，纸内袋开口与封套开口相互垂直。
6. 封套从上方装入透明 PP 外袋：背膜 → 封套 → 前膜。前膜包含低透明度透色、双焊缝、窄反光、宽柔光与角部张力折痕。
7. 折合外袋翻盖，胶条在保护袋上；编号贴在外袋右下角。移除虚构的“封套下沿插卡槽”和在成品封面上直接盖章。
8. 成品保持同一封面、封套、外膜、编号结构。交到托盘后，从实际放下的位置拿起、绕竖直轴转侧、竖着入架，最后只露出与邻近唱片等高的书脊；不再把正面封套缩成一张悬空小卡片。
9. 玩家填写的标题和署名印入 512×512 封面 PNG，也显示在中心纸标签与书脊上。封面长标题自动换行缩字号，狭窄书脊和中心标签使用省略号；完整名称保存在唱片资料中。新增 cover_layout_version、spine_title、spine_artist、shelf_orientation 字段；已有唱片保持原封面，不修改玩家历史文件。
10. 上架后点击米白色书脊可开合封面近看；近看使用同一张成品图片，不额外保存或结算。唱片库缩略图加大且保持原图比例。

## 对齐与输入

- 拾取时保留鼠标到物体中心的偏移，拿边缘不再跳到鼠标中心。
- 命中区域、绘制位置和动画使用同一桌面坐标系。
- 拖动时显示实际对齐区；没对准会放回，不跳过步骤。
- 入袋分为对齐袋口、沿开口轴线插入两段，避免从侧面穿袋。
- 工作台移动范围约束避免物件覆盖标题、步骤条或伸到屏幕外。
- 辅助按钮保留；它使用相同动画与保存逻辑，便于不方便精确拖动的玩家。

## 验证

```
godot --script tests/town_sound/test_packaging.gd -- --isolated-save
godot --script tests/town_sound/test_flow.gd -- --isolated-save --photo-cover --save-retry --screenshots
```

新测试实际发送拾取、移动、放开事件，检查音槽误抓、边缘抓取不跳动、错放不推进、各层装袋、翻盖和编号。另读取渲染像素，检查内袋前片遮挡与圆窗显露。`--manual` 为真实窗口鼠标检查入口，使用隔离存档和测试作品，不覆盖玩家正式存档。

`test_flow.gd` 还验证标题真正改变封面像素、60 字中文标题不覆盖图片、照片颜色保持、重新加载 PNG 内容一致、交付拖拽、保存失败重试、入架朝向和基线、点击书脊近看及不重复保存。加 `--manual-sleeve` 会完成检查后停留在成品架，供真实鼠标操作。
