# 参考与候选评估记录

更新：2026-09-24。实际安装的资源见 [许可索引](THIRD_PARTY_LICENSES.md) 和 [交付报告](docs/resource_integration_delivery_20260924.md)。这里区分视觉参考、源码阅读与尚未取得的候选。

## 当前视觉参考

| 来源 | 使用边界 | 本轮行为 |
| --- | --- | --- |
| 用户确认的随身图标与手绘 UI 参考 | 保留已确认图标、物件轮廓和文字标签关系；正文清晰、纹理克制 | 新纸页底形与按钮跟随原有布局和物件系统 |
| [Venba / Visai Studios 官方 presskit](https://venbagame.com/press/) | 厨房的温暖手绘表现、食物辨识度与料理交互参考；不导入其截图、音乐、角色或剧情 | 实际厨房继续保留切菜和食材逻辑；未复制 Venba 的素材 |
| [Little Chef / hello erika](https://hello-erika.itch.io/cute-cozy-cooking-game-assest) | 用户认可其色块/手绘方向，要求形状为本作适配 | 已实际选用资源，不再称“仅参考”；锅具通过图像编辑重新生成轮廓、配色与装饰，见改造记录 |
| 之前的《SOLMERE_Codex_功能打磨完整包.zip》参考图 | **用户明确排除，不作为参考** | 未提取、查看、导入或用于生成 |

## 本轮第三方候选

Little Chef、Cila、R4orce、HuntSounds 已下载并安装选用文件；UI Animation Library 与官方 spectrum 已抽取适配，详见许可索引。

- [Odds & Ents 纸纹理](https://oddsandents.itch.io/paper-texture-pack)：免费领取表单需要邮箱，待用户提供领取邮箱；未虚构下载结果。当前使用实际取得的 Cila 纸形和既有低强度纸感。
- 官方 `gui/gd_paint/paint_control.gd`、`gui/drag_and_drop/drag_drop_script.gd`、`audio/mic_record/MicRecord.gd`：已取得源码核对，固定 demos 提交 `a3b5c113112f77291d5f3d1360f33a882fdc52f7`；没有将完整示例接入。现有拼贴和 PCM 录音继续使用，实际采用的频谱代码另列许可。
- andrew-wilkes/godot-chess：保留自己的纯 GDScript 规则；未导入其 Go/UDP/UCI 服务或外部引擎二进制。

## 历史记录

[2026-09-18 开源方案](OPEN_SOURCE_INTEGRATION_PLAN.md) 保留作历史审计，其七日制、作品集等内容已经过时，不能作为当前玩法规格。最新五日基线与接入状态见本轮核对文件。
