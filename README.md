# Solmere · 七日档案

Godot 4.7.2 · 2D 小镇探索、双主角七日生活与第一人称记忆。

2026-09-17 已接入最终包的七日申请、材料与证明、纸张界面、相机录音和角色章节流程。开发记录见 [IMPLEMENTATION_NOTES.md](IMPLEMENTATION_NOTES.md)，待补内容见 [MISSING_CONTENT.md](MISSING_CONTENT.md)。

## 启动

用 Godot 4.7.2 打开 project.godot 后运行。桌面原有启动快捷方式继续指向此工程。新版窗口标题为「Solmere · 七日档案」。

## 操作

A / D 走动；W 与人交谈；E 与门、路口及物件互动；Space 继续对话；1 提问；C 相机；R 录音；G 相册；Tab 地图；B 素材本；F 档案；H 随身物品；J 私人手帐。Esc 逐层收起。小游戏和 3D 记忆使用各自的场内提示。

到社区中心柜台领取资料，外出收集与工作，晚上回自己房间的桌边整理。Day 7 18:00 前回柜台提交。相机和录音期间继续计时，纸张阅读暂停时间。

## 保存与检查

A/B 的私人材料分别保存，公共作品和小镇状态共享；照片为 PNG，录音为 WAV。正式存档在 Godot user:// 目录，测试使用 --isolated-save。请勿同时运行多个窗口写入同一正式存档。

[测试清单](TEST_CHECKLIST.md) · [机器结果](docs/FINAL_TEST_RESULTS.json) · [内容填写说明](CONTENT_WRITING_GUIDE.md) · [档案结构](RESIDENCY_CONTENT_SCHEMA.md)

旧版说明存于 docs/PRE_FINAL_README.md，仅供历史查询。
