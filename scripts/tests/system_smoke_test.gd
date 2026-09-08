extends Node

var failures: Array[String] = []


func _ready() -> void:
	ScheduleSystem.load_schedule_data("res://data/npcs/demo_npcs.json")
	_test_a_route()
	_test_b_route()
	_test_save_roundtrip()
	if failures.is_empty():
		print("SMOKE TEST PASS: A/B routes, schedules, travel and save/load")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_a_route() -> void:
	GameState.begin_vertical_slice("A")
	_check(GameState.use_free_time(240), "A should be able to wait continuously until 18:00")
	var result: Dictionary = TravelSystem.travel("park", "walk")
	_check(bool(result.get("ok", false)), "A should be able to walk to the park")
	_check(ScheduleSystem.residents_at("park", 1, GameState.current_minute).has("xia_touming"), "Xia should be at the park when A arrives")


func _test_b_route() -> void:
	GameState.begin_vertical_slice("B")
	_check(GameState.current_block_remaining() == 30, "B should begin with a 30 minute block")
	_check(GameState.advance_to_next_free_block(), "B should advance to the second block")
	_check(GameState.advance_to_next_free_block(), "B should advance to the third block")
	_check(GameState.advance_to_next_free_block(), "B should advance to the evening block")
	_check(GameState.current_minute == 1140, "B evening block should begin at 19:00")
	var result: Dictionary = TravelSystem.travel("park", "friend")
	_check(bool(result.get("ok", false)), "B should be able to use a friend's ride")
	_check(GameState.money == 45, "Friend ride should not cost B money")
	_check(ScheduleSystem.residents_at("park", 1, GameState.current_minute).has("xia_touming"), "Xia should be at the park when B arrives")


func _test_save_roundtrip() -> void:
	var test_path := "user://smoke_test_save.json"
	GameState.add_fact("smoke-test-fact")
	var saved_minute := GameState.current_minute
	_check(SaveManager.save_game(test_path), "Save should succeed")
	GameState.current_minute = 0
	GameState.known_facts.clear()
	_check(SaveManager.load_game(test_path), "Load should succeed")
	_check(GameState.current_minute == saved_minute, "Loaded time should match saved time")
	_check(GameState.known_facts.has("smoke-test-fact"), "Loaded facts should match saved facts")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
