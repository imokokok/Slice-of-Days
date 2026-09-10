extends Node

var failures: Array[String] = []


func _ready() -> void:
	ScheduleSystem.load_schedule_data("res://data/npcs/demo_npcs.json")
	TravelSystem.load_route_data("res://data/world/travel_routes.json")
	EventSystem.load_event_data("res://data/story/events.json")
	_test_calendar_and_role_isolation()
	_test_schedule_and_route()
	_test_event_and_relationship()
	_test_gameplay_module_state()
	_test_chapter_progression()
	_test_save_roundtrip()
	if failures.is_empty():
		print("SMOKE TEST PASS: dual-role state, calendar, routes, events, relationships, gameplay modules, chapters and save/load")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_calendar_and_role_isolation() -> void:
	ChapterSystem.start_new_game("A")
	_check(GameState.current_role == "A", "A should be the first active role")
	_check(GameState.current_day == 1, "A should start on day 1")
	_check(GameState.residency_confirmations == 0, "A should start without prototype confirmations")
	_check(GameState.current_minute == 540, "Day 1 should begin at 09:00")
	_check(GameState.spend_money(20), "A should be able to spend money")
	GameState.add_fact("A-only fact")
	_check(GameState.switch_to_role("B"), "Switching to B should succeed")
	_check(GameState.money == 45, "B should keep an independent budget")
	_check(not GameState.known_facts.has("A-only fact"), "B should not inherit A's private facts")
	GameState.add_fact("B-only fact")
	_check(GameState.switch_to_role("A"), "Switching back to A should succeed")
	_check(GameState.money == 160, "A's budget should survive the role switch")
	_check(GameState.known_facts.has("A-only fact"), "A's facts should survive the role switch")
	_check(not GameState.known_facts.has("B-only fact"), "A should not inherit B's private facts")


func _test_schedule_and_route() -> void:
	ChapterSystem.start_new_game("A")
	GameState.current_minute = 1080
	GameState.current_location = "park"
	GameState.commit_active_role_state()
	_check(
		ScheduleSystem.residents_at("park", 1, 1080).has("xia_touming"),
		"Xia should be present in the park on day 1 at 18:00"
	)
	GameState.current_location = "residence"
	GameState.current_minute = 540
	GameState.commit_active_role_state()
	var result: Dictionary = TravelSystem.travel("park", "walk")
	_check(bool(result.get("ok", false)), "The route graph should connect residence to park")
	_check(GameState.current_location == "park", "Travel should update the active role location")


func _test_event_and_relationship() -> void:
	ChapterSystem.start_new_game("B")
	GameState.current_day = 2
	GameState.current_minute = 660
	GameState.current_location = "cafeteria"
	GameState.commit_active_role_state()
	var result := EventSystem.trigger("b_d2_careful_questions")
	_check(
		bool(result.get("ok", false)),
		"The day 2 relationship event should trigger from data: %s" % str(result.get("message", ""))
	)
	_check(GameState.confirmed_residents.has("zhou_xiaoliu"), "The event should grant Zhou's confirmation")
	_check(
		RelationshipSystem.confirmation_status("zhou_xiaoliu") == "granted",
		"The relationship record should store confirmation status"
	)
	_check(
		RelationshipSystem.has_flag("zhou_xiaoliu", "把问题问得很清楚"),
		"The event should add a relationship memory flag"
	)


func _test_chapter_progression() -> void:
	ChapterSystem.start_new_game("A")
	var first := ChapterSystem.current_chapter()
	_check(str(first.get("role", "")) == "A", "The first chapter should use the selected starting role")
	var next := ChapterSystem.advance_chapter()
	_check(bool(next.get("ok", false)), "Advancing the first chapter should succeed")
	_check(GameState.current_role == "B" and GameState.current_day == 1, "The second chapter should switch to B on day 1")
	ChapterSystem.advance_chapter()
	_check(GameState.current_role == "A" and GameState.current_day == 2, "The third chapter should begin A's day 2")


func _test_gameplay_module_state() -> void:
	ChapterSystem.start_new_game("A")
	_check(GameplayModuleSystem.is_unlocked("tarot"), "Tarot should be initially unlocked")
	_check(GameplayModuleSystem.start("tarot"), "An unlocked gameplay module should start")
	_check(
		GameplayModuleSystem.complete("tarot", {"method": "test"}),
		"An unlocked gameplay module should store an outcome"
	)
	_check(
		bool(GameplayModuleSystem.state_for("tarot").get("completed", false)),
		"Gameplay completion should be stored in the active role state"
	)


func _test_save_roundtrip() -> void:
	ChapterSystem.start_new_game("A")
	GameState.add_fact("smoke-test-fact")
	GameState.switch_to_role("B")
	GameState.add_fact("smoke-test-b-fact")
	var test_path := "user://smoke_test_save.json"
	_check(SaveManager.save_game(test_path), "Save should succeed")
	GameState.begin_new_game("A")
	_check(SaveManager.load_game(test_path), "Load should succeed")
	_check(GameState.current_role == "B", "The active role should survive save/load")
	_check(GameState.known_facts.has("smoke-test-b-fact"), "B's facts should survive save/load")
	GameState.switch_to_role("A")
	_check(GameState.known_facts.has("smoke-test-fact"), "A's facts should survive save/load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
