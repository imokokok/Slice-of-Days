# Solmere 窗边拼贴工作坊

2026-09-20 版本按用户提供的桌面参考图和《Letter & Collage Workshop》规格实现。原图保留于 `assets/reference-desk.png`；空桌底图与独立物件通过内置图像编辑工具提取、补全，生成提示词记录在 `assets/ARTWORK.md`。透明 PNG 可独立移动，不需要背景色抠像。

## 运行

Solmere 主项目继续通过「代写与拼贴书信」进入。`../Main.tscn` 加载本目录控制器，宿主以独立 1600×900 视口缩放绘图、UI 和输入，返回条在游戏画面之外。

独立源码位于仓库 `prototypes/collage-letter`。使用 Godot 4.5.1+ 打开其 `project.godot`，或运行其中的 `server/launch.py`。完整 Windows 包由本机交付，运行时不纳入 Git。

## 桌边操作

- 左侧素材架 / Materials：按类型浏览 50 张纸张素材与 4 种干花装饰，左右翻页，拿到桌上。
- 干花：在 Materials / 素材中选择「干花」，包含薰衣草、洋甘菊、蕨叶、粉玫瑰；取出后放在信上，可拖动、旋转、缩放与调层级，透明边缘无纸底。装饰随草稿保存，并合成到折信与寄信图像中。assets/flowers/ARTWORK.md 记录内置 image_gen 工具的完整生成提示词。
- 纸片：拖放；Q/E 旋转；滚轮缩放；[/] 调层级；Delete 删除选中的裁片；Ctrl+Z / Ctrl+Y 撤销重做。
- 剪刀：可按住拖到桌上其他位置，或拖到纸上使用；也可先选纸再点击剪刀。Shift 拖动两端调整虚线，从起点按住沿线移动。两边均保留为可操作纸片。
- 刻刀：刻板固定在左下原位，点击不移动、不放大；把纸拖到刻板，再拿刻刀。快速从纸外划过纸面、在纸外松手也能裁开。闭合路径挖出局部并留下透明孔洞；从纸边到另一纸边分开纸张。
- 胶带：按住拉出，松开仍与卷相连，再点击左下剪刀剪断。裁下的胶带可移动、旋转和覆盖纸片。
- 笔：点击后按住在纸上写画，右键切换两种笔宽，Esc 放回；墨迹随纸张移动和裁切。
- 打字机：直接敲键盘，支持空格、退格、回车和 Ctrl+V；每个字依次落墨，配合同步按键和音效。中英文按实际字宽换行，预览与抽纸共用排版；SAVE 会等队列打完再抽出可裁切的打字纸。打字草稿（含待打印内容）自动保存。
- 完成：下缘向上折、上缘向下折；拖入信封、下拉带原画纹理的信封盖，封蜡继续使用同一信封；火柴在盒侧划动后点灯芯；勺子舀蜡、放到火上约六秒；移至封口倒蜡；印章压一秒后抬起；冷却后才出现 SEND。
- Esc 返回桌面；专注操作时其他工具不响应。进入邮局后桌面停止响应输入。

## 草稿与联机

工作坊使用独立 `user://workshop_v3.json` 草稿，保留旧版 `letter_v1.json`。每张纸保存透明图像、位置、旋转、缩放、层级、裁切历史、笔迹和胶带标记。撤销保留最近 20 步。

Letters 进入原有漂流瓶邮局。历史信可回复，发新信后必须回复其他人的信才能再发；服务端规则、并发控制、身份与重试幂等机制继续有效。默认启动本机服务，可部署到局域网或公网；本版本不提供已经上线的公共服务器。

## 代码与验证

`interactable_object.gd` 提供交互基类；`tool_object.gd` 处理实体工具与悬停；`paper_object.gd` 处理透明纸面、真实分割、绘画和序列化；`workshop.gd` 是显式模式状态机；`workshop_overlay.gd` 绘制在纸片上方的工具和裁切路径。胶带与打字纸复用 PaperObject，新增纸张以数据配置为主。

测试必须使用可渲染显示器（不要加 `--headless`）：

```sh
godot --path . --script res://tests/integration/test_letter_workshop.gd -- --workshop-test --fresh
godot --path . --script res://tests/integration/test_workshop_tools.gd -- --workshop-test --fresh
godot --path . --script res://tests/integration/test_typewriter.gd -- --workshop-test --fresh
godot --path . --script res://tests/integration/test_collage_viewport.gd -- --workshop-test --fresh
```

覆盖：素材翻页、纸片分割/镂空、撤销重做、刻板前置条件、胶带剪断、笔迹、打字纸、三折/装封、融蜡计时、印章与发送门槛、草稿恢复、宿主缩放及真实鼠标事件转发。`--workshop-test` 不写玩家草稿。

视觉采用透明图、Tween、路径和纸面遮罩；火漆为分阶段动画，音效为轻量程序合成。未使用刚体、布料或流体模拟。
