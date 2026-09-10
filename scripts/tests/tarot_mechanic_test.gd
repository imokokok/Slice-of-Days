extends Node

const TarotEngine = preload("res://scripts/core/tarot_case_engine.gd")

var failures: Array[String] = []


func _ready() -> void:
	var engine := TarotEngine.new()
	_check(engine.load_data("res://data/tarot/major_arcana.json", "res://data/tarot/cases.json"), "tarot data should load")
	_check(engine.arcana_by_id.size() == 22, "the major arcana catalog should contain 22 cards")
	_check(engine.cases.size() == 2, "both document cases should be playable")
	_validate_case_coverage(engine)

	var doors := engine.case_at(0)
	var structure := engine.reading_for(doors, "emperor", "square", "四组人数之间存在固定的数值结构吗？")
	_check(str(structure.get("result", "")) == "YES", "Emperor structure question should return YES")
	var structure_paraphrase := engine.reading_for(doors, "emperor", "square", "这四组人的数量是不是遵循某种规律？")
	_check(str(structure_paraphrase.get("result", "")) == "YES", "natural paraphrases should match semantic concepts")
	var wrong_image := engine.reading_for(doors, "emperor", "throne", "四组人数之间存在固定的数值结构吗？")
	_check(str(wrong_image.get("result", "")) == "无关" and str(wrong_image.get("match_kind", "")) == "misaligned", "a mismatched image should explain the misalignment")
	_check(str(wrong_image.get("reason", "")).contains("方正构图"), "a wrong image should suggest the relevant image without losing the round result")
	var neutral_negative_form := engine.reading_for(doors, "wheel", "turning", "门的位置会不会影响结果？")
	_check(str(neutral_negative_form.get("result", "")) == "NO", "会不会 should be treated as a neutral yes/no form")
	var explicit_negative := engine.reading_for(doors, "wheel", "turning", "门的位置不会影响结果吗？")
	_check(str(explicit_negative.get("result", "")) == "YES", "an explicitly negated proposition should invert the answer")
	var negative_equality := engine.reading_for(doors, "temperance", "cups", "两组人数不一样也满足条件吗？")
	_check(str(negative_equality.get("result", "")) == "NO", "negative equality wording should be understood")
	var open_hint := engine.reading_for(doors, "star", "main_star", "下一步应该查什么？")
	_check(str(open_hint.get("result", "")) == "YES", "The Star should allow its documented open hint question")
	var unknown_question := engine.reading_for(doors, "star", "main_star", "天气会影响开门吗？")
	_check(str(unknown_question.get("result", "")) == "无关" and bool(unknown_question.get("consume_round", false)), "an in-scope yes/no form with no known fact should be unrelated")
	var other_case_question := engine.reading_for(doors, "temperance", "cups", "报警的人有没有走进过屋子里？")
	_check(str(other_case_question.get("result", "")) == "切换案件", "a question from the other case should be identified")
	_check(not bool(other_case_question.get("consume_round", true)) and str(other_case_question.get("reason", "")).contains("门外的目击者"), "wrong-case questions should point to the correct case without consuming the round")
	_check(str(other_case_question.get("suggested_case_id", "")) == "doorway_murder", "wrong-case guidance should expose a safe local case-switch target")
	var cross := engine.cross_reading_for(doors, "temperance", "emperor", "相等和大小关系必须同时成立吗？")
	_check(str(cross.get("result", "")) == "YES", "configured cross reading should work in either card order")
	var solved_doors := engine.evaluate_solution(doors, "恰好两组人数相同，相同值位于另外两组之间，门的位置不影响结果。")
	_check(bool(solved_doors.get("success", false)), "complete four doors solution should pass")
	var incomplete_doors := engine.evaluate_solution(doors, "只要两组人数相同就会开门。")
	_check(not bool(incomplete_doors.get("success", false)), "incomplete four doors solution should fail")
	_check((incomplete_doors.get("missing", []) as Array).has("相等值与其余两组的大小关系"), "solution feedback should use authored non-spoiler hints")

	var murder := engine.case_at(1)
	_check(not str(murder.get("opening", "")).contains("女1"), "case copy should use names instead of numbered women")
	_check(not str(murder.get("opening", "")).contains("男1"), "case copy should use names instead of numbered men")
	var solved_murder := engine.evaluate_solution(murder, "凶手是塞琳。她因关系结束仍有执念，在艾琳到达前先进入并杀死米拉。艾琳只在门外看到尸体，没有进入。")
	_check(bool(solved_murder.get("success", false)), "complete murder solution should pass")
	var erin_entered := engine.reading_for(murder, "chariot", "city", "报警的人有没有走进过屋子里？")
	_check(str(erin_entered.get("result", "")) == "NO", "aliases and movement paraphrases should resolve locally")
	var erin_did_not_enter := engine.reading_for(murder, "chariot", "city", "艾琳是不是没进屋？")
	_check(str(erin_did_not_enter.get("result", "")) == "YES", "negated entry questions should invert the canonical fact")
	var former_lovers := engine.reading_for(murder, "lovers", "gaze", "米拉与塞琳以前谈过恋爱吗？")
	_check(str(former_lovers.get("result", "")) == "YES", "relationship paraphrases should be recognized")
	var selene_killer := engine.reading_for(murder, "justice", "gaze", "杀害米拉的人是不是塞琳？")
	_check(str(selene_killer.get("result", "")) == "YES", "reordered killer questions should be recognized")
	var wrong_card := engine.reading_for(murder, "lovers", "gaze", "塞琳是杀害米拉的凶手吗？")
	_check(str(wrong_card.get("match_kind", "")) == "misaligned" and str(wrong_card.get("reason", "")).contains("正义"), "recognized questions on the wrong card should explain the proper direction")
	var open_question := engine.reading_for(murder, "justice", "gaze", "谁杀了米拉？")
	_check(not bool(open_question.get("consume_round", true)) and str(open_question.get("result", "")) == "需要改写", "open questions should be rejected without consuming the round")
	var choice_question := engine.reading_for(murder, "justice", "gaze", "凶手是艾琳还是塞琳？")
	_check(not bool(choice_question.get("consume_round", true)), "choice questions should be split before a Reading is consumed")

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var draw := engine.draw_three(doors, {}, 2, rng)
	_check(draw.size() == 3, "each round should draw three cards")
	_check(draw[0] == "emperor", "the third miss round should prioritize an unresolved relevant card")
	_check(draw[0] != draw[1] and draw[1] != draw[2] and draw[0] != draw[2], "a draw should not contain duplicates")

	if failures.is_empty():
		print("TAROT MECHANIC TEST PASSED")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _validate_case_coverage(engine: TarotCaseEngine) -> void:
	for raw_case in engine.cases:
		var case_data: Dictionary = raw_case
		var deck: Array = case_data.get("deck", [])
		_check(deck.size() >= 6 and deck.size() <= 9, "%s should use a 6–9 card case deck" % str(case_data.get("id", "case")))
		var opening_draw: Array = case_data.get("opening_draw", [])
		_check(opening_draw.size() == 3, "%s should define a three-card onboarding draw" % str(case_data.get("id", "case")))
		for opening_card in opening_draw:
			_check(deck.has(str(opening_card)), "%s opening draw should only use cards from its deck" % str(case_data.get("id", "case")))
		var covered_cards: Dictionary = {}
		for raw_rule in case_data.get("readings", []):
			var rule: Dictionary = raw_rule
			var card_id := str(rule.get("card", ""))
			var image_id := str(rule.get("image", ""))
			_check(deck.has(card_id), "%s reading card should belong to its case deck" % str(rule.get("id", "rule")))
			_check(_card_has_image(engine.card(card_id), image_id), "%s should reference a real card image" % str(rule.get("id", "rule")))
			_check(not (rule.get("concepts", []) as Array).is_empty(), "%s should define semantic concept groups" % str(rule.get("id", "rule")))
			_check(not str(rule.get("fact", "")).is_empty(), "%s should define a factual response" % str(rule.get("id", "rule")))
			covered_cards[card_id] = true
		for card_id in deck:
			_check(covered_cards.has(str(card_id)), "%s should have at least one local reading rule" % str(card_id))
		for raw_cross in case_data.get("cross_readings", []):
			var cross: Dictionary = raw_cross
			var pair: Array = cross.get("cards", [])
			_check(pair.size() == 2 and deck.has(str(pair[0])) and deck.has(str(pair[1])), "%s should connect two cards in the case deck" % str(cross.get("id", "cross")))
			_check(not (cross.get("concepts", []) as Array).is_empty(), "%s should define cross-reading concepts" % str(cross.get("id", "cross")))


func _card_has_image(card_data: Dictionary, image_id: String) -> bool:
	for raw_image in card_data.get("images", []):
		if str((raw_image as Dictionary).get("id", "")) == image_id:
			return true
	return false
