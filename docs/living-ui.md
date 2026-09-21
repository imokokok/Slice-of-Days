# Solmere 原生 UI

2026-09-22。当前实现与验收记录见 [Production UI](production-ui.md)。场景美术保持原样；界面由 Godot Control、共享 Theme 和独立组件搭建，素材图片不包含按钮、文字或透明点击区域。

- Notebook、Archive、Portfolio 使用真实纸媒介的视觉；对话、摄影、录音、商店、背包、暂停使用克制的海蓝／暖白功能界面。
- Notebook 是私人记录，与申请档案分开。六个内页为今天、听说、人物、地点、私人、收藏；任务勾选来自游戏状态。
- Archive 有六个独立章节。只有 Seven Days Portfolio 显示七日分页；每页独立保存素材的 ID、来源、位置、角度、缩放和层级。
- 一级物件共享位置与尺寸；相机拍摄时进入全屏取景。按钮具有正常、悬停、按下、焦点、禁用、选中状态。
- 所有操作按键提示从 SettingsSystem / Input Map 读取。关闭界面后恢复探索；对话可以中途退出。
- 相片、录音、素材继续使用现有 FilmSystem、TownWorld 和 ResidencySystem 的数据及本地文件，不建立平行存档。

历史生成的 living-folder.png、living-postcard.png 保留供旧资源引用；新纸面、地图和烹饪独立插画的来源记录见 Production UI 文档。
