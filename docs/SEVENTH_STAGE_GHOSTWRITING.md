# 第七阶段：第五天代写委托

## 目标

让代写工作台的句子选择真正进入剧情，而不是只在模块结果中留下不可见的 token ID；同时把“完成得正确”和“保留说话者自己的声音”分成两种不同结果。

## 可玩流程

1. B在图书馆见到迟迟没有寄出信的委托人。对方要求信不要写得太好，因为过于完整的表达不像自己。
2. 玩家从五块句子中按顺序挑出三块。顺序会连同标签一起写入模块结果。
3. 选择“先听完整，再裁切排列”会消耗完整时间，并在下一段时间触发第三次删改。
4. 删改场景通过 `{selected_1}`、`{selected_2}`、`{selected_3}` 读取玩家真正选择的句子，委托人会原样读出这份初稿。
5. 玩家可以删掉过于完整的连接、保留说话人的停顿；这会获得委托人和Sunniva的认可。
6. 玩家也可以保留准确清楚的版本。信可以寄出，但委托人拒绝认可，Sunniva保持考虑。
7. 选择快速成稿时，委托会按时完成，但委托人的认可保持待定，等待以后重新听完整。

## 动态回响机制

`GameplayModuleSystem` 会为每次模块结果保存 `selected_tokens` 与 `selected_labels`。`EventSystem.resolved_presentation()` 根据事件的 `module_echo.module_id` 读取最近结果，并递归替换文本中的选择占位符。

这一机制不只服务代写。后续可以用于：

- 在结局重放玩家选择过的菜材、声音与句子。
- 让居民针对玩家实际留下或排除的项目回应。
- 让同一场景保持固定逻辑，同时替换正式对白与 token 展示名。

## 内容入口

- 入场与删改事件：`data/story/events.json` 的 `b_d5_ghostwriting`、`b_d5_letter_revision_listen`、`b_d5_letter_revision_efficient`。
- 句子卡与工作台结果：`data/gameplay/module_prototypes.json` 的 `ghostwriting`。
- 动态文本替换：`scripts/core/event_system.gd`。
- 模块结果标准化：`scripts/core/gameplay_module_system.gd`。
- 图书馆写信背景：`art/locations/library/library_letter_revision_v01.png`。

## 下一步

把动态回响接入第七天结局，让菜谱材料、声音授权、代写句子、错过的预约与关系修复分别出现在A/B的最后记录里，而不改变通过与失败的基础判定。
