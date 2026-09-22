# Solmere · 五日旅程

Godot 4.7.2 · 海边小镇探索、双主角的五日生活与公共作品。

当前主流程以用户确认的《Solmere_Codex_5Day_Rebuild_CN》为准。保留现有美术、摄影录音、交易与可用小游戏。旧七日申请制不再控制推进。[五日交付报告](docs/FIVE_DAY_REBUILD_REPORT.md)说明实际挂载、存档和验证范围；其他历史文档中的七日要求不再代表当前流程。

第二阶段按《Solmere_GameplayFlow_Feedback_Guidance_CN》接入持续生活物件、分级引导和第五天真实时段。[第二阶段报告](docs/GAMEPLAY_FLOW_GUIDANCE_REPORT.md)为当前反馈与时间交互的说明。

## 启动

用 Godot 4.7.2 打开 project.godot 后运行并选择新游戏。新版窗口标题为「Solmere · 五日旅程」。

## 操作

A / D 走动；W 交谈；E 与物件互动；Space 继续对话；C 相机；R 录音；G 相册；Tab 地图；B / I 随身物品；F 档案；J 随身本。Esc 退出当前对话或逐层收起。第五天见面后，通过「日程与视角」按钮选择角色；不再使用街上即时切换快捷键。其他实际提示读取 Input Map。

Day 1 A 制作音乐；Day 2 B 完成餐厅工作；Day 3 A 制作拼贴信；Day 4 B 下棋并约定见面；Day 5 两人见面后可切换视角。前两天完成主活动即可自主回家休息；第三、四天还需实际查看生活物件及相关交谈。前四天界面不提前揭示 A/B 身份。纸页、居民留字及自由拼贴均为可选记录，不需要提交作品集或集齐认可才能推进。

## 保存与检查

A/B 的钱、物品、关系、笔记和草稿分别保存；公共作品与小镇状态共享。五日存档为 user://solmere_five_day.json 及另外两个槽，schema 7 是格式版本号。旧 solmere_save.json 保留并只读检测，不兼容时需新开五日旅程。实际照片和录音另存文件。测试使用 --isolated-save。请勿同时运行多个窗口写入同一正式存档。

[测试清单](TEST_CHECKLIST.md) · [机器结果](docs/FINAL_TEST_RESULTS.json) · [内容填写说明](CONTENT_WRITING_GUIDE.md) · [档案结构](RESIDENCY_CONTENT_SCHEMA.md)

旧版说明存于 docs/PRE_FINAL_README.md，仅供历史查询。
