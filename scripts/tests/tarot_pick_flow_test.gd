extends Node

const TarotTable = preload("res://scripts/ui/tarot_table.gd")

var failures: Array[String] = []


func _ready() -> void:
	var table := TarotTable.new()
	add_child(table)
	await get_tree().process_frame

	_check(table.choosing_cards, "a new round should begin with a face-down three-card deal")
	_check(table.world_overlay.z_index > 2, "the World modal should render above lifted tarot cards")
	_check(table.draw_pile.size() == 3, "each round should prepare exactly three cards")
	_check(table.current_draw.is_empty(), "cards should not be drawn before the player clicks them")
	_check(not table.question_edit.editable and table.ask_button.disabled, "questions should wait until the three cards are revealed")
	_check(table.draw_pile == table.case_data.get("opening_draw", []), "the first deal should use the authored onboarding draw")

	await table._shuffle_pile()
	_check(not table.choosing_cards, "the prepared cards should flip together")
	_check(table.current_draw.size() == 3, "exactly three cards should be revealed")
	_check(table.current_draw[0] != table.current_draw[1] and table.current_draw[1] != table.current_draw[2] and table.current_draw[0] != table.current_draw[2], "revealed cards should be unique")
	_check(table.question_edit.editable and table.ask_button.disabled, "writing may begin after the reveal, but Reading should wait for an image")
	_check(table.shuffle_button.disabled, "the deal should not change after the reveal")
	table._select_card(str(table.current_draw[0]))
	var first_images: Array = table.engine.card(str(table.current_draw[0])).get("images", [])
	var structure_image := str((first_images[1] as Dictionary).get("id", ""))
	table._select_image(structure_image)
	_check(not table.ask_button.disabled, "selecting a card image should unlock the Reading action")
	table.question_edit.text = "四组人数之间存在固定的数值结构吗？"
	table._ask_question()
	_check(table.round_locked and table.records.size() == 1, "one submitted Reading should lock the round and create one record")
	_check(table.confirmed_cards.has("emperor"), "a critical YES should leave the chosen card in the spread")
	_check((table.confirmed_cards["emperor"] as Dictionary).get("images", []).has(structure_image), "the chosen image should stay illuminated on a confirmed card")

	table._draw_round()
	table._reveal_cards(["emperor", "temperance", "justice"])
	table._select_card("emperor")
	table._select_image("square")
	table.question_edit.text = "四组人数之间存在固定的数值结构吗？"
	table._ask_question()
	_check(not table.round_locked and table.records.size() == 1, "repeating a resolved fact should not consume time or create a duplicate record")

	table._confirm_card("temperance", "cups", "恰好两组人数相等是开门规律的一部分。")
	table._refresh_cross_button()
	_check(not table._available_cross_pairs().is_empty(), "two confirmed compatible cards should unlock a cross reading")
	table._select_next_cross_pair()
	table.question_edit.text = "相等和大小关系必须同时成立吗？"
	table._ask_question()
	_check(table.round_locked and table.used_cross_pairs.size() == 1, "a submitted cross reading should consume the pair for this case")
	_check(table._available_cross_pairs().is_empty(), "a completed cross pair should not be reusable")
	table._request_case(1)
	_check(table.case_index == 0 and table.pending_case_switch_index == 1, "switching cases with progress should require confirmation")
	table._on_next_pressed()
	_check(table.case_index == 1 and table.records.is_empty(), "confirmed case switching should start a clean investigation")

	if failures.is_empty():
		print("TAROT PICK FLOW TEST PASSED")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
