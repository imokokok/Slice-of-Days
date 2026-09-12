extends RefCounted

const Questions = preload("res://scripts/question_engine.gd")
# Every clause must be accounted for. Never pass a paragraph merely because it
# contains solution keywords; uncertainty, contradictions and unknown clauses block.
const REQUIRED := {
	"murder": {"old_relationship": "案发前的人物关系", "ended_relationship": "关系发生的变化", "motive_chain": "动机如何导致行动", "visitor": "案发前的来访", "conflict": "冲突与结果的联系", "weapon": "造成死亡的工具", "reporter_entered": "目击者当时的位置", "detective_first": "案发后的进入先后", "possession": "后续操纵者与对象", "possession_plan": "原定目标与后来的变化", "mislead": "调查为何走向错误方向"},
	"doors": {"sum": "总人数约束", "exact_structure": "完整数量结构（含严格大小关系）", "door_position": "换门是否影响结果"}
}
const NARRATIVE := {
	"murder": [
		["motive_chain", "女子三因无法接受分手而杀死死者", "女子三(?:因为|因)(?:无法接受分手|不能接受分手|求复合被拒绝)(?:而|所以)?(?:杀死了死者|杀死死者|杀了死者)"],
		["possession_plan", "女子三原本打算附身报案人", "女子三(?:原本|本来)(?:打算|想要|想)(?:附身报案人)"],
		["mislead", "女子三附身侦探后误导调查", "女子三附身侦探后(?:误导调查|把怀疑引向报案人|嫁祸报案人)"],
		["reporter_entered", "报案人在发现尸体时没有进入房间", "报案人(?:发现尸体时|在发现尸体时)?(?:一直|仍然|仍)?(?:留在门外|站在门外|在门外)"],
	],
	"doors": [
		["exact_structure", "四组人数从小到大排序后，最少 < 中间 = 中间 < 最多", "(?:四组人数)?(?:从小到大排序后|排序后)?(?:最少|最低)<中间=中间<(?:最多|最高)"],
		["exact_structure", "中间两组相等，最小组严格更少，最大组严格更多", "排序后中间两组人数相等且最小组严格更少且最大组严格更多"],
		["door_position", "相同四组交换门的位置不影响结果", "(?:相同四组)?(?:换门|交换门的位置)(?:不影响结果|不会改变结果)"],
	]
}

static func review(case_id: String, raw: String) -> Dictionary:
	var rows: Array = []
	var unknown: Array = []
	var seen := {}
	var conflicts: Array = []
	var splitter := RegEx.new()
	splitter.compile("[。；;！!\\n，,]+")
	var divided := splitter.sub(raw, "\n", true)
	for part in divided.split("\n", false):
		var clause := str(part).strip_edges()
		if clause.is_empty(): continue
		var parsed: Dictionary = {}
		if not (clause.contains("?") or clause.contains("？") or clause.ends_with("吗") or clause.contains("可能") or clause.contains("也许")):
			parsed = Questions.parse(case_id, clause)
			if parsed.get("status") != "recognized":
				for row in NARRATIVE[case_id]:
					var regex := RegEx.new()
					regex.compile("^(?:" + str(row[2]) + ")$")
					if regex.search(Questions.normalize(clause)):
						parsed = {"status": "recognized", "id": row[0], "claim": row[1], "answer": true, "raw": clause}
						break
		if parsed.get("status") != "recognized":
			unknown.append(clause)
			continue
		rows.append(parsed)
		if not parsed.answer:
			conflicts.append(clause)
		else:
			seen[parsed.id] = true
	var missing: Array = []
	for key in REQUIRED[case_id]:
		if not seen.has(key): missing.append(REQUIRED[case_id][key])
	return {"rows": rows, "unknown": unknown, "conflicts": conflicts, "missing": missing, "complete": not rows.is_empty() and unknown.is_empty() and conflicts.is_empty() and missing.is_empty()}

static func self_test() -> void:
	var doors := "四组总人数是五十。最低<中间=中间<最高。换门不影响结果。"
	assert(review("doors", doors).complete)
	assert(not review("doors", doors + "最多的一组一定安全。").complete)
	assert(not review("doors", doors + "也许没人会死。").complete)
	assert(not review("doors", "最低<中间=中间<最高").complete)
	assert(not review("doors", "总人数不是50。最低<中间=中间<最高。換門。").complete)
	var murder := "女子三与死者曾是恋人。女子三与死者已经分手。女子三因无法接受分手而杀死死者。女子三主动来到死者家中。门边的冲突与死亡有关。水果刀是凶器。报案人留在门外。侦探是案发后第一位进入现场的人。女子三附身侦探。女子三原本打算附身报案人。女子三附身侦探后误导调查。"
	assert(review("murder", murder).complete)
	assert(not review("murder", murder + "报案人是凶手。").complete)
	assert(not review("murder", murder.replace("女子三附身侦探。", "侦探附身女子三。")).complete)
	assert(not review("murder", murder.replace("女子三因无法接受分手而杀死死者。", "女子三无法接受分手。女子三杀死了死者。")).complete)
