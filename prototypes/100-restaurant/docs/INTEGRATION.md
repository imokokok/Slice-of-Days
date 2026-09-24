# 接进主游戏

独立入口是 `demo_host.tscn`。可复用模块入口是 `res://modules/restaurant/restaurant.tscn`，根节点为 `Node2D`。正面料理台与食材使用 2D 物理和鼠标交互。宿主负责创建和释放模块、传入玩家上下文、接收结算；模块内部负责这一班的厨房操作与界面。

接入已有工程时，完整复制 `modules/restaurant/` 即可，保留目录内场景、脚本、UID、数据、字体和授权文件。`demo_host.gd/.tscn` 用于展示宿主调用方式，无需复制其钱包或路由实现。模块不注册 Autoload，也不调用全局场景切换；由宿主实例化、挂载和释放入口节点。

## 最小接入示例

```gdscript
const Restaurant = preload("res://modules/restaurant/restaurant.tscn")
var restaurant: Node
var paid_sessions: Dictionary = {} # 正式宿主要持久保存结算回执

func enter_restaurant() -> void:
    restaurant = Restaurant.instantiate()
    restaurant.configure({
        "player_id": "player_01",
        "display_name": "今日主厨",
        "shift_seconds": 240.0,
    }) # configure 必须在 add_child 之前
    restaurant.shift_completed.connect(on_shift_completed)
    restaurant.exit_requested.connect(leave_restaurant)
    restaurant.recipe_published.connect(on_recipe_published)
    restaurant.poster_published.connect(on_poster_published)
    add_child(restaurant)

func on_shift_completed(result: Dictionary) -> void:
    var receipt := str(result.get("session_id", ""))
    if receipt.is_empty() or paid_sessions.has(receipt):
        return
    paid_sessions[receipt] = true
    # 使用你的钱包 API；示例：wallet.credit(result.share)
    # 正式项目应在同一持久化事务中记回执并入账。

func leave_restaurant() -> void:
    restaurant.queue_free()
    # 恢复宿主场景、玩家控制器和宿主自己的鼠标状态。

func on_recipe_published(record: Dictionary) -> void:
    pass # 可用于成就提示或由宿主接入在线发布

func on_poster_published(data: Dictionary) -> void:
    pass # 把海报安排到世界广告位，由世界日程判断谁能看到
```

`demo_host.gd` 中有可运行的完整示例，示例钱包只在内存保存，不能直接当作正式经济系统。

## 上下文与事件

| 接口 | 内容与约定 |
| --- | --- |
| `configure(context)` | 在加入场景树之前调用；基本字段是 `player_id`、`display_name`、`shift_seconds` |
| `npc_profiles` | 可选顾客配置，具体结构见 `data/customers.json`；用于宿主传入当前可接待的人物 |
| `repository_path` | 可选自定义菜谱 JSON 存档路径；根模块会传给本地仓库，默认路径见下文 |
| `shift_completed(result)` | 携带 `session_id` 与领域结算数据；`share` 是需要给玩家的分成金额 |
| `exit_requested()` | 请求返回主游戏，由宿主释放节点并恢复场景 |
| `recipe_published(record)` | 一道完成保存的菜谱记录；主游戏可以监听成就或上传队列 |
| `poster_published(data)` | 发布的海报 JSON；主游戏可以创建公告栏内容或宣传任务 |

`session_id` 是防止重复支付的业务键。不要收到信号后再次乘以 30%；`share` 已是玩家分成。不要只用“当天 + 玩家”去重，因为同一天可能经营多个班次。正式钱包需要持久化回执与入账结果，使重新载入、重复信号、重试不导致重复赚钱。

## 模块边界

当前已验证的是演示宿主中的独占视口，虚拟画布为 1600×946，采用 `canvas_items` 拉伸。直接挂载示例假设宿主此时交出这个视口。若主游戏仍有活动 Camera2D、其他 2D 物理场景或不同画布尺寸，应在接入层使用隔离的 SubViewport / World2D 并保持 1600:946 的比例缩放，让小游戏的命中坐标和界面一起映射。不要让主世界相机移动厨房，也不要让主世界刚体与厨房碰撞；这种并存接入方式需在真实主项目中另行验证。

模块不要求 Autoload，也不使用全局场景树暂停来冻结主游戏。接入方应按自己的游戏流程暂停或禁用宿主角色输入，同时管理主游戏的时钟；关闭小游戏时恢复自己之前的状态。料理台通过可见鼠标拖拽物体，宿主的鼠标与 UI 状态应在退出与强制释放两条路径下正确恢复。

NPC 日程是主游戏的权威数据。海报只能让“可能路过、确实看见、并且有空”的 NPC 有机会到访。独立原型中的顾客到访规则用于演示；接入时把真实日程查询/事件接到宿主，不要把小游戏生成的到访结果直接当成主世界所有 NPC 的事实。

食材目录使用稳定 ID，显示名可以调整。做法与评价在 `domain/kitchen_session.gd` 中，存储独立在 `storage/recipe_repository.gd` 中，世界表现和界面不应该直接操作宿主钱包。这样替换料理台场景或做新美术时可以保留玩法与历史菜谱。

当前画面采用日间暖色、简化硬边几何。环境绘图在 `world/kitchen_backdrop.gd`，物理交互在 `world/kitchen_world.gd`。更换画面时保持砧板、锅、出餐口和食材架的可见位置与命中区域一致。刀具是独立工具节点，按住拖动、松手停止，释放发生在宿主 UI 上时也应正确收尾。

`assets/food_art.gd` 是可复用的 `Node2D` 食材绘制组件：设置 `definition`（食材目录中的字典）、`cut`（是否切过）、`heat`（加工热量），可由 `RigidBody2D` 作为父节点。绘图原点在中央，基础尺寸约 80×80 像素；物理碰撞由世界模块负责。绘制全部使用 Godot 原生线条、图形和着色，没有外部贴图依赖。

调料容器由食材数据控制：`dispense_mode` 为 `powder`（撒）、`pour`（倒）或 `squeeze`（挤），`dispense_mass` 是每批出料的千克质量。未配置出料模式的材料继续作为实体取放和切配；旧的最简番茄酱定义仍兼容挤压。新增调料时应一起配置模式、质量和颜色。容器有 `is_container` 标记，不进入料理、不占锅内容量，也不会被刀切；每批出料为独立刚体，带原食材 ID、`dispensed` 与 `dispense_mode`，通过既有 `food_entered_pan` / `accept_food` 回路落锅后才计入菜。每批占一份，画面上的细粉和液滴不单独占份数。

按住左键首批等待 0.35 秒，随后每 0.75 秒出一批；锅内和锅区在途份数达到 6 份后，额外调料进入台面溢出对象（`overflow`），不再进入菜品。相同调料的溢出复用一个污渍刚体、扩大图形，避免无限生成；放下容器后空手点击可清理。松开、移出锅区、失去焦点、禁用厨房控制、放下或抛出容器都会结束出料。宿主显示操作提示时可调用 `world.get_held_operation_hint()` 或 `world.ingredient_operation_hint(definition)`，不要按具体食材 ID 写死提示。`world.get_dispense_mode(definition)` 可供材料列表区分实体与容器。当前为批次刚体表现，不模拟连续流体与容器余量。

`mass` 表示容器/食材本体质量；可选 `dispense_mass` 默认 0.035，世界模块限制在 0.001–0.2，目录应提供有限的正数。质量当前用于物理表现，不是收费或口味加成倍率。调料批次沿用原食材的稳定 ID、标签、切配与热量记录，出料模式及质量属于目录配置，无需加入已存料理条目；现有 `dish.ingredients`、评分、装盘、菜谱保存和 JSON 交换格式保持一致。即使世界已预留锅内、待登记和在途份量，宿主仍须使用领域层的容量检查，并在回调中调用 `accept_food(body, accepted)`；拒收的批次会移出锅且停止释放。

## 存档、照片与海报

默认菜谱存档为 `user://after_hours_kitchen/cookbook.json`，首次为空。`user://` 由宿主工程名决定，因此接进另一个工程后数据目录也会改变；要继承演示数据，请使用 JSON 导出/导入，或由宿主安排显式迁移。

JSON 菜谱版本为 1，照片是内嵌 PNG base64，不携带作者电脑的本地路径。每道菜的自由拼贴布局保存在记录的 `poster` 字段，独立宣传海报也复用这一画布格式。字段、容量、校验边界、错误处理与仓库 API 详见 `modules/restaurant/storage/README.md`。现有文件损坏时仓库先尝试 `.bak`，不得忽略错误后直接重置玩家作品。

### 纸面作品的数据边界

`ui/poster_canvas.gd` 同时承载菜谱和海报编辑。新画布从空白纸开始，素材由玩家明确加入；标题、署名与做法元数据不会自动排到纸上。宿主应保留画布结构，读取时调用 `import_data()`，保存时使用 `export_data()`，以便重新编辑、展示和交换作品。

| 数据 | 保存内容 |
| --- | --- |
| `poster.version` | 当前为 `1` |
| `poster.strokes` | 归一化笔画点、颜色与画笔宽度 |
| `poster.stickers` | 按前后顺序排列的图层数组；包括食材、文字、照片和装饰贴纸 |
| 图层公共字段 | `position`、`scale`、可选 `rotation`；顺序由数组保留 |
| 食材图层 | `kind: "ingredient"`、稳定 `id`、`cut`、`heat`；用目录中的图形重建 |
| 文字图层 | `kind: "text"`、`text`、`color` |
| 胶带图层 | `kind: "tape"`；可选 `color`（HTML 十六进制，默认 `baa977`）、`length`（0.5–6，默认 1）、`width`（0.4–3，默认 1） |
| 照片图层 | `kind: "photo"`、`png`；图片内容为内嵌 PNG base64 |
| 可选 `mask` | 食材或照片的局部归一化多边形裁剪点，坐标范围 `[-1, 1]` |
| `poster.caption` | 兼容旧记录的文字字段；新画布不自动绘制成固定标题 |

图层位置归一化到纸面，缩放和旋转在重建时恢复；不要保存屏幕像素坐标、节点引用、纹理对象或作者电脑的照片路径。图层照片会缩到最长边 512 像素并内嵌，单层上限 512 KiB；最多 32 个图层，交换文件上限 16 MiB。布局校验由画布和仓库共同执行，导入方应检查错误结果。

画布提供 `add_ingredient()`、`add_text()`、`add_photo()`，以及选中图层的缩放、旋转、复制、移到底层和删除操作。选中会将素材图层提至上方；笔画统一绘制在素材上面，当前不参与素材的层序调整。裁剪模式在食材或照片上点选轮廓，Enter 或双击完成，Esc 取消未完成轮廓；`restore_selected_cut()` 恢复该素材的完整形状。只读展示设置 `editable = false`。这些作品操作不修改锅内食材、火候或收入。

菜谱 `thumbnail` 是另一个可选预览照片字段，不能替代 `poster` 中的可编辑布局。发布事件携带的是本地保存结果；自动上传、跨设备同步和合作者同时编辑需要宿主另外实现。

胶带使用本地 80×32 的几何基准；`length` 与 `width` 独立改变形状、命中区域和选框，`scale` 仍是整层缩放。`selected_tape_settings()` 返回 `{color: String, length: float, width: float}`，未选胶带时返回空字典；工具栏调用 `set_tape_color(Color)`、`set_tape_length(float)`、`set_tape_width(float)`。在滑块开始拖动或调色面板打开时调用 `begin_property_edit()`，结束时调用 `end_property_edit()`，连续变化合并成一次撤销。有限的工具输入会限制到上述范围，无效浮点数忽略；文件导入严格拒绝越界值。选择和修改会发出 `changed`，可据此同步工具栏。选择模式下胶带两端的圆点支持鼠标拖动拉长，松手结束；旋转后的胶带沿自身方向伸长。新增字段可省略，因此已有版本 1 作品仍可读入；导出和重新载入会保留这些字段。

菜谱也允许未做菜时创作：纯纸面记录使用 `dish: {"ingredients": []}`，但必须有实际笔画或素材层，且不附加料理评分。宿主不能把这种作品发布当作完成烹饪或产生收入。打开已有菜谱继续 DIY 时，保存修改会更新同一个 `id`，`recipe_published` 发出更新后的那条完整记录；请按 ID 更新作品，不要每次都当作新作品累计。另存为新菜谱才会创建新 ID。创建时间与本地喜欢记录在原 ID 更新时保留。

线上共享需要一个新的服务适配层。当前导入导出只交换文件；它没有登录、自动同步、多人会话或服务端点赞真实性。将来建议保留领域菜谱结构，另加远程 ID、作者权限、版本/冲突策略与上传状态，不要让世界场景直接依赖具体网络 SDK。

## 接入验收

锅铲由 `world/spatula_tool.gd` 管理，随厨房场景装卸，无额外 Autoload。铲头扫过锅内食物时，对现有刚体施加受限冲量和角速度，不新增食材、不改变质量或切配状态。力度按质量限幅；松键、失焦、打开模态界面时归位。使用锅铲时与持刀、持食材互斥，J/P/Tab/ESC 仍可进入对应界面；宿主暂停或覆盖厨房时应继续调用 `set_controls_enabled(false)`。这是鼠标扫掠接触驱动的刚体翻炒，不是完整锅铲网格碰撞或液体流体模拟。

1. 从主游戏进入、退出、强制关闭模块、再次进入，宿主控制器与鼠标状态都正确。
2. 服务顾客并结算一次，钱包只收到 `share`；重复同一 `session_id` 不会再次入账。
3. 更换玩家身份和顾客配置，署名与顾客偏好显示正确，世界日程仍归宿主管理。
4. 新存档菜谱为空，新作品纸面为空；加入食材、文字和照片，移动、旋转、缩放、调整顺序及裁剪后，保存、重启、导出、导入仍能重建相同布局、照片与署名。
5. 在另一台电脑用相同 Godot 版本导入源码运行，未依赖绝对路径或缺失的 `.godot` 缓存。
6. 在宿主 UI 上松开刀具或打开编辑器，刀停止拖动；菜谱和海报编辑期间，小游戏火候与顾客等待暂停，宿主时钟按宿主策略处理。

## 可移动锅、水量和声音（2026-09-08）

`world.pan` 为 `pan_controller.gd` 实例，负责二维自由拖动、水龙头、1500 ml 水量、加热到沸腾及倒水。锅壁列表、PanInterior 和 enrolled 的未装盘实体一起位移；松手、失焦及模态退出拖动。锅内物品保持原 physics_id。锅是受控拖拽物件，可倾斜倒出实际食物，松手受控下落；尚不支持容器间倒汤和任意碰撞翻滚。

所有锅区查询使用 `world.pan_rect()` 或 `world.pan.offset`，不要在新工具中写死炉灶中心。`session.heat_contact` 由适配层每帧取 `pan.on_stove()`；火仍开着时离灶食物不再累计受热。水温为快速煮沸的原型计时，不应解释为完整的真实摄氏温度模型。水满时继续接入的水流回水槽。水量记录到非空料理快照可选 `water_ml`，范围 0–1500，旧存档缺省 0；纸面素材栏可主动加入水量文字，画纸仍不预填。

`world.audio` 独立控制本模块播放器；`muted`、窗口失焦和 `controls_enabled` 限制连续声音，不修改 Master 总线。音效事件、素材来源和替换方式见 `AUDIO.md`。

`customer_review.gd` 根据真实食材目录和本次快照生成本地编写的评价。顾客可设置 `review_voice`：tired、old_critic、excited、fresh、chef、sweet、deadpan、regular；未知值按 kind 回退。出餐结果增加 `detail`、`reaction`、`role`、`reason`，旧的 score/payment/feedback 保留。反应文字不替代未来 NPC 表情动画；评分及收费规则沿用现有模型。

## 放大工作台与本轮状态字段

- `ui/cutting_canvas.gd` 只映射现有台面刚体，在模态期间冻结；退出恢复，`world.split_food(body, normal, world_cut, max_depth)` 接受可选切口位置，旧两参数调用不变。
- `ui/plating_canvas.gd` 维护实物位置与 `dish.ingredients[].plate_position`（归一化 x/y）、`plate_rotation`（弧度）。`dish.presentation.strokes` 为归一化点列，`garnish: true` 的条目有 `amount_ml`；固体六份与摆盘酱汁 120 ml 的限额分开。
- `pan_controller` 提供二维 offset、angle、实际重力落台与倾倒，旧标量 move_to 调用仍支持。`off_heat`、`physics_id` 为运行时数据，保存菜谱时剔除。
- 模态不暂停宿主 SceneTree。餐盘照片由独立 SubViewport 生成，640×357 PNG，作为本地菜谱 thumbnail 与可选纸面照片素材。无摄像头、上传、自动发布。
- 背景保存在模块 assets 内；不依赖个人电脑的参考图路径。字体、背景、音频随模块一起交付。

## 有符号结算与等待时间

当前顾客统一等餐 120 秒。评分低于 20 会扣赔偿，超过 80 才产生随机小费。result.share 是净收入的 30%，可能为负；宿主钱包必须支持扣款并按 session_id 防止重复结算。不要再次乘分成比例或把负值截成零。
