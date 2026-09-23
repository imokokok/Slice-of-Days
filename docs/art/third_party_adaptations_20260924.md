# 锅具改造记录 · 2026-09-24

用户认可 Little Chef 的厨房画风，同时要求部分器具改变形状，避免照搬全部素材。保留原有场景、随身图标与切菜操作。

源素材：hello erika / Little Chef，`Sprites/Sprites/Environment/Pot/pot_base.png`。完整来源、下载包哈希及使用条款见 `THIRD_PARTY_LICENSES.md` 与 `data/presentation/resource_manifest.json`。第二张风格对照为本项目已批准的 `art/ui/pocket_doodles/kitchen_objects.png`。

方式：使用内置 imagegen 的图像编辑，根据上述两张实际图片生成透明背景锅具前景层。不是用程序绘制替代生图，也没有使用用户排除的旧参考包。

编辑指令归档摘要：

> Keep a front-occlusion sprite with two handles and an open upper edge; no interior ellipse, lid, food, spoon, scene background or detached ground shadow. Replace the three daisies with two simple ivory bands along the lower body. Use muted sea teal for the pot and soft terracotta for rim and handles, a fine warm-brown irregular ink outline, clear large color blocks and only subtle brush variation. Make the silhouette slightly wider and squatter. Keep true alpha; avoid a 3D render, grunge, text and logos. Retain the source attribution.

结果：`art/ui/third_party_adapted/solmere_pot_front.png`，1467 × 1072，RGBA。花朵装饰改为两条米白带，锅身海绿、手柄陶土色。保留来源归属，不将派生图标为与原素材无关的原创。

运行时适配：`scripts/ui/components/cooking_pot.gd` 用真实食材、后锅沿、勺子与这张前景层装配；锅前景遮住食材/勺子的下部。用户点选食材、切菜、拌匀、出餐与库存保持同一状态链。实窗检查后下移后锅沿，修复后层浮在锅上方的接缝。

原图 SHA-256：`fadd9b72c564e628b4ea6382938bb6c071f47dacb8397c9fdb43f3baed686eb6`

改后图 SHA-256：`a34da07a2a391d5a3e8778151a36ef15069805a787f3611d9cf1fb704e187b2d`

生成原件保留在本机 Codex generated_images 中；正式项目使用上面的确定文件名。
