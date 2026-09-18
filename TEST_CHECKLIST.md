# 验证记录

最新结果见 docs/FINAL_TEST_RESULTS.json，各轮日志在工程旁 final_regression_test_*.log。测试均使用 --isolated-save，按顺序运行。

| 脚本 | 验证范围 |
| --- | --- |
| test_final_runtime | 七日纸张、资料领取、实际证明、营业时间、去重、归档、居民签记、截止提交、角色隔离、界面 |
| test_final_tools | 实际截图 PNG、实际声景 WAV、录音标记、地图暂停、桌面拖放、Home |
| test_final_calendar | A/B 全十四章、每人七日记录、修订保留、工作分钟数、波形读数 |
| test_feedback_systems | 收支、背包、照片去重、工具输入与既有反馈 |
| test_network_vertical_slice | 场景路线、NPC 日程、实际聊天计时、手帐、旧存档迁移 |
| test_walking_journey | 走路、住宅入口、实际床位、入睡转场、小游戏返回 |
| test_native_modules | 既有原生小游戏 |
| test_linear_dialogue | 连续对话和人物视角 |
| test_world_clock | 世界计时、固定工作与时间段 |
| test_meta_layer | 心声、旁注、安全区域与人文系统 |
| test_v2_entry_debug | 记忆入场与调试信息 |

## 实际游玩复查

- 新游戏影片播放、淡入城镇；菜单 A/B 各七天位置正确。
- 社区中心上午九点后领取资料；店铺工作后领取证明；晚上回自己房间整理。
- 纸张界面关闭后能继续走动，相机和录音期间时间继续。
- Day 7 提交前有清晰缺项提示；提交后保留快照。
- F8 / F9 开发信息继续可用，正常模式隐藏参与者覆盖。

本轮自动验证不替代完整十四章人工游玩。发布前补测不同分辨率、音频设备断开、系统休眠恢复和各显卡的 3D 画面。
