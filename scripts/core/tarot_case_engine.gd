class_name TarotCaseEngine
extends RefCounted

const OPEN_QUESTION_WORDS := ["为什么", "为何", "怎么", "如何", "谁", "什么", "哪里", "哪儿", "何时", "什么时候"]
const CHOICE_QUESTION_WORDS := ["还是", "或者", "或是"]
const NEGATION_WORDS := ["没有", "并没有", "没进入", "没进", "未进入", "从未", "并非", "不是", "不会", "不能", "不影响", "不重要", "不需要", "不相同", "不相等", "不一样", "没结束", "未结束", "无关"]
const NEUTRAL_QUESTION_FORMS := ["有没有", "有无", "会不会", "能不能", "是不是", "可不可以", "要不要"]

var arcana_by_id: Dictionary = {}
var cases: Array = []


func load_data(arcana_path: String, cases_path: String) -> bool:
	var arcana_data := _load_json(arcana_path)
	var case_data := _load_json(cases_path)
	if arcana_data.is_empty() or case_data.is_empty():
		return false
	arcana_by_id.clear()
	for raw_card in arcana_data.get("cards", []):
		var card_data: Dictionary = raw_card
		arcana_by_id[str(card_data.get("id", ""))] = card_data
	cases = case_data.get("cases", [])
	return not arcana_by_id.is_empty() and not cases.is_empty()


func case_at(index: int) -> Dictionary:
	if index < 0 or index >= cases.size():
		return {}
	return cases[index]


func card(card_id: String) -> Dictionary:
	return arcana_by_id.get(card_id, {})


func reading_for(case_data: Dictionary, card_id: String, image_id: String, question: String) -> Dictionary:
	return _resolve_reading(case_data, card_id, image_id, [], question)


func cross_reading_for(case_data: Dictionary, first_card: String, second_card: String, question: String) -> Dictionary:
	return _resolve_reading(case_data, "", "", [first_card, second_card], question)


func validate_question(question: String) -> Dictionary:
	var normalized := _normalize(question)
	if normalized.length() < 4:
		return _invalid("问题太短。请写明人物或条件，以及你想确认的事实。")
	var neutral_probe := normalized.replace("有没有", "").replace("有无", "")
	for word in CHOICE_QUESTION_WORDS:
		if neutral_probe.contains(word):
			return _invalid("一次 Reading 只能确认一个判断。请把选择题拆成一个 YES / NO 问题。")
	if normalized.count("吗") > 1 or question.count("？") + question.count("?") > 1:
		return _invalid("一次 Reading 只能提出一个问题。请拆开后再问。")
	for word in OPEN_QUESTION_WORDS:
		if normalized.contains(word):
			return _invalid("系统只回答 YES / NO / 无关。请把开放问题改写成一个可确认的判断。")
	return {"valid": true, "consume_round": true}


func evaluate_solution(case_data: Dictionary, answer: String) -> Dictionary:
	var matched := 0
	var missing: Array[String] = []
	for raw_group in case_data.get("solution_groups", []):
		var group: Array = raw_group
		if _matches_any(answer, group):
			matched += 1
		else:
			missing.append(_group_hint(group))
	var required := int(case_data.get("solution_required", case_data.get("solution_groups", []).size()))
	return {
		"success": matched >= required,
		"matched": matched,
		"required": required,
		"missing": missing,
	}


func draw_three(case_data: Dictionary, confirmed: Dictionary, miss_streak: int, rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array = case_data.get("deck", []).duplicate()
	var result: Array[String] = []
	if miss_streak >= 2:
		for raw_rule in case_data.get("readings", []):
			var focus_id := str((raw_rule as Dictionary).get("card", ""))
			if not focus_id.is_empty() and not confirmed.has(focus_id) and pool.has(focus_id):
				result.append(focus_id)
				pool.erase(focus_id)
				break
	while result.size() < 3 and not pool.is_empty():
		var pick := rng.randi_range(0, pool.size() - 1)
		result.append(str(pool[pick]))
		pool.remove_at(pick)
	return result


func _resolve_reading(case_data: Dictionary, card_id: String, image_id: String, cross_cards: Array, question: String) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var source: Array = case_data.get("cross_readings", []) if not cross_cards.is_empty() else case_data.get("readings", [])
	for raw_rule in source:
		var rule: Dictionary = raw_rule
		var score := _semantic_score(rule, question)
		if score > 0:
			candidates.append({"rule": rule, "score": score})
	if candidates.is_empty():
		var validation := validate_question(question)
		if not bool(validation.get("valid", false)):
			return validation
		var other_case := _find_other_case_match(str(case_data.get("id", "")), question)
		if not other_case.is_empty():
			return {
				"result": "切换案件",
				"fact": "",
				"critical": false,
				"consume_round": false,
				"reason": "这个问题属于《%s》，而当前案件是《%s》。请先点击左侧的“%s”再提问。" % [str(other_case.get("title", "另一案件")), str(case_data.get("title", "当前案件")), str(other_case.get("title", "另一案件"))],
				"match_kind": "other_case",
				"suggested_case_id": str(other_case.get("id", "")),
			}
		return {
			"result": "无关",
			"fact": "",
			"critical": false,
			"consume_round": true,
			"reason": "这个问题可以判断，但当前案件的已知事实无法给出可靠的 YES 或 NO。请换一个更具体的对象、关系、动作、时间或数值条件。",
			"match_kind": "unknown",
		}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score))
	var best_aligned: Dictionary = {}
	var best_misaligned: Dictionary = candidates[0]
	for candidate in candidates:
		var rule: Dictionary = candidate.rule
		if not cross_cards.is_empty():
			if _same_pair(rule.get("cards", []), cross_cards):
				best_aligned = candidate
				break
		elif str(rule.get("card", "")) == card_id and str(rule.get("image", "")) == image_id:
			best_aligned = candidate
			break
	if best_aligned.is_empty():
		return _misaligned_result(best_misaligned.rule, card_id, image_id, not cross_cards.is_empty())
	var matched_rule: Dictionary = best_aligned.rule.duplicate(true)
	var validation := validate_question(question)
	if not bool(validation.get("valid", false)) and not bool(matched_rule.get("allow_open", false)):
		return validation
	var truth := bool(matched_rule.get("truth", str(matched_rule.get("result", "YES")) == "YES"))
	if _is_negated(question, matched_rule):
		truth = not truth
	matched_rule["result"] = "YES" if truth else "NO"
	matched_rule["consume_round"] = true
	matched_rule["match_kind"] = "semantic"
	matched_rule["reason"] = str(matched_rule.get("fact", ""))
	return matched_rule


func _find_other_case_match(current_case_id: String, question: String) -> Dictionary:
	var best_case: Dictionary = {}
	var best_score := 0
	for raw_case in cases:
		var other_case: Dictionary = raw_case
		if str(other_case.get("id", "")) == current_case_id:
			continue
		for raw_rule in other_case.get("readings", []):
			var score := _semantic_score(raw_rule as Dictionary, question)
			if score > best_score:
				best_score = score
				best_case = other_case
	return best_case


func _semantic_score(rule: Dictionary, question: String) -> int:
	var normalized := _normalize(question)
	var score := 0
	for raw_phrase in rule.get("match", []):
		var phrase := _normalize(str(raw_phrase))
		if not phrase.is_empty() and normalized.contains(phrase):
			score += 8 + mini(phrase.length(), 8)
	var groups: Array = rule.get("concepts", [])
	var matched_groups := 0
	for raw_group in groups:
		if _matches_any(normalized, raw_group as Array):
			matched_groups += 1
			score += 4
	var required := int(rule.get("required_concepts", groups.size()))
	if not groups.is_empty() and matched_groups < required:
		return 0
	for raw_excluded in rule.get("exclude", []):
		if normalized.contains(_normalize(str(raw_excluded))):
			return 0
	return score


func _misaligned_result(rule: Dictionary, selected_card: String, selected_image: String, is_cross: bool) -> Dictionary:
	var expected_card := str(rule.get("card", ""))
	var expected_image := str(rule.get("image", ""))
	var reason := "问题含义可以识别，但与本次 Reading 的牌义不一致。"
	if is_cross:
		reason = "问题含义可以识别，但不属于当前两张牌能够共同确认的关系。"
	elif expected_card == selected_card:
		var image_name := _image_label(expected_card, expected_image)
		reason = "问题方向与所选牌一致，但更接近“%s”意象。请改读该意象，或围绕当前意象重新提问。" % image_name
	else:
		var expected := card(expected_card)
		reason = "问题含义可以识别，但当前牌义不覆盖它。它更接近“%s”的方向：%s。" % [str(expected.get("name_zh", expected_card)), str(expected.get("theme", ""))]
	return {
		"result": "无关",
		"fact": "",
		"critical": false,
		"consume_round": true,
		"reason": reason,
		"match_kind": "misaligned",
	}


func _invalid(reason: String) -> Dictionary:
	return {
		"valid": false,
		"result": "需要改写",
		"fact": "",
		"critical": false,
		"consume_round": false,
		"reason": reason,
		"match_kind": "invalid",
	}


func _is_negated(text: String, rule: Dictionary = {}) -> bool:
	var probe := _normalize(text)
	for form in NEUTRAL_QUESTION_FORMS:
		probe = probe.replace(form, "")
	for word in NEGATION_WORDS:
		if probe.contains(_normalize(word)):
			return true
	for raw_word in rule.get("negative_match", []):
		if probe.contains(_normalize(str(raw_word))):
			return true
	return false


func _same_pair(first: Array, second: Array) -> bool:
	if first.size() != 2 or second.size() != 2:
		return false
	var first_copy := first.duplicate()
	var second_copy := second.duplicate()
	first_copy.sort()
	second_copy.sort()
	return first_copy == second_copy


func _image_label(card_id: String, image_id: String) -> String:
	for raw_image in card(card_id).get("images", []):
		var image_data: Dictionary = raw_image
		if str(image_data.get("id", "")) == image_id:
			return str(image_data.get("label", "牌面元素"))
	return "另一个牌面元素"


func _matches_any(text: String, terms: Array) -> bool:
	var normalized := _normalize(text)
	for raw_term in terms:
		if normalized.contains(_normalize(str(raw_term))):
			return true
	return false


func _normalize(text: String) -> String:
	var normalized := text.to_lower().replace(" ", "").replace("\n", "").replace("？", "").replace("?", "").replace("，", "").replace(",", "").replace("。", "").replace("！", "").replace("!", "")
	var replacements := {
		"报警的人": "报警人",
		"报案人": "报警人",
		"受害者": "死者",
		"受害人": "死者",
		"死掉的人": "死者",
		"行凶者": "凶手",
		"杀人者": "凶手",
		"屋子里": "房间",
		"屋里面": "房间",
		"屋内": "房间",
		"家里面": "家",
		"走进": "进入",
		"进去过": "进入过",
		"进到": "进入",
		"谈过恋爱": "恋爱",
		"在一起过": "恋人",
		"一样多": "相等",
		"数量一样": "相等",
		"相同数量": "相等",
		"数目": "人数",
		"队伍": "组",
		"四队": "四组",
		"丢掉": "扔",
		"谋杀": "杀害",
	}
	for source in replacements:
		normalized = normalized.replace(str(source), str(replacements[source]))
	return normalized


func _group_hint(group: Array) -> String:
	if group.is_empty():
		return "仍缺少一个关键环节"
	return str(group[0])


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing tarot data: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid tarot data: %s" % path)
		return {}
	return parsed
