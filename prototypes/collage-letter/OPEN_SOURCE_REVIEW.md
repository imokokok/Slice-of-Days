# 可商用组件筛选与本次接入

核验日期：2026-09-26。目标是保留原版工作台和玩法，改善联机稳定性与声音。许可文件随源码保存，不把许可说明放进玩家操作流程。

| 项目 | 许可 | 本次用途 / 结论 |
| --- | --- | --- |
| [Waitress 3.0.2](https://docs.pylonsproject.org/projects/waitress/en/stable/) | [ZPL-2.1](https://github.com/Pylons/waitress/blob/main/LICENSE.txt) | 已原样接入 server/vendor。Windows、Linux 与容器共用成熟 WSGI HTTP 服务；限定工作线程、连接数、空闲超时、请求体与请求头大小。无需游戏画面署名，必须保留源码版权与许可文件。 |
| [SQLite](https://sqlite.org/copyright.html) | 公有领域 | 继续使用 Python 内置绑定。信件、回复义务及同一流水号去重继续由数据库事务保障；无 SQLite 署名要求。 |
| [Godot HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html) | Godot MIT | 用引擎现有 API 增加有限次数退避重试；读取和具有流水号的寄信可重试，身份注册和业务拒绝不重试。请求固定地址、身份和正文，避免重试重复发信。Godot 许可仍随运行时保留。 |
| [Kenney UI Audio](https://kenney.nl/support) | CC0 | 已接入之前下载的点击录音。免费商用，不要求署名。 |
| Freesound 纸张、摩擦、印章与火柴录音 | CC0，逐文件核验 | 已接入，来源在 assets/open_pack/sources.json。声音片段配合现有动作；复用声部、冷却、音高变化与短淡出由本项目实现。 |
| [Godot Sound Manager](https://github.com/nathanhoad/godot_sound_manager) | MIT | 已评估。当前主线面向 Godot 4.6+，本独立项目维持 4.5.1；本次使用项目自身的轻量声音池，不引入该插件或复制其代码。 |
| [Nakama](https://github.com/heroiclabs/nakama) | Apache-2.0 | 已评估，适合以后统一账号与大型多人后端。本次服务继续使用现有漂流信数据与协议，接入 Waitress。未引入 Nakama。 |

“免费商用”不代表可以删掉所有许可证。新增音效/图案优先采用 CC0；代码依赖按各自许可保留必要文件，不要求玩家在游戏画面中看到署名。

## 已验证的改进

- 67 个材料全部经 Godot 渲染和裁剪，图案使用 240px SVG 固有尺寸，避免放大低分辨率导入贴图。
- 原工作台、矩形/自由裁剪、纸片变换、胶带、手写、折信、信封、封蜡、寄信流程保留。
- Waitress 上模拟“已入库但第一次响应失败”，Godot 自动重试返回同一封信；数据库只增加一封信。
- 临时错误最多重试两次；建立身份不自动重复；回信义务拒绝不自动重复。
- 10 个音效声部循环复用，静音立即停止已播放效果。

仍为可部署的匿名身份服务，尚无已开通的公共邮局。Docker 文件已更新；本机实际验证使用 Waitress，未声称完成公网或容器上线。
