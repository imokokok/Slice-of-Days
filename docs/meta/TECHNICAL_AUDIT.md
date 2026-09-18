# 项目检查与接入位置

1. 场景：主页 → town_day 街道 → interactive_space 室内；SceneRouter 管理小游戏、手账与章节转场。
2. Autoload：GameState、CharacterSystem、ScheduleSystem、ResidentProfileSystem、TravelSystem、WorldGraph、KnowledgeSystem、EchoSystem、DialogueSystem、RelationshipSystem、EventSystem、ChapterSystem、GameplayModuleSystem、SaveManager、SettingsSystem、SceneRouter，以及 WorldSound、SoundSettings、ObservatoryState、ObservatoryAudio。
3. 时间：GameState 管理角色各自的分钟与日程块，use_free_time 会校验当前可用时段。保留七天结构。
4. 存档：GameState 序列化，SaveManager 三槽位、临时文件校验与原子替换。新增状态放入 shared_state。
5. 对话：ConversationPanel 按角色显示连续台词；DialogueSystem 管理话题、连续段落和小游戏邀请。直接提问复用现有话题。
6. NPC：data/npcs 的核心档案、日程、连续对话与邀请分开存放。保留现有角色编号。
7. 小游戏：GameplayModuleSystem 路由料理、书信、采样、塔罗、摄影、档案、光学与现有扩展。作品已通过 EchoSystem 留在小镇，不另建作品存档。
8. 房间：home_a、home_b 原为 interactive_spaces.json 中的室内配置。本次加入房间物件入口，保留原场景底图。
9. 手账与交互：原 Journal 使用 KnowledgeSystem 与角色物件；WalkStage 提供邻近热点。本次增加修订记录、直接提问与可暂停行走的覆盖层。
10. 资源：art/scene_atlas 保存原参考场景；data/world、data/story、data/npcs、data/gameplay 分工明确。新增模型与声音集中在 art/memories，文本集中在 data/meta。

接入顺序：先复用存档与时间接口，再加文本覆盖层、房间入口和记忆控制器；Blender 模型按独立 collection 导出，最后运行系统测试和图形窗口检查。
