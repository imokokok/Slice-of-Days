# 内容录入格式

## 主角设定

`data/story/characters.json` 保存 A/B 的稳定人物骨架。`role` 不可修改；正式角色姓名确定前继续使用 A/B。当前界面会读取 `job_title_zh`，其余字段供剧情、美术和后续对白统一口径：

- `background`、`ambition`、`inner_tension`、`reason_for_solmere`：角色经历与行动动机。
- `work_habit`、`life_habit`：事件选择的行为边界。
- `visual_direction`：服装、随身物与体态方向，不等同于最终设计稿。
- `memory_motifs`：允许反复出现的私人记忆意象。
- `portrait_path`：正式立绘路径；留空时界面继续使用占位表现。

具体对白无需写进人物表，应继续按场景写入事件的 `presentation`，这样可以单场替换和校对。

## 居民

每位居民至少需要：稳定 ID、展示名、七日日程、所在地点、活动描述。日程允许留白；留白表示玩家无法在公共地点遇见该居民。

```json
{
  "id": "resident_id",
  "display_name": "居民名",
  "schedule": [
    {"id": "activity_id", "days": [1, 3], "start": 1080, "end": 1200, "location": "park", "activity": "散步"}
  ]
}
```

十二名主要居民的叙事骨架独立存放在 `data/npcs/core_residents.json`，用同一个居民 ID 与日程关联。可替换字段包括：

- `town_role`、`public_face`、`private_pressure`：身份、外在状态与隐藏压力。
- `recognition_basis`、`refusal_basis`：专属认可和拒绝场景的写作依据，不是公开数值条件。
- `voice`：正式对白的语气约束。
- `role_lens.A` / `role_lens.B`：同一居民如何分别理解两位主角。
- `recurring_image`：立绘、道具和环境叙事可以反复使用的视觉母题。
- `ambient_lines.A` / `ambient_lines.B`：公共地点短交流的可替换占位台词。

界面只按稳定 ID 查询这些资料，因此更换名字、职业、台词或人物美术不需要修改事件条件与存档。核心居民使用专属事件决定认可，日程里的 `draft` 应保持为 `false`。

## 剧情事件

建议每个事件稿件使用以下字段：

- `id`：不可重复的稳定标识。
- `conditions`：日期、时间、地点、视角、已知事实、前置事件；预约事件可填写 `required_appointment`。
- `cost`：分钟、金钱或关系代价。
- `presentation`：对白、旁白、镜头、声音提示。
- `results`：新增事实、关系变化、居民确认、后续事件。
- `choices`：可选回应；每项可以有自己的时间、金钱、表现和结果。
- `launch_module`：进入独立玩法工作台，例如 `cooking`、`translation` 或 `tarot`。

事件结果目前支持：

- `facts`、`completed_events` 和 `reveal_schedule_entries`。
- `encounters`、`relationship_flags` 和 `confirmations`。
- `journal_entries`、`appointments` 和 `artifacts`。
- `unlock_modules` 和正向金钱变化。

认可状态使用 `unknown`、`pending`、`granted`、`refused`、`withdrawn`，不要用一个公开好感度数字替代具体经历。

`draft: true` 表示居民可以使用通用认可请求流程；主要角色或需要严格叙事控制的居民应使用 `draft: false`，并通过专属事件改变认可。不要为了让主要角色快速可用而临时改成草稿居民。

大量灰盒居民可以放进 `generated_roster`：`start_index` 与 `id_prefix` 共同生成稳定 ID，`display_names` 决定展示名，`schedule_patterns` 按顺序循环分配日程。当前第 33—100 号居民采用这种方式。正式替换某位居民时必须保留其 `town_resident_XXX` ID，否则旧存档里的关系记录将失去对应对象。

带 `choices` 的事件完成后，系统会按 `事件ID/选择ID` 把选择写入当前角色的 `choice_history`。结局回声和后续条件可以读取这个稳定键，因此发布后不要随意改动已使用的选择 ID。

`presentation.lines` 兼容纯字符串旁白，也支持对白对象：`{"speaker": "角色名", "text": "对白"}`。无说话人的叙述只填写 `text`。`presentation.image_path` 可挂载该场景的正式插图，并以低透明度作为事件卡背景。这样正式文本和美术都可以逐场替换，不需要修改事件弹窗代码。

需要以舞台式节奏逐句展开的主要事件，可以增加 `presentation.beats`：

```json
"beats": [
  {"direction": "站台上没有列车。", "text": "她提前六分钟抵达。"},
  {"speaker": "旧站看守", "text": "要把多出来的十一分钟也等完吗？", "direction": "分针停在原处。"}
]
```

`text` 是必填正文，`speaker` 与 `direction` 可省略。界面会逐拍显示这些内容，在最后一拍之后才展示事件选择或执行结算。正式文本可以逐场增加 `beats`；没有该字段的事件仍沿用原来的整页事件卡。

后续场景需要复述玩家在玩法工作台选择的内容时，可以在 `presentation` 增加：

```json
"module_echo": {"module_id": "ghostwriting"}
```

随后在标题、摘要、节拍或结果文本中使用 `{selected_1}`、`{selected_2}`、`{selected_3}`、`{selected_joined}` 与 `{module_choice}`。事件打开时会从该角色最近一次模块结果读取真实标签并替换；模块系统会在结算时自动保存标签，因此测试或其他界面直接调用玩法也不会丢失回响内容。

预约至少填写稳定 `id`、`day`、`start`、`end`、`location` 和 `label`。承接预约的事件应与预约使用同一 ID，并在条件里填写同一个 `required_appointment`。系统自动维护 `scheduled`、`active`、`completed`、`missed`，内容数据不要手动跳过这些状态。

## 灰盒玩法

`data/gameplay/modules.json` 登记稳定玩法ID和场景入口；`data/gameplay/module_prototypes.json` 保存灰盒选择、成本与结果。正式美术和更复杂的交互可以替换工作台场景，但应继续通过同一结果结构写回关系、日记、作品和玩法状态。

每个灰盒玩法还需要一个 `interaction`：

- `prompt`：进入桌面后要完成的具体操作说明。
- `mode`：`ordered` 表示选择顺序有意义，`toggle` 表示只记录保留了哪些项目。
- `min_select` 与 `max_select`：结算按钮解锁前需要选择的数量。
- `tokens`：可操作的材料、句子、声音、观察点或记录；每项使用稳定 `id`、展示 `label` 和说明 `detail`。
- `progress_steps`：可选；按已选择数量显示的过程反馈。若最多选择三项，应提供从零项到三项共四句反馈。
- `icon_path`：可选的正式美术图标路径。

玩法根节点可以使用可选的 `background_path` 替换工作台背景。操作结果会把玩家选中的 token ID 一并写入玩法 outcome，方便后续对白、作品名称、音轨或构图引用。

玩法结果还可以使用 `required_tokens` 与 `forbidden_tokens` 限制某种结算。例如可交付音轨可以禁止未授权人声；被禁止的组合会让对应结果按钮不可用，核心系统也会再次校验，不能通过绕过界面直接结算。`constraint_note` 用于说明不可用原因。

## 结局回声

`data/story/endings.json` 的 `echoes` 会从 A/B 各自存档匹配已经发生的经历。每条回声需要稳定 `id`、`category`、`priority`、正文 `text`，以及至少一种条件：

- `choice_key`：匹配 `事件ID/选择ID`。
- `journal_id` 或 `journal_kind`：匹配具体日记或某类日记。
- `artifact_id`：同时查询角色私人物件与公共作品。
- `module_id` 与可选的 `module_choice_id`：读取某个玩法最近一次结果。
- `role`：可选；限制只查询 A 或 B。省略时依次查询两人。

玩法回声正文支持 `{selected_1}`、`{selected_2}`、`{selected_3}`、`{selected_joined}` 和 `{module_choice}`；日记与作品还可以使用 `{journal_text}` 和 `{artifact_title}`。多个条件写在同一条回声时必须同时满足。`one_per_category` 会防止同类记录挤占结局页，`max_echoes` 控制最多显示数量。

## 美术资源

推荐命名：`角色或地点_用途_版本`，例如 `xia_touming_portrait_v01.png`。人物、地点和 UI 分开存放；源文件与导出文件不要混在同一目录。

首轮占位资源允许替换，但不要改动代码和数据中的 ID。这样后续文本、美术和 UI 跟进时，可以逐项充实而不推翻系统。
