# 试玩反馈修订 · 2026-09-22

## 已接入真实界面

- 菜谱：缩短左页编辑区、列表及操作区，给左下植物留出完整空间；长文字仍可滚动，草稿保存逻辑不变。
- 菜摊：柠檬更换为篮装手绘素材；调整货品位置，中文品名采用实色小标签，避免与货架横梁混在一起。保留真实价签、购物篮、结算和小票。
- 地图：新增方正、不透明的蓝色外框及暖白内衬；地点仍为动态 Control 节点。现有中文商店、商品、地点与料理提示在新窗口检查；缺少食材不再显示内部英文 ID，报销章也改为中文。
- 打字机：纸张和纸上的文字共同旋转 3°，对应机器的纸轴角度。导出文稿保持正常纸张方向。
- 鱼获：采用 FAO 的欧洲沙丁鱼及金头鲷资料，区分常见尺寸和大型个体。随机出现比例属于游戏设计，不冒充野外种群统计。真实鱼获保存长度、鱼种、时间、地点、收下/放生决定，并进入可滚动的海边笔记和档案素材。23.1 厘米沙丁鱼标为较大个体，不当作常见尺寸。
- 星云：保留原始高分辨率照片，新增连续三维表面与气体体积呈现；删除装饰星点天空。操作提示常驻放大、实色底；每片星云有四段科普/观测史和原始来源链接。相机环绕、缩放、各星云视角记忆、摄影及退出仍接原系统。模型来源及艺术重建区别见 `extensions/observatory/assets/nebulae/SOURCES.md`。
- 每日循环：未分享作品时，居民会点出真实作品并邀请展示；只有实际分享、听完后续，才记录收到作品。修正测试中的旧台词断言。

## 新插画来源

`art/ui/handmade/lemon.png` 使用内置 image_gen 编辑生成，参考项目原有 lemon/crates 插画。未添加文字或整页 UI，按钮与价签仍为原生节点。

最终提示约束：small shallow woven market basket holding three lemon-yellow lemons and two green leaves; chunky imperfect navy pencil and dry gouache matching the supplied lemon and crates; slight front/top view; straw basket occludes lower fruit; transparent background; no text, shadow or backdrop. 保留整体海蓝、柠檬黄、暖白手绘风格。

## 资料

- [FAO：欧洲沙丁鱼](https://www.fao.org/fishery/docs/CDrom/ARTFIMED/ArtFiWeb/descript/Species/CLUSAPIL.HTML)：常见 15–20 厘米，最大约 25 厘米。
- [FAO：金头鲷](https://www.fao.org/fishery/docs/CDrom/ARTFIMED/ArtFiWeb/descript/Species/SPASPAUR.HTML)：常见 20–50 厘米，最大约 70 厘米。
- 科普正文与游戏采样参数统一存放 `data/world/coastal_fish.json`，保留来源供后续核查。

验证采用独立存档：居民名册、购买、对话、每日循环、鱼获科普与存档、星云输入/拍摄/退出，以及真实窗口中的菜谱、菜摊、星云与阅读面板。英语翻译目录缺失为原有警告，本次未补齐全项目英文翻译。
