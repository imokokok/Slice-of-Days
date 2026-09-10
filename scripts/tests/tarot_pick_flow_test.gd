extends Node

const TarotTable = preload("res://scripts/ui/tarot_table.gd")

var failures: Array[String] = []


func _ready() -> void:
	var table := TarotTable.new()
	add_child(table)
	await get_tree().process_frame

	_check(table.choosing_cards, "a new round should begin with face-down card selection")
	_check(table.draw_pile.size() >= 6, "the case deck should be presented as a pile")
	_check(table.current_draw.is_empty(), "cards should not be drawn before the player clicks them")
	_check(not table.question_edit.editable and table.ask_button.disabled, "questions should wait until three cards are picked")

	var order_before := table.draw_pile.duplicate()
	table._shuffle_pile()
	_check(table.picked_pile_indices.is_empty(), "shuffling should clear partial picks")
	_check(table.draw_pile.size() == order_before.size(), "shuffling should retain the complete case deck")

	table._pick_pile_card(0)
	table._pick_pile_card(2)
	_check(table.choosing_cards and table.picked_pile_indices.size() == 2, "the pile should remain face down until three cards are chosen")
	table._pick_pile_card(4)
	_check(not table.choosing_cards, "the selected cards should flip after the third pick")
	_check(table.current_draw.size() == 3, "exactly three player-picked cards should be revealed")
	_check(table.current_draw[0] != table.current_draw[1] and table.current_draw[1] != table.current_draw[2] and table.current_draw[0] != table.current_draw[2], "player-picked cards should be unique")
	_check(table.question_edit.editable and not table.ask_button.disabled, "the Reading controls should unlock after the reveal")
	_check(table.shuffle_button.disabled, "the pile should not reshuffle after the reveal")

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
