extends RefCounted

const Bank = preload("res://scripts/question_bank.gd")

# Closed-domain, anchored grammar. Unsupported words are NOT discarded.
# Each row: fact id, affirmative statement, truth, positive grammar, negative grammar.
static var FACTS: Dictionary = Bank.database().fact_definitions

static var TOPICS: Dictionary = Bank.database().fact_topics

static func suggest(case_id: String, raw: String, allowed: Array = []) -> Array:
	# Suggestions deliberately do not claim to understand the original sentence.
	# The player must choose a rewritten proposition before asking for its truth.
	var text := normalize(raw)
	var candidates: Array = []
	for row in FACTS.get(case_id, []):
		if not allowed.is_empty() and not allowed.has(row[0]): continue
		var topic: Array = TOPICS[row[0]]
		if not str(topic[0]).is_empty() and not text.contains(str(topic[0])):
			continue
		var score := 0
		for word in topic[1]:
			if text.contains(word):
				score += 1
		if score == 0:
			continue
		candidates.append({"status": "recognized", "id": row[0], "claim": row[1], "answer": row[2], "negative": false, "raw": raw, "score": score, "rewritten": true})
	candidates.sort_custom(func(a, b): return a.score > b.score)
	return candidates.slice(0, 2)

static func normalize(raw: String) -> String:
	var s := raw.strip_edges()
	var synonyms := [["报案的人", "报案人"], ["报案者", "报案人"], ["女子二", "报案人"], ["女二", "报案人"], ["女子2", "报案人"], ["女子一", "死者"], ["女一", "死者"], ["女子1", "死者"], ["女三", "女子三"], ["女子3", "女子三"], ["和", "与"], ["看到", "看见"], ["屋子", "房间"], ["进屋", "进入过房间"], ["有没有", ""], ["是不是", "是"], ["是否", ""], ["请问", ""], ["我想问", ""]]
	for pair in synonyms:
		s = s.replace(pair[0], pair[1])
	for mark in [" ", "　", "\n", "\r", "\t", "？", "?", "。", "吗", "呢"]:
		s = s.replace(mark, "")
	s = s.trim_suffix("了")
	return s

static func parse(case_id: String, raw: String, card_id: String = "") -> Dictionary:
	if raw.strip_edges().is_empty():
		return {"status": "clarify", "message": "请先输入一个你想求证的问题。"}
	if raw.length() > 120:
		return {"status": "clarify", "message": "请把问题缩短到 120 字以内，一次只问一件事。"}
	for phrase in ["没有没有", "不是不是", "并非没有", "并非不是", "不能不", "不得不"]:
		if raw.contains(phrase):
			return {"status": "clarify", "message": "这句话包含多重否定，请改成直接的肯定或否定问题。"}
	var text := normalize(raw)
	var entry := Bank.lookup(case_id, raw, card_id)
	if not entry.is_empty():
		if entry.status != "bank_fact": return entry
		for row in FACTS.get(case_id, []):
			if row[0] == entry.id:
				return {"status": "recognized", "id": row[0], "claim": ("并非：" if entry.negative else "") + row[1], "answer": not bool(row[2]) if entry.negative else bool(row[2]), "negative": entry.negative, "raw": raw, "source": "authored_bank"}
	if case_id == "doors":
		if matches("(?:保持)?(?:四组)?人数不变[，,]?(?:结果|结局)(?:是否|会不会|会)?(?:变化|改变)", text):
			return {"status": "clarify", "message": "人数保持不变时，你改变的是哪一项：门的位置，还是其他条件？请补充改变的操作，我才能判断结果；本次不计次数。"}
		if matches("(?:保持)?(?:四组)?人数不变[，,]?(?:只)?(?:换门|交换门的位置)[，,]?(?:结果|结局)(?:会|是否|会不会)?(?:变化|改变)", text):
			return quantity_claim("door_position", "保持四组人数不变，只交换门的位置会改变结果", false, raw)
		var experiment := parse_experiment(raw)
		if not experiment.is_empty(): return experiment
		var short_rule := parse_quantity_rule(text, raw)
		if not short_rule.is_empty():
			return short_rule
	for word in ["并且", "同时", "而且", "或者", "以及", "，", ",", "如果", "假如", "因为", "所以"]:
		if text.contains(word):
			return {"status": "clarify", "message": "这句话包含条件或多个判断，请拆成单独的是非问题。"}
	if text.begins_with("她") or text.begins_with("他") or text.begins_with("他们"):
		return {"status": "clarify", "message": "你指的是谁？请把代词换成人物名称，再问一次。"}
	for row in FACTS.get(case_id, []):
		for polarity in [3, 4]:
			var regex := RegEx.new()
			regex.compile("^(?:" + str(row[polarity]) + ")$")
			if regex.search(text) != null:
				var negative: bool = polarity == 4
				return {"status": "recognized", "id": row[0], "claim": ("并非：" if negative else "") + row[1], "answer": not bool(row[2]) if negative else bool(row[2]), "negative": negative, "raw": raw}
	return {"status": "unsupported", "message": "暂时无法可靠理解这句话，不计次数，也不作 YES/NO 判断。请明确人物、动作与时间；目前支持进入、目击、关系、来访、死因或数量规则等是非问题。"}

static func parse_experiment(raw: String) -> Dictionary:
	var regex := RegEx.new()
	regex.compile("^(?:测试|试试|实验)\\s*([0-9]+)[、，, /]+([0-9]+)[、，, /]+([0-9]+)[、，, /]+([0-9]+)(?:能通过吗|能活吗|可以吗)?[？?。]?$" )
	var found := regex.search(raw.strip_edges())
	if not found: return {}
	var numbers: Array[int] = []
	for i in range(1, 5):
		if found.get_string(i).length() > 3:
			return {"status": "clarify", "message": "总人数只有50，请输入合理的四组正整数人数，不扣次数。"}
		numbers.append(int(found.get_string(i)))
	var total := 0
	for n in numbers: total += n
	if total != 50 or numbers.min() < 1:
		return {"status": "clarify", "message": "实验须分成四个非空组，人数为正整数且总和为50。你给的总和是%d；请调整，不扣次数。" % total}
	var sorted := numbers.duplicate()
	sorted.sort()
	var answer: bool = sorted[0] < sorted[1] and sorted[1] == sorted[2] and sorted[2] < sorted[3]
	return {"status": "recognized", "id": "experiment:%d:%d:%d:%d" % sorted, "claim": "分组 %s 能满足生路规则（只检验这个例子，不代表一般规律）" % str(numbers), "answer": answer, "raw": raw, "negative": false, "source": "computed_experiment"}

static func matches(pattern: String, text: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^(?:" + pattern + ")$")
	return regex.search(text) != null

static func quantity_claim(id: String, claim: String, answer: bool, raw: String) -> Dictionary:
	return {"status": "recognized", "id": id, "claim": claim, "answer": answer, "negative": false, "raw": raw}

static func verdict(response: Dictionary) -> String:
	return "对你确认的命题：\n「%s」\n%s" % [response.claim, "YES · 这句话成立。" if response.answer else "NO · 这句话不成立。"]

static func parse_quantity_rule(text: String, raw: String) -> Dictionary:
	var bad := "(?:死|死亡|失败|不安全|坠入深渊|不能活|不能生还|不能成功)"
	var good := "(?:活|活着|生还|成功|安全|通过|不死|不会死)"
	var implies := "(?:就会|就|会|就要|一定会|就一定会|就能|能|一定)?"
	var all_distinct := quantity_claim("all_distinct_failure", "四组人数各不相同，没有任何两组相等，就无法成功", true, raw)
	var some_different := quantity_claim("some_different_failure", "只要其中两组人数不同，就一定无法成功", false, raw)
	if matches("(?:如果)?(?:人数)?(?:不相等|不一样|不同)" + implies + bad, text) or matches("(?:如果)?两组(?:人数)?(?:不相等|不一样|不同)" + implies + bad, text):
		return {"status": "clarify_scope", "message": "你说的‘不相等’是哪一种？范围不同，答案也会不同。", "options": [all_distinct, some_different]}
	if matches("(?:如果)?(?:四组|四组人数|所有组人数)(?:都不同|都不相等|各不相同|两两不同|都不一样)" + implies + bad, text) or matches("(?:如果)?(?:没有|没有任何|不存在)(?:两组|两组人数)(?:相等|相同|一样)" + implies + bad, text):
		return all_distinct
	if matches("(?:如果|只要)?(?:有|有任意|其中任意)(?:两组|两组人数)(?:不同|不相等|不一样)" + implies + bad, text):
		return some_different
	var enough := quantity_claim("equal_sufficient", "只要存在两组人数相等，就一定能成功", false, raw)
	if matches("(?:如果|只要)?(?:有|存在)?(?:两组|两组人数)(?:相等|相同|一样)" + implies + good, text):
		return enough
	if matches("(?:人数)?(?:相等|相同|一样)" + implies + good, text):
		var all_equal := quantity_claim("all_equal_sufficient", "四组人数全部相等就可以成功", false, raw)
		return {"status": "clarify_scope", "message": "你指的是有两组相等，还是四组全部相等？", "options": [enough, all_equal]}
	return {}

static func self_test() -> void:
	assert(parse("doors", "保持四组人数不变 结果是否变化").status == "clarify")
	assert(parse("doors", "保持四组人数不变，结果是否变化").status == "clarify")
	assert(not parse("doors", "保持四组人数不变，只换门，结果是否变化").answer)
	assert(parse("doors", "保持四组人数不变，只换门，结果不变化吗").status != "recognized")
	var yes: Array = ["报案人看见尸体了吗？", "报案的人是否没有进入过房间？", "女子三去过死者家吗", "女子一和女子三曾是恋人吗", "门向外开吗", "侦探被附身了吗"]
	for question in yes:
		var result := parse("murder", question)
		assert(result.status == "recognized" and result.answer, question)
	var no: Array = ["报案的人进屋了吗？", "报案人是不是凶手？", "女子三没去过死者家吗", "门向内开吗", "侦探没有被附身吗"]
	for question in no:
		var result := parse("murder", question)
		assert(result.status == "recognized" and not result.answer, question)
	for question in ["她进屋了吗", "报案人进入了房间而且拿走了刀吗", "如果报案人进入了房间会死吗", "报案人后来进入过房间吗", "报案人没有没有进入过房间吗", "水果刀是红色的吗", "谁是凶手"]:
		assert(parse("murder", question).status != "recognized", question)
	assert(parse("doors", "交换门的位置不影响结果吗").answer)
	assert(not parse("doors", "任意两组人数相等就一定成功吗").answer)
	var scope := parse("doors", "不相等就会死")
	assert(scope.status == "clarify_scope" and scope.options[0].answer and not scope.options[1].answer)
	assert(parse("doors", "四组人数都不同就会死吗").answer)
	assert(parse("doors", "没有任何两组人数相等就会死").answer)
	assert(not parse("doors", "只要两组人数相等就能活").answer)
	assert(not parse("doors", "有两组人数不一样就会死").answer)
	print("PASS: local questions; synonyms, negation, ambiguity, unknown topics, compound and temporal guards")
