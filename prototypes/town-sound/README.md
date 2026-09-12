# Town Sound / 城市采样

当前试玩版：**v0.2**。新增任意区间拖选剪辑、时间轴缩放、声音设备选择和重新制作的工作台；详见 [更新说明](UPDATE-v0.2.md)。下方早期版本的边界说明以更新说明为准。

本目录是持续开发的 Git 工作目录，后续编辑与一键推送见 [GIT_WORKFLOW.md](GIT_WORKFLOW.md)。

Godot 本地优先可玩原型，2026-09-12。使用 Godot **4.7.2 stable** 开发和验证。按用户提供的最终规格从空目录建立，未修改其他项目。

## 运行

仓库提供源码。Windows 可通过 Godot 导出为独立 EXE，默认输出 `build/TownSound.exe`；已导出的程序无需安装 Godot，也无需联网。

开发：用 Godot 4.7.2 导入本目录 `project.godot`，按 F6/F5 运行主场景。其他 Godot 4.x 版本和 macOS 尚未验证。

## 一次完整体验

1. 选择输入设备，点击 REC；录下两种以上声音。每次 STOP 后可以试听、命名、保存或放弃。最长每段 60 秒，最多 20 段。
2. 向下滚动到「进入 STUDIO」。拖动素材到四条轨道，或点击素材放到第一轨游标位置。时间轴最长 60 秒。
3. 拖片段中部移动，拖左右边缘裁切；点击空白处设置游标。片段内部游标可以拆分。支持复制、删除、循环、音量、速度和淡入淡出。循环开启后可拖右边缘延长。
4. PLAY、PAUSE、STOP 控制播放。Ctrl/Cmd+D 复制，Delete/Backspace 删除选中片段。工程编辑会自动保存，也可以手动保存或重载。
5. 点击 Visual，输入中文或英文描述，本地生成抽象画面。「换一个种子」改变布局，声音控制大小与动作。播放和暂停可用。
6. 使用至少两种录音、两个片段，并使工程达到 8 秒；点击「交给老板试听」。老板试听 8 秒后进入工作台。
7. 命名、选择封面帧、用滑条左右取景。依次完成中心标签、压制、内袋、外套、封签、印章、编号卡、交还老板。物件可拖到右侧目标框，也可用步骤按钮操作。
8. 保存成品成功后才结算 60–180 的游戏内授权费。返回录音页进入「LOCAL RECORDINGS」可以再次试听。预置三张程序化原创居民唱片。

小窗口下页面可以滚动，底部操作不会被永久遮挡。输入文本时快捷键由输入框优先处理。

## 数据与成本

Windows 存档在 `%APPDATA%/Godot/app_userdata/Town Sound/`：

- `samples/`：真实麦克风 WAV 与逐段 JSON。
- `samples/trash/`：手动移除录音的回收文件。
- `projects/current.json`：当前可编辑工程，与成品唱片分离。
- `records/rec_*/`：成品 `audio.wav`、`cover.png`、`record.json`。
- `tests/`：隔离的自动测试产物，不进入玩家唱片架。

已被工程引用的素材暂时禁止删除，需先移除相关片段。坏 metadata 跳过，丢失音频保留信息并显示提示。唱片 metadata 是提交标记，只有成功提交的记录参与余额计算，重启不会重复发钱。

本版本无云服务、无生成式 AI、无付费调用、无私钥。公共库只做到独立接口和明确不可用提示；**没有上传、公共试听或下载服务**。根据规格“免费后端无法配置则停止在 Phase 16”，未部署 Cloudflare，也未绑定任何计费账户。

## 已知边界

- 这是可玩功能原型，不是最终美术版。工作台采用程序绘制与步骤交互，标签/封签样式固定，角色对话和动作简化；没有完整人物动画、自由标签排版或多款封签选择。
- 多轨采用编辑后离线混音，再由一个播放器播放。混音为 22050 Hz / 16-bit / mono WAV，支持同步和速度变调；较长工程混音时主线程会短暂停顿。当前使用硬限幅，没有母带压缩器或抗混叠高质量重采样。
- 频段通过本地一阶滤波近似分离，非精确 FFT；视觉由混音能量驱动，轨道层按片段活动、静音和音量控制，并非逐轨独立频谱。回放使用时间与种子重建，不保存视频。
- 工程暂为一个自动保存槽，暂不支持多工程管理与 Undo/Redo。老板试听固定 8 秒，反馈为简化的本地规则文本。
- 封面是实时 Visual 的横向方形取景，暂不支持任意尺寸裁切或复杂封面排版。
- 录音权限被系统拒绝时，程序不能代替用户授予权限。无帧/静音会提示设备或权限问题；普通安静环境与系统返回的静音无法可靠区分。
- Windows 实测通过；macOS 麦克风权限、签名、导出与试听尚未实测。公共后端、网络失败注入、公开内容限制与配额核验留待实际配置后进行。

## 源码入口

- `scripts/audio/AudioRecorder.gd`：原生 microphone / capture / PCM。
- `scripts/data/SampleStore.gd`：录音持久化。
- `scripts/studio/Arrangement.gd`：工程与混音。
- `scripts/studio/Timeline.gd`：拖拽剪辑和波形。
- `scripts/visual/VisualCanvas.gd`：关键词解析与声音驱动画面。
- `scripts/record_shop/PressingTable.gd`：制作步骤与付款。
- `scripts/network/`：本地唱片库与未来联网层边界。

## 测试命令

```text
godot --headless --path . --script res://tests/test_recorder.gd
godot --headless --path . --script res://tests/test_arrangement.gd
godot --path . --script res://tests/test_flow.gd
```

第三项需要真实图形驱动来截取封面。测试里的合成 PCM 仅作为测试输入，不会替换麦克风录音。测试结论见 `TEST_REPORT.md`。

技术参考：[Godot AudioEffectCapture 官方文档](https://docs.godotengine.org/en/4.6/classes/class_audioeffectcapture.html)。
