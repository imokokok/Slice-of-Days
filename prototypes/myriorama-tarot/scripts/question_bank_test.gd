extends RefCounted

const Parser = preload("res://scripts/question_engine.gd")
const Guidance = preload("res://scripts/card_guidance.gd")
const Rules = preload("res://scripts/rules.gd")

static func run() -> void:
	var db: Dictionary = Parser.Bank.database()
	var unique := {}
	var assertions := 0
	for group in db.facts:
		var source: Array = []
		for row in Parser.FACTS[group.case]:
			if row[0] == group.id: source = row
		assert(not source.is_empty(), "Dangling bank fact: " + group.id)
		for phrase in group.aliases:
			var key := str(group.case) + ":" + Parser.Bank.key(phrase)
			assert(not unique.has(key), "Duplicate phrase: " + key)
			unique[key] = true
			for input in [str(phrase), "请问" + str(phrase) + "？"]:
				var result: Dictionary = Parser.parse(group.case, input)
				assert(result.status == "recognized" and result.id == group.id, input)
				var expected: bool = not bool(source[2]) if group.get("negative", false) else bool(source[2])
				assert(result.answer == expected, input)
				assert(bool(result.negative) == bool(group.get("negative", false)), input)
				assertions += 1
	for group in db.responses:
		for case_id in ["doors", "murder"]:
			if group.case not in ["*", case_id]: continue
			for phrase in group.aliases:
				var key := str(case_id) + ":" + Parser.Bank.key(phrase)
				assert(not unique.has(key), "Duplicate response: " + key)
				unique[key] = true
				var result: Dictionary = Parser.parse(case_id, phrase)
				assert(result.status == group.status, phrase)
				assert(not result.has("answer"), "Non-fact must not supply YES/NO: " + str(phrase))
				assertions += 1
	for group in db.visuals:
		for case_id in ["doors", "murder"]:
			for phrase in group.aliases:
				var result: Dictionary = Parser.parse(case_id, phrase, group.card)
				assert(result.status in ["guidance", "clarify", "unwritten"], phrase)
				assert(not result.has("answer"), phrase)
				assertions += 1
	# Adversarial tests are not auto-generated answer-bearing aliases.
	for question in ["报案人第二天进门了吗", "女三从来没杀过任何人吗", "死者被侦探附身了吗", "报案人喜欢死者吗", "女子三没有没有杀死死者吗", "女子三不是不是凶手吗", "报案人进去而且杀人了吗", "只要报案人进屋就会死吗", "侦探是凶手还是女三", "杯子上的花纹证明女三是凶手吗", "女子三当时可能杀了死者吗", "侦探被鬼附体了吗"]:
		assert(Parser.parse("murder", question).status != "recognized", question)
		assertions += 1
	assert(not Guidance.allows("murder", "02", "hidden_killer"))
	assert(Guidance.allows("doors", "06", "experiment:4:11:11:24"))
	var valid := Parser.parse("doors", "测试 4、11、11、24")
	assert(valid.status == "recognized" and valid.answer)
	assert(Parser.parse("doors", "测试 24、11、4、11").id == valid.id)
	assert(not Parser.parse("doors", "测试 5、5、15、25").answer)
	for phrase in ["测试 0、10、10、30", "测试 5、10、10、26", "测试 999999999999999999、1、1、1"]:
		assert(Parser.parse("doors", phrase).status == "clarify", phrase)
	for a in range(1, 15):
		for b in range(1, 15):
			var numbers := [a, b, 10, 40 - a - b]
			var result: Dictionary = Parser.parse("doors", "测试 %d、%d、%d、%d" % numbers)
			assert(result.answer == Rules.doors_rule(numbers))
			assertions += 1
	print("PASS: question bank assertions=" + str(assertions) + "; authored statistics=" + JSON.stringify(Parser.Bank.statistics()))
