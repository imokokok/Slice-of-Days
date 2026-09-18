# Residency 数据结构

定义：data/residency/portfolio.json。运行时：GameState.role_states[角色].artifacts.residency；当前角色通过 GameState.artifacts 访问。管理入口：ResidencySystem。

| 字段 | 内容 |
| --- | --- |
| version | 档案格式版本，当前 1 |
| packet | 是否在社区柜台领取资料 |
| pages | 固定七项，day 为 1–7 |
| materials | 材料 ID → 材料记录 |
| filing | 材料 ID → 唯一归档位置 |
| ledger | 真实收支副本，source 为交易 ID |
| opening_balance | 导入账本前的余额 |
| visits | 到访地点及游戏日期、分钟 |
| annotations | 原笔记 → 修订笔记的关联 |
| map_notes | 私人地图标注 |
| submitted | 提交日期、分钟、选择、结语及快照 |
| imported | 旧记录首次导入标记 |

## 每日页

day、today、record、fields、keep、marks、ledger_checked。fields 的键与 portfolio.json 对应；keep 保存材料 ID，marks 只接受玩家真正获得的居民确认，单页最多两人，同一人不跨页重复。

## 材料

基本字段：id、kind、title、role、day、minute、location、collected。kind 包括 official、photo、sound、object、work、proof、receipt、ticket、note。

照片 ID 对应 PhotoLibrary 的 photo.png / photo.json；声音 ID 对应 SampleStore 的 WAV 及元数据。录音附 markers（秒）。原文件通过 ID 读取，归档动作仅改变 filing。

work 记录 issuer、proof_kind、source、paid、work_minutes 等；proof 增加 source_material、issued_day、issued_minute、applicant、issuer_npc、signature、work_dates、hours。收入与贡献分开判断。

filing 可为 day_1…day_7、proof、personal、loose。移动时同步移除旧页的 KEEP 引用。未来日期和已提交档案拒绝改动。

## 核对与提交

audit() 检查资料袋、七日页、七日账目核对、收入证明、贡献证明、三类探索记录及至少三个实际到访、十二位唯一居民签记、个人页、最终说明和签名。

submit() 要求 Day 7、09:00–18:00、社区中心室内柜台和全部材料齐备。提交后保存页面与归档关系快照，重复操作不会产生第二次提交。

所有写入沿用 SaveManager。正式存档与 --isolated-save 的测试存档分开。角色切换先提交当前角色，再读取另一份记录。
