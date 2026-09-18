# 摊主与争吵后续

## 实际入口

- 菜与罐头摊：BEETMAN 按原日程于 10:30—18:30 在摊边。靠近本人按 W 闲聊，按 1 提问。原柜台的直接购物热点已移除。
- 完整闲聊后，同一张对话卡提供“再聊一会儿 / 看看今天的罐头 / 问点事 / 先走了”。鼠标与方向键、Enter 均可操作。
- 打开商店免费，收起商店回到原谈话选择。每轮闲聊按统一配置计时；罐头和菜按商品标价付款，购买不追加谈话时间。350 ms 内重复购买输入只结算一次。
- 原菜摊争执保留六次记忆交换。结束后，阿禾和陈川分别成为 W / 1 可交谈对象；两人各有三组轮换闲聊，涉及蔬菜、面包、明信片、薄荷和天气。
- 原争执位置留下观察热点，可再次查看菜篮痕迹。两人在此停留 90 游戏分钟，再按各自日程去书店或杂货店，之后沿住宅区回家。后续相遇继续使用争吵后的对话池。

## 接线

`TownDay._interact → _talk_nearby → ConversationPanel → DialogueSystem.present_line → dialogue_line_presented`

`ConversationPanel.purchase_requested → TownDay._open_shop → ShopPanel._buy → GameState.buy_item → SaveManager`

`ShopPanel.tree_exited → ConversationPanel.resume_from_shop`

`StreetArgument.finish_requested → TownDay._finish_market_encounter → DialogueSystem.mark_argument → SaveManager`

`TownDay._observe_market_afterward → MetaExperience.observe(event_id=market_argument_finished)`

## 状态与角色

保留原 BEETMAN ID `beetman`。原扩展里的阿禾 / 陈川此前仅为台词名，现登记为 `ahe` / `chen_chuan`，沿用相同角色。原 100 位日程居民加这两个既有场景人物共 102 项；核心人物资料仍为 12 份。

争吵状态保存在 `shared_state.market_argument_A/B`，包含 seen、finished、day、minute。旧版 `market_encounter_<role>_<day>_done` 自动迁移。轮换进度保存在原 `linear_talk_counts_<role>`。照片、证明、收入等原系统保持原存储结构。

心声稳定目标：`beetman.greeting.0.0`、`maya.greeting.0.0`、`market_argument_finished`。每条真实对话信号都带 speaker_id、npc_id、location_id、event_id、dialogue_id、line_id、protagonist_id、time_of_day、flags/world_state。

## 验证入口

`tests/integration/test_patch_npcs.gd` 从 TownDay 的 W / 1 输入处理器验证聊天、商店、单次计费、原争执、两个单独后续对话、保存读档、限时停留与回归日程。与其他使用 `--isolated-save` 的测试串行运行。实际结果统一记录在补丁验收报告。
