# 组件、素材与参考来源

核验日期：2026-09-26。可运行功能优先使用当前项目与成熟引擎 API，新增音频和纹理优先选择可核查的 CC0 来源。许可和来源记录随源码保留，不塞进玩家操作流程。

## 实际接入

| 项目 | 许可 / 来源 | 用途 |
| --- | --- | --- |
| [Waitress 3.0.2](https://docs.pylonsproject.org/projects/waitress/en/stable/) | [ZPL-2.1](https://github.com/Pylons/waitress/blob/main/LICENSE.txt) | 原样放在 `server/vendor`，为本机、局域网和可部署服务提供 WSGI HTTP 层；限制线程、连接、超时和请求大小。保留代码版权与许可文件。 |
| [SQLite](https://sqlite.org/copyright.html) | 公有领域 | 使用 Python 内置绑定；用事务保存信件、回复义务与寄信编号，处理并发和重复请求。 |
| [Godot HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html) | Godot MIT | 读取和带幂等编号的寄送可有限重试；身份注册及业务拒绝不自动重复。重试保持原地址、身份与正文。 |
| [Godot TextEdit](https://docs.godotengine.org/en/stable/classes/class_textedit.html) | Godot MIT | A4 纸面直接输入的编辑组件，保留多行、光标、选区、撤销等原生能力；玩家输入不经过 NPC 逐字演出队列。原生中文 IME 是否通过，须看实际验证记录。 |
| [Kenney Interface Sounds](https://kenney.nl/assets/interface-sounds) | CC0 | 小型界面操作反馈。 |
| Freesound 纸张、摩擦、印章与火柴录音 | CC0，逐文件来源见 `assets/open_pack/sources.json` | 裁剪、涂鸦、胶带、翻页和器具使用对应来源；声音池、冷却与短淡出由本项目实现，部分动作复用同类录音。 |
| [Typewriter sounds / Cassie-OrbitGames](https://opengameart.org/content/typewriter-sounds) | CC0 | 新接入 4 个原始手机实录 WAV；验证可解码、非静音、无满幅削波。写字事件使用录音片段，未合成“打字”替代声音。 |
| [Paper02 / plaggy](https://opengameart.org/content/cc0-pbr-paper-02-texture-paper02albedopng) | CC0 | 使用颜色纹理表现平面纸纤维，没有导入 PBR 法线或 3D 材质。 |
| [Watercolor textures / PuzzleAndy](https://opengameart.org/content/cc0-watercolor-textures) | CC0 | 12 张既有水彩原图用于纸张和颜料沉积；未重新生成原纹理。 |
| 既有 Solmere 场景照片 | 项目已有美术，外部再分发权利未独立核验 | 5 张场景 JPG 从主仓库逐字节复制，作为游戏内照片素材。来源、原文件与哈希可追溯；不标为 CC0，也不宣称可供无关商业项目使用。 |
| 用户提供的字母图 | 用户提供的项目材料 | 52 个大小写字母按原像素裁切，保留不透明颜色与边缘；不能据此推断其为公共领域。 |

素材清单逐文件记录来源、许可与 SHA-256。**来源可追溯和获准在所有商业项目复用是两件事**：CC0 素材、项目既有图像与用户提供素材分别标记。现有场景图的权利说明不会被项目 MIT 代码许可覆盖。字体也按自己的许可处理。

4 个新打字机文件保持原始字节，许可说明为 `assets/open_pack/licenses/Cassie-Typewriter-CC0.txt`。解码、波形检查和代码接入不等于已经在用户设备上完成听感验收。

## 评估但未引入的代码

| 项目 | 许可 | 结论 |
| --- | --- | --- |
| [Godot Sound Manager](https://github.com/nathanhoad/godot_sound_manager) | MIT | 没有引入插件或复制代码；本项目保留轻量声音池和当前 Godot 兼容范围。 |
| [Godot Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager/blob/main/LICENSE) | MIT | 没有引入整套插件；12 份委托使用现有独立实现的对话状态、逐字播放、追问回返和历史记录。 |
| [Nakama](https://github.com/heroiclabs/nakama) | Apache-2.0 | 未引入。当前漂流信保留已有匿名身份、WSGI / SQLite 协议；部署与运维规模没有要求增加整套账号后端。 |

免费商用代码通常仍需保留许可与版权声明。未引入的候选不计入已集成能力，也不计入素材数量。

## 参考游戏与本作的转译

[Kind Words / Paper Sky 研究文档](docs/KIND_WORDS_STUDY.md)记录了官方资料、全流程拆解、版本差异、输入证据与推断边界。本次未找到两作官方授权、可直接商用复用的程序或素材包。因此只借鉴纸上写字、安静读信、回到桌边和有停留感的寄送体验，不提取它们的 UI、角色、音轨或玩家信件。没有声称亲自完整试玩两款商业游戏。

Paper Sky 自由输入的旧版演示与后续词语机制须分开看。卷纸、拔塞、装瓶、重新塞好并投入海面，是依据本项目要求独立实现的流程，不能说成已经复用 Paper Sky 的代码。Kind Words 的贴纸致谢与限制持续私聊属于研究发现；本作仍保留“旧信可回复”及“发一封、回一封”的已确认规则，未宣称接入原作全部社交功能。

用户提供的《絮絮手账本》图片和视频用于收纳、分类、翻页及拿取交互参考。桌面继续是单页 A4 信，素材册本身可翻页，底纸没有装订孔与绿色装饰框。街道、海景、百叶窗与桌上独立文具遵循 Solmere 的暖木、浅纸、灰蓝与橄榄色方向。

此前另研究过 [Sticky Business](https://store.steampowered.com/app/2303350/Sticky_Business/)、[Pieced Together](https://store.steampowered.com/app/2891370/Pieced_Together/)、[A Tiny Sticker Tale](https://store.steampowered.com/app/2322180/A_Tiny_Sticker_Tale/) 的排列、纪念物和物件交互原则。它们都是设计参考，不是本项目的开源素材提供者。

## 数量与验证边界

- 678 个可用材料条目包含排版、纹理应用和裁切变体，不代表 678 张独立下载原图。120 个文字条目来自 20 组较完整的中英文小镇文案与 6 类版式；121 个票据条目包含不同票号、日期、金额、座位及事项结构。
- 18 个音频来源文件包含 4 个新实录打字机 WAV；静音停止已播放效果，声音池避免无限叠加。
- 纸张、胶背、水粉、对话历史和瓶子状态均有存档字段；网络使用持久化寄信编号。具体回归结果见 [VALIDATION.md](docs/VALIDATION.md)，不能由这些字段存在便推断全流程已通过。
- 漂流服务仍为可部署版本，尚无已开通的公共邮局。Docker / Caddy 文件是部署配置，不代表已完成公网或容器上线。
