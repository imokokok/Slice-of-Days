extends Node

const EndingEchoResolverScript := preload("res://scripts/core/ending_echo_resolver.gd")

var failures: Array[String] = []


func _ready() -> void:
	ScheduleSystem.load_schedule_data("res://data/npcs/demo_npcs.json")
	TravelSystem.load_route_data("res://data/world/travel_routes.json")
	EventSystem.load_event_data("res://data/story/events.json")
	_test_calendar_and_role_isolation()
	_test_schedule_and_route()
	_test_core_resident_profiles()
	_test_event_and_relationship()
	_test_draft_confirmation_request()
	_test_appointment_lifecycle()
	_test_choice_history()
	_test_gameplay_module_state()
	_test_ending_echo_resolver()
	_test_ui_scenes_load()
	_test_chapter_progression()
	_test_save_roundtrip()
	if failures.is_empty():
		print("SMOKE TEST PASS: dual-role state, calendar, routes, core resident profiles, events, appointments, relationships, gameplay modules, chapters and save/load")
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
	_check(ScheduleSystem.residents.size() == 100, "The graybox roster should expand to 100 stable residents")
	_check(not ScheduleSystem.activity_at("town_resident_033", 1, 780).is_empty(), "A generated resident should expose a real schedule")
	var found_day_lead := false
	for lead in EventSystem.day_leads():
		if str(lead.get("id", "")) == "a_d1_print_help":
			found_day_lead = true
	_check(found_day_lead, "The journal lead query should expose an eligible day event without requiring the current location")
	GameState.current_minute = 1080
	GameState.current_location = "park"
	GameState.commit_active_role_state()
	_check(
		ScheduleSystem.residents_at("park", 1, 1080).has("xia_touming"),
		"Xia should be present in the park on day 1 at 18:00"
	)
	var known_activity := ScheduleSystem.activity_by_id("zhou_cafeteria")
	_check(str(known_activity.get("resident_name", "")) == "周晓六", "Known schedules should resolve to readable resident data")
	GameState.current_location = "residence"
	GameState.current_minute = 540
	GameState.commit_active_role_state()
	var result: Dictionary = TravelSystem.travel("park", "walk")
	_check(bool(result.get("ok", false)), "The route graph should connect residence to park")
	_check(GameState.current_location == "park", "Travel should update the active role location")


func _test_core_resident_profiles() -> void:
	_check(ResidentProfileSystem.profiles.size() == 12, "The core resident layer should load exactly 12 profiles")
	_check(ResidentProfileSystem.town_role("mossner") == "剧作人和临时邀约的发起者", "A core resident profile should expose its town role")
	var a_line := ResidentProfileSystem.ambient_line("jiu", "A", 0)
	var b_line := ResidentProfileSystem.ambient_line("jiu", "B", 0)
	_check(not a_line.is_empty() and not b_line.is_empty() and a_line != b_line, "A and B should receive distinct ambient lines from a core resident")


func _test_ui_scenes_load() -> void:
	var town_scene = load("res://scenes/town_day.tscn")
	var workbench_scene = load("res://scenes/module_workbench.tscn")
	var ending_scene = load("res://scenes/ending.tscn")
	_check(town_scene is PackedScene, "The town UI scene and its script should parse")
	_check(workbench_scene is PackedScene, "The module workbench scene and its script should parse")
	_check(ending_scene is PackedScene, "The ending UI scene and its dynamic echo resolver should parse")


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


func _test_draft_confirmation_request() -> void:
	ChapterSystem.start_new_game("A")
	RelationshipSystem.record_encounter("recordist", "smoke_first")
	var early := RelationshipSystem.request_confirmation("recordist")
	_check(str(early.get("status", "")) == "refused", "Asking a draft resident after one encounter should be refused")
	for index in 3:
		RelationshipSystem.record_encounter("recordist", "smoke_more_%d" % index)
	var repaired := RelationshipSystem.request_confirmation("recordist")
	_check(str(repaired.get("status", "")) == "granted", "A refused draft resident should allow repair after enough real encounters")
	_check(GameState.confirmed_residents.has("recordist"), "A repaired draft relationship should grant confirmation")


func _test_choice_history() -> void:
	ChapterSystem.start_new_game("A")
	GameState.current_day = 6
	GameState.current_minute = 1080
	GameState.current_location = "park"
	GameState.commit_active_role_state()
	var result := EventSystem.trigger("a_d6_last_full_block", "watch_stars")
	_check(bool(result.get("ok", false)), "A branching event should trigger")
	_check(GameState.has_choice("a_d6_last_full_block/watch_stars"), "A branching event should persist its selected choice")
	_check(GameState.choice_history.size() == 1, "A non-repeatable branching event should record one choice")


func _test_appointment_lifecycle() -> void:
	ChapterSystem.start_new_game("A")
	GameState.add_appointment({
		"id": "smoke_meeting",
		"day": 1,
		"start": 600,
		"end": 660,
		"location": "studio",
		"label": "Smoke meeting",
	})
	_check(GameState.appointment_status("smoke_meeting") == "scheduled", "A future appointment should begin scheduled")
	GameState.current_minute = 610
	GameState.refresh_appointments()
	_check(GameState.appointment_status("smoke_meeting") == "active", "An appointment should become active inside its window")
	GameState.mark_event("smoke_meeting")
	_check(GameState.appointment_status("smoke_meeting") == "completed", "Completing the matching event should complete its appointment")
	GameState.add_appointment({
		"id": "smoke_missed",
		"day": 1,
		"start": 620,
		"end": 630,
		"location": "port",
		"label": "Missed smoke meeting",
	})
	GameState.current_minute = 640
	GameState.refresh_appointments()
	_check(GameState.appointment_status("smoke_missed") == "missed", "Passing an appointment end should mark it missed")
	var missed_logged := false
	for entry in GameState.journal_entries:
		if str(entry.get("id", "")) == "missed_smoke_missed":
			missed_logged = true
	_check(missed_logged, "A missed appointment should leave one journal record")


func _test_chapter_progression() -> void:
	ChapterSystem.start_new_game("A")
	var first := ChapterSystem.current_chapter()
	_check(str(first.get("role", "")) == "A", "The first chapter should use the selected starting role")
	_check(not ChapterSystem.has_seen_opening(), "A new chapter opening should begin unseen")
	ChapterSystem.mark_opening_seen()
	_check(ChapterSystem.has_seen_opening(), "The current chapter opening should persist as seen")
	var next := ChapterSystem.advance_chapter()
	_check(bool(next.get("ok", false)), "Advancing the first chapter should succeed")
	_check(GameState.current_role == "B" and GameState.current_day == 1, "The second chapter should switch to B on day 1")
	_check(not ChapterSystem.has_seen_opening(), "The next role should have its own unseen opening")
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
	_check(GameplayModuleSystem.unlock("cooking"), "Cooking should unlock for its workbench test")
	_check(GameplayModuleSystem.begin_session("cooking", "smoke"), "Cooking session should begin")
	var cooking_result := GameplayModuleSystem.complete_choice(
		"improvise",
		{"mode": "ordered", "selected_tokens": ["lemon", "bread", "tomato"]}
	)
	_check(bool(cooking_result.get("ok", false)), "Cooking interaction should complete from its data")
	var outcomes: Array = GameplayModuleSystem.state_for("cooking").get("outcomes", [])
	_check(not outcomes.is_empty(), "Cooking should store an outcome")
	if not outcomes.is_empty():
		var interaction: Dictionary = outcomes[-1].get("interaction", {})
		_check(
			interaction.get("selected_tokens", []) == ["lemon", "bread", "tomato"],
			"The selected workbench tokens should survive in the gameplay outcome"
		)
	_check(GameplayModuleSystem.unlock("sound_sampling"), "Sound sampling should unlock for its constraint test")
	_check(GameplayModuleSystem.begin_session("sound_sampling", "smoke_permissions"), "Sound sampling session should begin")
	var blocked_delivery := GameplayModuleSystem.complete_choice(
		"planned_route",
		{"mode": "ordered", "selected_tokens": ["rain_awning", "bus_brake", "cafe_cups"]}
	)
	_check(not bool(blocked_delivery.get("ok", false)), "An unauthorized voice sample should block the delivery route")
	_check(GameplayModuleSystem.pending_module_id() == "sound_sampling", "A blocked delivery should keep the workbench session active")
	var allowed_delivery := GameplayModuleSystem.complete_choice(
		"planned_route",
		{"mode": "ordered", "selected_tokens": ["rain_awning", "bus_brake", "distant_flute"]}
	)
	_check(bool(allowed_delivery.get("ok", false)), "Authorized and traceable sound samples should allow delivery")
	_check(GameplayModuleSystem.unlock("ghostwriting"), "Ghostwriting should unlock for its echo test")
	_check(GameplayModuleSystem.begin_session("ghostwriting", "smoke_echo"), "Ghostwriting session should begin")
	var letter_result := GameplayModuleSystem.complete_choice(
		"listen_then_cut",
		{"mode": "ordered", "selected_tokens": ["still_here", "door_light", "no_reply"]}
	)
	_check(bool(letter_result.get("ok", false)), "Ghostwriting should complete for its echo test")
	var echo_presentation := EventSystem.resolved_presentation({
		"presentation": {
			"module_echo": {"module_id": "ghostwriting"},
			"beats": [{"text": "{selected_1} / {selected_2} / {selected_3}"}],
		}
	})
	var echo_beats: Array = echo_presentation.get("beats", [])
	_check(not echo_beats.is_empty(), "A module echo presentation should keep its staged beats")
	if not echo_beats.is_empty():
		_check(
			str(echo_beats[0].get("text", "")) == "我还在这里 / 门下面一直有光 / 不用马上回复",
			"A follow-up scene should resolve the exact selected workbench sentences"
		)


func _test_ending_echo_resolver() -> void:
	ChapterSystem.start_new_game("A")
	_store_echo_outcome("cooking", "improvise", "把零碎材料组合成新菜", ["一袋柠檬", "昨天的面包", "熟透的番茄"])
	GameState.record_choice("a_d4_confirmation_withdrawn", "ask_what_was_missed", "再告诉我一次")
	GameState.switch_to_role("B")
	_store_echo_outcome("sound_sampling", "planned_route", "按路线采样并完成短曲", ["雨落遮阳棚", "公交刹车", "公园里的声音"])
	_store_echo_outcome("ghostwriting", "listen_then_cut", "先听完整，再裁切排列", ["我还在这里", "门下面一直有光", "不用马上回复"])
	GameState.record_choice("b_d5_letter_revision_listen", "preserve_client_voice", "保留委托人的声音")
	GameState.record_choice("b_d4_missed_window", "record_the_absence", "记录没有出现")
	var file := FileAccess.open("res://data/story/endings.json", FileAccess.READ)
	var ending_data: Dictionary = JSON.parse_string(file.get_as_text())
	var resolver = EndingEchoResolverScript.new()
	var echoes: Array[Dictionary] = resolver.resolve(ending_data)
	_check(echoes.size() == 5, "The ending should select five distinct high-priority memory categories")
	var ending_text := resolver.display_text(ending_data)
	_check(ending_text.contains("一袋柠檬、昨天的面包、熟透的番茄"), "The ending should replay A's actual cooking materials")
	_check(ending_text.contains("雨落遮阳棚、公交刹车、公园里的声音"), "The ending should replay B's authorized sound sequence")
	_check(ending_text.contains("“我还在这里”——“门下面一直有光”——“不用马上回复”"), "The ending should replay B's exact letter sentence order")
	_check(ending_text.contains("未出现。不是未完成。"), "The ending should preserve the missed schedule as an absence")
	_check(ending_text.contains("后来被重新说了一遍"), "The ending should preserve the relationship repair")
	_check(not ending_text.contains("{selected_"), "Resolved ending copy should not expose data placeholders")


func _store_echo_outcome(module_id: String, choice_id: String, label: String, selected_labels: Array[String]) -> void:
	_check(GameplayModuleSystem.unlock(module_id), "Ending echo test should unlock %s" % module_id)
	_check(GameplayModuleSystem.complete(module_id, {
		"choice_id": choice_id,
		"label": label,
		"interaction": {"selected_labels": selected_labels},
	}), "Ending echo test should store %s" % module_id)


func _test_save_roundtrip() -> void:
	ChapterSystem.start_new_game("A")
	GameState.add_fact("smoke-test-fact")
	GameState.record_choice("smoke-event", "smoke-choice", "Smoke choice")
	GameState.switch_to_role("B")
	GameState.add_fact("smoke-test-b-fact")
	var test_path := "user://smoke_test_save.json"
	_check(SaveManager.path_for_slot(1) == SaveManager.SAVE_PATH, "Slot 1 should preserve the existing save path")
	_check(SaveManager.path_for_slot(3).ends_with("solmere_save_3.json"), "Additional save slots should use separate files")
	_check(SaveManager.save_game(test_path), "Save should succeed")
	GameState.begin_new_game("A")
	_check(SaveManager.load_game(test_path), "Load should succeed")
	_check(GameState.current_role == "B", "The active role should survive save/load")
	_check(GameState.known_facts.has("smoke-test-b-fact"), "B's facts should survive save/load")
	GameState.switch_to_role("A")
	_check(GameState.known_facts.has("smoke-test-fact"), "A's facts should survive save/load")
	_check(GameState.has_choice("smoke-event/smoke-choice"), "A's key choices should survive save/load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
