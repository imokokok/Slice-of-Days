# 第三方代码与素材实际接入审查

2026-09-24。本次复核用户提供的《第三方资源与代码融合方案 V1》里选用的素材和代码；不把安装文件数当作完成玩法的证据。

## 来源、修改和当前用途

| 内容 | 来源与许可记录 | 实际接入 |
| --- | --- | --- |
| Little Chef 10 张选用 PNG | [hello erika 官方页](https://hello-erika.itch.io/cute-cozy-cooking-game-assest)，原 ReadMe 和页面条款均保留 | `handmade_assets.gd` 的面包/奶酪；`cooking_pot.gd` 的锅后景、勺、锅盖；厨房器具。锅前景已按用户要求改宽矮比例、海绿色与陶土手柄，保留派生来源。 |
| Cila 18 张 PNG | [Cila 官方页](https://nacila.itch.io/paper-stylized-ui-ready-for-development)，要求署名，限制素材独立再分发 | `production_assets.gd` 纸页/按钮/输入框主题；本轮按 PNG 形状重新切边和配置文字安全区。未覆盖已批准的实体图标和地图。部分符号仍为备用。 |
| R4orce 14 个 WAV | [官方页](https://r4orce.itch.io/cute-ui-sound-pack)，完整包内 License 已保留 | `WorldSound.play_ui` 加载真实点击、开关、录制、错误、反馈声；通知音现接入 `guidance_toasts.gd`。drag/snap 已注册但尚无正式动作调用，明确记为预留。 |
| HuntSounds 42 个 WAV | [官方页](https://huntsounds.itch.io/cosy-sfx-volume-1)，页面项目使用条款已保留 | `WorldSound` 的 6 个环境/天气循环、4 地面×5 脚步、12 物件声和4鸟声，按场景/时间/雨天/室内状态选用。 |
| Godot UI Animation Library | Rock Gementiza，[上游](https://github.com/rockgem/godot-ui-animation-library)，MIT，提交 `62230b14300c44a6a7decb8ad052b2b29b416a67` | 抽取 `animation_scale.gd` 的 `offset_transform_scale` Tween 思路和实现到 `solmere_motion.gd`，增加中断、释放安全与减弱动效。由实际 Button 输入、纸页打开及食材选择调用。 |
| Godot 官方频谱示例 | [官方 demos](https://github.com/godotengine/godot-demo-projects)，MIT，提交 `a3b5c113112f77291d5f3d1360f33a882fdc52f7` | `SignalSpectrum.gd` 适配 `audio/spectrum/show_spectrum.gd` 的频段强度与 dB 归一化；`AudioRecorder.gd` 接真实总线分析，`live_sound_window.gd` 用于录制/回听。新增离线 WAV 分析及边界保护。 |

完整许可留在根目录 [THIRD_PARTY_LICENSES.md](../THIRD_PARTY_LICENSES.md) 和 `third_party/licenses/`；仅参考、未复制的项目单列 [REFERENCE_LOG.md](../REFERENCE_LOG.md)。未导入整套 Unity 工程、Godot 编辑器插件、外部棋引擎或旧开场动画。

## 逐文件核查

`python tools/audit_resource_usage.py` 校验四个官方 ZIP 的固定 SHA-256、84 个包内原始文件的哈希，以及84个安装文件的哈希。转换 WAV 时保留原采样率/声道，转换过程在 manifest 明示。

[逐文件审查 JSON](qa/third_party_usage_20260924.json) 列出原文件名、来源包、安装路径、原始和转换后哈希、当前 GDScript 引用位置。结果：65 项有源码引用或动态路由，15 项是已安装备用，2 项是锅具改造来源/备用，2 个音效事件只有注册尚无调用。**源码引用不等于运行覆盖**，报告没有把所有84项都标成玩家已经体验到。

20个界面采集过程中观察到实际加载的纸形、面包/奶酪、菜单/翻页/通知和场景音效；完整资源测试进一步验证全部文件能从源工程及导出 PCK 加载，正式流程测试验证实际 PCM、压片、库存和作品保存。测试入口和结果见 [UI 与运行复核](qa/ui_readability_20260924.md)。

公开 Git 仓库保留安装器、固定哈希、改造记录和许可；禁止作为独立素材重新分发的原始包留在本地忽略目录。Windows 游戏 PCK 包含选用资源，离线运行无需再下载。未把免费使用素材笼统称为开源或公共领域。

## 查出的旧实现

声音模块注册表和通用入口原本还可能落到旧的2.4秒计时试听。已删除该模拟波形/计时逻辑，注册信息与 `SceneRouter.gameplay_module` 同时指向真实声音工作台。实际交付仍由 `record_studio_delivery` 检查音频文件、时长、当前角色和日期，继续复用真实存档和第五天角色状态。

导入后暴露的文字裁切、低对比、Checkbox 实心化、纸边安全区和录音总线所有权问题均已修复；没有靠重新引入过期 NPC 或放松真假数据检查来通过测试。

## 尚未完成，不能算作本次接入成果

- Odds & Ents 纸纹理包仍未取得：免费领取需要邮箱，之前的询问尚无答案。当前使用已获得的 Cila 纸页；没有虚构导入结果。
- 文档的六参数 Visual Automation 曲线（Pitch / Volume / Filter / Reverb / Pan / Glitch）没有完整实现。现有 Studio 的片段速度、音量、循环、淡入淡出和轨道混音确实改变 PCM；频谱色块只是声音驱动画面，不是该六参数系统，也不是根据声音语义生成视频。
- 文档新增的每 NPC 四片认知→现场签名流程、扩展顾客订单和水量/配比系统不以素材导入替代验收。当前保留实际五日叙事、已有居民互动和库存采购/烹饪流程。
- 旧 Myriorama 牌背/桌布的来源许可待明确记录继续保留；本次未重新给所有历史美术作商用授权结论。

这些是明确的未完成事项，未伪造完成标记、录音、签名或库存来掩盖。
