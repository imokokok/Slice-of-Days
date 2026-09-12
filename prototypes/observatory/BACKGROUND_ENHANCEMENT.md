# 观景台背景清晰度增强

工具：内置 image_gen，编辑模式。
输入：assets/background/observatory_scene.jpg（1536×628）。
输出：assets/background/observatory_scene_hd.png（1961×802）。
提示词目标：增强分辨率、恢复清晰边缘和细致笔触，保留原图全景比例、构图、夜景色彩、暖灯、文字、座椅、植物、幕布及望远镜的相对位置；不裁切、不重新布局、不增加物体、不转写实风格、不添加锐化光晕或景深模糊。要求最高可用分辨率，理想尺寸 3840×1568；实际返回为 1961×802，因此不宣称 4K。

增强包含 AI 补绘，不保证所有局部细节与原图完全相同。源 JPG 未被覆盖；游戏保持 16:9 等比裁切显示。

## 实际发送的提示词

Edit target: the provided observatory game background. Restore and enhance image resolution and edge detail, output at highest available resolution ideally 3840x1568 (same 1536:628 panoramic aspect). This is a faithful clarity restoration for an existing 2D game, NOT a redesign. Preserve EXACT composition, camera framing, every object's relative position, silhouettes, colors and original hand-painted illustration style. Particularly preserve the projection screen quadrilateral at normalized corners (0.48177,0.30732), (0.66927,0.28822), (0.66927,0.56529), (0.48177,0.56210), and the telescope at right around x=.84 y=.71 because interactive elements are aligned to these. Improve clearly resolved foliage, stone edges, wooden chair grain, cushion fabric, lantern metal and telescope detail, restore coherent fine brushwork without blurry JPEG smearing or pixelation. Keep warm soft lantern light and navy night sea, original buildings and sea reflections. Preserve all existing lettering and the moon as closely as possible, no added text, objects, stars, characters or props. No cropping, no re-layout, no oversharpened halos, no photorealistic style conversion, no depth of field blur. Deliver the single restored background image.
