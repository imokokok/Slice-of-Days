# 内容录入格式

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

## 剧情事件

建议每个事件稿件使用以下字段：

- `id`：不可重复的稳定标识。
- `conditions`：日期、时间、地点、视角、已知事实、前置事件。
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

## 灰盒玩法

`data/gameplay/modules.json` 登记稳定玩法ID和场景入口；`data/gameplay/module_prototypes.json` 保存灰盒选择、成本与结果。正式美术和更复杂的交互可以替换工作台场景，但应继续通过同一结果结构写回关系、日记、作品和玩法状态。

## 美术资源

推荐命名：`角色或地点_用途_版本`，例如 `xia_touming_portrait_v01.png`。人物、地点和 UI 分开存放；源文件与导出文件不要混在同一目录。

首轮占位资源允许替换，但不要改动代码和数据中的 ID。这样后续文本、美术和 UI 跟进时，可以逐项充实而不推翻系统。
