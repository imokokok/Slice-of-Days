# 2026-09-25 手写订单与纸面 DIY

本轮对应用户要求：订单像纸上的手写叮嘱；DIY 主要通过落笔、涂鸦、拖放贴纸、食材和照片完成；输入过程与纸面成品保持统一。沿用 Little Chef / Venba / Cooking Simulator 分工及现有厨房、物理和团队原画。

## 已实现并验证

- 订单使用不规则纸边、细纤维纹理、折角、半透明胶带和中文手写字体。原始需求、已了解的偏好、习惯与所点菜谱保留；点击纸条可拿近阅读完整内容，同时暂停厨房。长姓名和长正文不会覆盖相邻控件。
- 菜谱与海报共用手作桌：大纸页、笔/剪刀工具、十类图形贴纸及这一餐实际用料。贴纸、食材和已拍照片可以拖到纸上；图层可直接移动、拉伸、旋转、剪裁，保留复制、删除、调整前后关系和胶带长度/宽度。食材拼贴不消耗或更换实际锅中食物。
- 三种笔触：细笔、铅笔、宽笔。笔画记录笔触种类，旧笔画仍能读取；支持整体撤销/重做，输入框内保留原生文本编辑。
- 选择“纸上写字”在纸上落笔，双击字迹直接改写。编辑和展示使用同一字体、同一原生 TextEdit 排版，不额外弹出输入表单；换行向下增长，不把前面的字重新居中。标题、做法和署名也直接在纸面输入。中文、换行、光标、选择和输入法合成由 Godot 原生文本控件处理。
- “先收起纸页”在本次游戏进程中保留草稿，按菜谱 ID 隔离；保存成功才清掉对应草稿。永久保存仍需“收进我的菜谱 / 保存修改”。只有名字的空白页仍拒绝保存；在纸上写下做法后，不必额外添加装饰才能保存为 DIY 页，也不会伪造已烹饪食材。
- 照片来自真实摆盘渲染或玩家导入的图片。已有摆盘照片作为可拖动素材出现；没有实际照片时明确提示先去装盘台拍摄。书架、展开页、离线分享继续使用同一份纸面数据，保存后可逐图层继续编辑。

## 本轮发现并修复的问题

| 问题 | 修正 |
| --- | --- |
| 原客户需求只是平面色块，纸条读不下长需求 | 有纹理纸面、正文省略及完整阅读入口 |
| DIY 编辑依赖把标题/做法再“加入纸面”的按钮 | 标题、做法直接写在纸上，自由文字原位编辑 |
| 新增原位输入时，旧控件的延迟失焦可能结束下一段编辑 | 失焦提交绑定原编辑控件身份 |
| 新增空白文字后立即删除可能删掉别的素材 | 提交/取消空文字后重新检查选择有效性 |
| 多行文字增加高度时旧字迹向上跳 | 保持首行位置，按图层变换补偿中心 |
| 收起未完成菜谱会丢失当次工作 | 当前进程草稿按作品身份恢复 |
| 较小窗口的海报底部操作溢出 | 读取旧稿与发布操作并排，复验 1600×900 布局 |
| 订单等待字段本是剩余耐心，误读为已经等候时长 | 明确显示“还能等”倒计时 |
| 原心情图标高心情反而呈皱嘴 | 修正嘴部曲率与眉线方向 |

## 验证及边界

证据在 `qa/20260925-paper-craft/`。实际生产场景运行；测试使用独立菜谱库，不上传玩家私人作品。

| 检查 | 结果 |
| --- | --- |
| 新纸面交互专项，headless | 38 项通过 |
| 新纸面交互专项，RTX 4050 / OpenGL | 44 项通过，含实际食物装盘、拍照、加入纸面 |
| 菜谱创建/编辑/另存/重开 | 76 项通过 |
| 共享手作工具、胶带操作 | 30 / 75 项通过 |
| 引擎 GUI 输入、拼贴数据 | 68 / 39 项通过 |
| 纸面存档 | 30 项通过 |
| 完整流程、跟做、切配/清理/分享、窗口与操作舒适性 | 124 / 40 / 86 / 90 项通过 |
| 海报存档及存储 smoke | 两个入口通过 |

实际查看 `final-order.png`、`final-order-open.png`、`final-writing.png`、`final-desk.png`、`final-reader.png`。输入中与结束后的文字变换、中文换行、双击重新编辑、取消、清空、撤销重做、草稿隔离、食材状态保留、照片图层、旧笔画兼容及同源展示均有断言。集成测试从旧“加标题/放大/右转”按钮更新到新输入入口；拖拽变换另由原 68 项 GUI 输入测试覆盖。

Windows GPU 下，Godot 原生拖放使用系统鼠标位置解析落点，合成事件的落点会被真实鼠标位置影响。没有为了测试移动系统鼠标：完整合成拖放及落点在 headless 校验；GPU 校验拖放数据后，对生产 `_drop_data` 传入明确纸面坐标生成可复现截图。该证据不是人工鼠标拖放验收。照片额外使用实际已装盘物体生成，截图中不是预制成品图。

已实现但未人工验收：Windows 中文输入法候选词选择、不同 IME 合成/撤销、持续人工拖放与长时创作。系统候选窗外观由 Windows/输入法控制，不能声称已改成游戏手绘风。游戏内文本控件样式和输入后的排版已统一。未完成草稿仅在当前游戏进程内保留，退出后必须依赖已保存菜谱；未新增在线作品社区或云同步。

## 新素材来源与许可

### 字体

- [LXGW WenKai Lite 官方仓库](https://github.com/lxgw/LxgwWenKai-Lite)，固定版本 v1.522。
- [字体原始下载](https://github.com/lxgw/LxgwWenKai-Lite/releases/download/v1.522/LXGWWenKaiLite-Regular.ttf)，存于 `modules/restaurant/assets/fonts/lxgw_wenkai_lite.ttf`，没有修改字体。
- [官方 OFL 文本](https://raw.githubusercontent.com/lxgw/LxgwWenKai-Lite/v1.522/OFL.txt)，存于 `modules/restaurant/assets/fonts/LXGW_OFL.txt`。OFL-1.1 允许随游戏使用与分发，保留版权及许可；Windows 包附同名许可，导出资源也包含许可。
- 字体 SHA-256：`140c99ba4e28e817cec49bf82a0c5fcdc4fe633fb9dfda16d0ee8d59a8545f15`。
- 许可 SHA-256：`c38b1994a5e48ac30ac7d1da7d0409fd8fd8127dfe28a13d6e787d5b1ef34a5e`。
- 罕见字使用项目原有 Noto Sans SC 回退。

### 纸张纹理

`modules/restaurant/assets/paper/ivory_fibers.png`，1536×1024，使用内置 imagegen 新生成的空白纸面；没有编辑、替换或重绘团队食材原画。运行时叠加低对比暖色以保证可读性。SHA-256：`8635797d7c22c97460a2621375d0fa050586af38f6e1a84906bb9d8d1be3c066`。

完整实际提示词：

> Create a production game texture asset, a single flat unmarked warm ivory handmade writing-paper texture that fills the ENTIRE rectangular image edge to edge. Landscape 3:2 composition. Fine physically believable visible cellulose fibers, subtle uneven warm cream tone, gentle faint pressed grain, a few tiny embedded beige fibers. Warm restrained hand-crafted kitchen journal aesthetic, matte, soft daylight uniformly illuminating it, near-flat values so dark handwritten Chinese text remains very readable over every part. No objects, no lettering, no lines, no stains, no decorative illustrations, no border, no shadow, no vignette, no perspective. This will be mapped to independently drawn irregular paper silhouettes and must function as a close-up paper surface, not a photograph of a sheet resting on a desk. Save a raster texture.
