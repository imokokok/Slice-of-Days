# 纸页与磁带 UI · 2026-09-24

使用内置 image_gen，未使用 API / CLI。参考用户提供的经营 UI 分区和磁带形象，生成新的空白底图，中文文字和交互由 Godot 控件提供。

最终游戏素材：
- `art/ui/reference_paper/clipboard.png`：饭店采购夹板。
- `art/ui/reference_paper/cassette.png`：暂停 / 设置的磁带收纳盒。

两张 PNG 都已处理为透明背景，游戏中没有荧光粉紫色底。米白、浅木色、灰绿和深棕线条是当前配色。去除了绘图外的背景，保留原图案和笔触。原始抠图背景不是 UI 配色，未放入游戏资源。

`tools/prepare_reference_paper.cjs` 记录裁切步骤；开发工具依赖 Node.js + sharp。生成源图保留在本机 image_gen 输出目录，最终素材已保存到仓库，运行游戏不依赖该目录。

## 实际生成提示词

以下保留生成时的原始提示词，含后来已移除的抠图背景说明。

### ui_cassette_gen

```text
Create ONE production-ready 2D illustrated game UI asset: an open ivory cassette tape storage case / portable tape binder, on a genuinely transparent background. Use case: stylized-concept, in-game pause menu art. The case is a wide off-white rectangle occupying about 82% of the canvas, with a narrow hinged spine on the left, a large cassette inset on the right with two clearly drawn round tape spools and a tiny bridge between them. View almost front-on with a very slight perspective, like a casually drawn still life in a sketchbook. Minimal hand ink outlines with occasional tiny gaps and doubled strokes, restrained pale warm ivory fills, a little muted sage on the spine, dark charcoal contours. Clean broad untextured color areas. Strong readable silhouette, quiet indie game hand-drawn art. Render a single complete object centered, ample transparent margin. No other objects, plants, lemons, flowers, faces, words, logo, watermark, buttons or lettering. NOT photoreal, no 3D shading, no shiny surfaces, no ornamental flourishes, no heavy grain. Design at 1536x1024 landscape. Leave the upper right label area plain ivory for live text.
```

### ui_clipboard_gen

```text
Use case: stylized-concept. Create one blank management-game clipboard UI background asset, landscape 1536x1024. Flat 2D hand-drawn pen illustration. One large horizontal pale ivory sheet on a thin warm ochre wooden clipboard backing, covering 90 percent of the canvas. Subtly rounded intact corners, quiet irregular brown ink contour. A small simple brass clip at the top center, a little beige masking tape on top left and bottom right. The center must remain entirely plain pale warm ivory, at least 80 percent blank usable text area. Only extremely small faint sketched leaf sprigs at far outer lower left edge, no fruit. Style: delicate sketchbook linework with restrained large flat watercolor color blocks; calm sage, straw and warm ivory accents; not detailed, no grime, no random texture, no flourishes. No text, charts, slots, inner boxes, UI widgets, emblems, shadows, vignette, gradients, photographic or 3D appearance. Draw the clipboard fully visible with safe margins on a single absolutely flat solid pure magenta #ff00ff background for subsequent game asset keying; every outside pixel must be pure magenta. The clipboard itself has no magenta.
```

### ui_cassette_gen_final

```text
Edit this generated game asset. Keep exactly the open cassette case, its silhouette, left blank panel, right tape, linework and positions. Replace the ENTIRE background outside the case, including ALL shadows and glow, with absolutely uniform flat pure magenta #ff00ff. This is a chroma-key background, no shading or gradients permitted outside the object. Flatten the ivory and sage fills inside the object to mostly uniform quiet broad color blocks with very little material texture. Keep a hand-drawn pen quality with slight imperfections, but no extra ornaments. Do not add text or buttons. Only the single intact cassette case should remain on pure magenta. Preserve resolution and all object boundaries.
```
