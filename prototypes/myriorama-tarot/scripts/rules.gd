extends RefCounted

# The authored clue paths are prototype proposals, not a replacement for the source story.
const CASES := {
	"murder": {
		"title": "门外的目击者", "subtitle": "档案 01  /  海龟汤",
		"surface": "实习生升职的那天，一名女子被发现死在家中。门向外开，门边留下激烈挣扎的痕迹，垃圾桶里有一把沾血的水果刀。\n\n报案人说，她在门外看见了尸体。侦探随后进入现场，并把怀疑引向报案人。\n\n谁在说谎？看见尸体，是否就意味着进过这扇门？",
		"main": ["09", "10", "12", "07", "13", "14", "16", "18"],
		"support": ["11", "15", "17", "05"],
		"truth": "女子三与死者曾有亲密关系。关系结束后，她仍无法接受，前来求复合；遭到拒绝后，在门边冲突中杀死死者。\n\n她原本打算附身后来进入的报案人，但报案人一直留在门外。案发后先进入现场的外来调查者是侦探；女子三转而附身侦探，误导调查。\n\n这是文档中的超自然设定；附身条件与公平线索仍需要补充确认。",
		"facts": {
			"09": ["旧日关系", "女子一与女子三曾有亲密关系", "这段旧关系是案件动机的起点。"],
			"10": ["关系结束", "这段亲密关系在案发前已经结束", "结束的关系与无法接受结束，不是同一件事。"],
			"12": ["占有与执念", "女子三无法接受这段关系的结束", "注意控制欲，而不只是爱情。"],
			"07": ["主动来访", "女子三主动来到死者家中", "来访使动机进入了实际行动。"],
			"13": ["门边冲突", "门边的挣扎与死亡直接相关", "冲突不是一条与死因无关的装饰线索。"],
			"14": ["死亡结果", "水果刀是造成死亡的凶器", "把实际死因与后来发生的误导分开。"],
			"16": ["内外边界", "报案人在发现尸体时仍留在门外", "看见尸体不等于进入房间。"],
			"18": ["隐藏的操纵", "侦探受到一个未被看见的力量影响", "文档设定包含附身；这一机制仍需补充公平提示。"],
			"11": ["关系转移", "死者另有所爱与来访者的情绪相关", "这是动机的补充，不等于完整的行动链。"],
			"15": ["表象误导", "对报案人的怀疑包含错误推断", "不要把表象自动当成事实。"],
			"17": ["发现与报案", "报案人看见尸体后报告了事件", "报案动作本身不能证明行凶。"],
			"05": ["证据复核", "进入现场的先后值得重新核实", "核实证据比接受侦探的结论更重要。"]
		},
		"false_claim": "报案人看见尸体，足以证明她进入过房间"
	},
	"doors": {
		"title": "五十人与四扇门", "subtitle": "档案 02  /  规则海龟汤",
		"surface": "五十个人分成四组，分别走向四扇门。某些分组能通往生路，另一些却会坠入深渊。\n\n人数最多的组不一定安全，人数最少的组也不一定危险；仅发现两组人数相等，仍然不足以解释结果。\n\n生路取决于怎样的数量关系？把相同的四组换到不同门前，结果会改变吗？",
		"main": ["01", "04", "02", "05", "06", "03"],
		"support": ["07", "08"],
		"truth": "将四组人数从小到大排列，必须满足：最低 < 中间 = 中间 < 最高。\n\n恰好中间两组相等，两端严格更低、更高。总人数仍为五十。具体是哪一扇门不影响判定。\n\n例如 5、10、10、25 成立；5、5、15、25 不成立。这里的拼牌是推理顺序，最后还需要验证数量结构。",
		"facts": {
			"01": ["观察对应", "两组人数相等是成功条件的一部分", "相等是线索，但不是全部。"],
			"04": ["检验反例", "只出现任意两组相等仍可能失败", "寻找能推翻过度简单规律的反例。"],
			"02": ["建立顺序", "需要先比较四组人数的大小顺序", "从无序的四组走向可比较的结构。"],
			"05": ["比较中间", "相等的两组需要处于排序后的中间", "两端不能与中间并列。"],
			"06": ["控制实验", "主动改变分组可以测试候选规则", "保持总人数五十，测试是否仍然成立。"],
			"03": ["位置不变性", "相同四组交换门的位置不影响结果", "数量结构与具体门号是两件事。"],
			"07": ["执行选择", "进入哪扇门本身不是唯一判据", "行动与决定行动结果的规则要分开。"],
			"08": ["生路目标", "成功的分组存在可重复验证的规律", "希望只是方向，还需要证据。"]
		},
		"false_claim": "只要有任意两组人数相等，就一定能成功"
	}
}

static func make_deal(case_id: String, rng: RandomNumberGenerator) -> Array:
	var spec: Dictionary = CASES[case_id]
	var result: Array = spec.main.duplicate()
	result.append_array(spec.support)
	var extras: Array = []
	for n in range(1, 19):
		var id := "%02d" % n
		if not result.has(id):
			extras.append(id)
	shuffle_with_rng(extras, rng)
	while result.size() < 15:
		result.append(extras.pop_back())
	shuffle_with_rng(result, rng)
	return result

static func shuffle_with_rng(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var old: Variant = items[i]
		items[i] = items[j]
		items[j] = old

static func evaluate(case_id: String, selected: Array) -> Dictionary:
	var expected: Array = CASES[case_id].main
	var related := 0
	for id in selected:
		if expected.has(id):
			related += 1
	var connected := 0
	for i in range(selected.size() - 1):
		var at := expected.find(selected[i])
		if at >= 0 and at < expected.size() - 1 and expected[at + 1] == selected[i + 1]:
			connected += 1
	return {"related": related, "connections": connected, "required": expected.size(), "complete": selected == expected}

static func doors_rule(groups: Array) -> bool:
	if groups.size() != 4:
		return false
	var total := 0
	for n in groups:
		if n < 1 or int(n) != n:
			return false
		total += int(n)
	var ordered := groups.duplicate()
	ordered.sort()
	return total == 50 and ordered[0] < ordered[1] and ordered[1] == ordered[2] and ordered[2] < ordered[3]
