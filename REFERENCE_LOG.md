# 参考与候选评估记录

更新：2026-09-24。实际安装的资源见 [许可索引](THIRD_PARTY_LICENSES.md) 和 [交付报告](docs/resource_integration_delivery_20260924.md)。这里区分视觉参考、源码阅读与尚未取得的候选。

## 当前视觉参考

| 来源 | 使用边界 | 本轮行为 |
| --- | --- | --- |
| 用户确认的随身图标与手绘 UI 参考 | 保留已确认图标、物件轮廓和文字标签关系；正文清晰、纹理克制 | 新纸页底形与按钮跟随原有布局和物件系统 |
| [Venba / Visai Studios 官方 presskit](https://venbagame.com/press/) | 厨房的温暖手绘表现、食物辨识度与料理交互参考；不导入其截图、音乐、角色、剧情或具体菜谱 | 只学习“当前步骤聚焦、食材状态可见、动作马上回应、摆盘也属于料理”的交互原则：新增切配图、入锅落下、火候色泽、真实摆盘预览与热气；未复制 Venba 的素材或画面构图 |
| [用户提供的小红书料理游戏视频](https://www.xiaohongshu.com/discovery/item/697364cf000000002203a563) | 2026-09-24 用户确认视频展示的就是 Venba；链接未能直接播放，具体细节以 Venba 官方资料为准 | 选材序号、火候区间与备料说明来自本作界面的可读性复核；两种备料方式现在影响实际火候或锅温，不照搬视频画面 |
| [Little Chef / hello erika](https://hello-erika.itch.io/cute-cozy-cooking-game-assest) | 用户认可其色块/手绘方向，要求形状为本作适配 | 已实际选用资源，不再称“仅参考”；锅具通过图像编辑重新生成轮廓、配色与装饰，见改造记录 |
| 之前的《SOLMERE_Codex_功能打磨完整包.zip》参考图 | **用户明确排除，不作为参考** | 未提取、查看、导入或用于生成 |

## 本轮第三方候选

Little Chef、Cila、R4orce、HuntSounds 已下载并安装选用文件；UI Animation Library 与官方 spectrum 已抽取适配，详见许可索引。

- [ScratchIO 2D Vegetables](https://opengameart.org/content/2d-vegetables)：CC0；只用整菜/切片对照理解切配轮廓，没有将原图打包进仓库。
- [KayKit Restaurant Bits](https://github.com/KayKit-Game-Assets/KayKit-Restaurant-Bits-1.0)：CC0；只用 raw/chopped/cooked 状态组织方式作为结构参考，没有导入 3D 模型或贴图。
- [Glitch Food & Drink Items SVG](https://opengameart.org/content/glitch-food-drink-items-svg)：CC0 候选；评估后未采用，避免引入与用户手绘素材不一致的矢量语言。

- [Odds & Ents 纸纹理](https://oddsandents.itch.io/paper-texture-pack)：免费领取表单需要邮箱，待用户提供领取邮箱；未虚构下载结果。当前使用实际取得的 Cila 纸形和既有低强度纸感。
- 官方 `gui/gd_paint/paint_control.gd`、`gui/drag_and_drop/drag_drop_script.gd`、`audio/mic_record/MicRecord.gd`：已取得源码核对，固定 demos 提交 `a3b5c113112f77291d5f3d1360f33a882fdc52f7`；没有将完整示例接入。现有拼贴和 PCM 录音继续使用，实际采用的频谱代码另列许可。
- andrew-wilkes/godot-chess：保留自己的纯 GDScript 规则；未导入其 Go/UDP/UCI 服务或外部引擎二进制。

## 历史记录

[2026-09-18 开源方案](OPEN_SOURCE_INTEGRATION_PLAN.md) 保留作历史审计，其七日制、作品集等内容已经过时，不能作为当前玩法规格。最新五日基线与接入状态见本轮核对文件。

## 2026-09-26 采用与舍弃

- 继续用用户确认的 Summer House 氛围、Venba 的步骤集中与即时食材反馈、纸本 UI 参考约束本作；不下载这些商业游戏的成品 UI 或音效当作免费资源。
- Skymon 是独立手绘符号包：统一线条、低饱和染色、保留用户确认的随身物件轮廓。采用范围见许可索引；不宣传为成熟游戏的已验证在用资源。
- Kenney 的 Interface Sounds、RPG Audio 已实际安装，并接入 WorldSound 的控件/物件反馈；素材数不等于功能数。
- Nathan Hoad 的音效池与 Maaack 的 UI 信号注册采用 MIT 代码片段；均固定版本、保留完整版权许可，并适配现有 Godot 总线。
- Game-icons.net 的 CC BY 图标可署名商用，但线条语言与现有物件不一致，本轮未导入。Kenney Scribble Platformer 的角色/平台风格也不适用，没有为“多导入”而替换场景或角色。
- 原有字体与手写待办继续沿用 Xiaolai；无新远程字体/CDN依赖。键盘弹窗焦点参考 Godot 官方 GUI navigation 机制，只做现有页面的焦点范围与返回，不替换存档、角色或任务架构。
