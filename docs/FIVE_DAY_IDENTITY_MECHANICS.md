# 五日身份认知与跨领域机制

本轮只扩展游戏状态、反馈与验证，不修改角色动画或正式美术。

## 身份认知

NPC 的共享记忆保存在 `GameState.shared_state.npc_memory`，认知状态依次为：

1. `unseen`
2. `assumes_same_person`
3. `notices_inconsistency`
4. `suspects_two_people`
5. `identity_confirmed`

每次推进同时保存日期、当前角色和证据。旧存档若只有 `perceived_same_person`，读取时会推导对应阶段；兼容字段继续保留。

Day 3/4 的认知不能由重复点击同一物件触发。玩家必须查看两种不同 `view_kind` 的真实生活物件；Day 3 使用菜谱与小票，Day 4 使用唱片与信件。观察到的物件 ID、种类和标题由 `ChapterSystem.observation_summary()` 提供。

Day 3/4 的主线谈话会让当前角色选择“当场说明误认”或“先保留疑问”。选择按角色与 NPC 写入 `five_day_story.identity_responses`，同时进入私人关系标记、选择历史与日记。选择不会成为通关条件，也不能在后续被静默覆盖。

Xanni、石泳琪、Mossner、闹闹各有按认知阶段编写的反应。普通交谈只播放当前阶段尚未听过的反应；身份确认后的台词还会回收玩家此前选择立即说明还是等待见面。

## 第五天会面

会面对白从双方实际查看过的物件和 NPC 当前认知阶段生成。对白进度继续写入 `meeting_beat`，中途离开后可以恢复；只有最后一次确认会揭示身份并开放角色切换。

## 跨领域尝试

身份揭示后，每个角色第一次完成原本属于另一角色的主玩法时，结果写入 `craft_perspective = cross_domain`，并记录到 `five_day_story.cross_domain_practice`。重复完成同一玩法不会重复写入首次记录。

右侧引导会为尚未尝试的角色推荐一次跨领域活动。该活动完全可选，不影响结束旅程，也不改变双方私有钱包、物品、关系和草稿的隔离规则。

## 结局回响

结局从真实存档生成三组内容：双方留下的公共作品、四名主线 NPC 的最终认知与回应、身份揭示后的跨领域尝试。未进行跨领域尝试时会明确显示为可选留白，不会伪造完成记录。

## 验证

```sh
godot --headless --path . --script tests/integration/test_five_day_identity_mechanics.gd -- --isolated-save
godot --path . --script tests/integration/test_five_day_flow.gd -- --isolated-save --fresh
godot --headless --path . --script tests/integration/test_five_day_flow.gd -- --isolated-save --reload-only
```

新增纯状态测试覆盖重复观察、证据种类、NPC 阶段、回应不可覆盖、一次性阶段反应、动态会面、身份确认、跨领域去重、结局数据和英文结局渲染。完整五日窗口测试继续覆盖真实录音、采购烹饪、拼贴信、棋局、保存与安全切换。
