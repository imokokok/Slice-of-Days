extends Node

var failures: Array[String] = []


func _ready() -> void:
	ScheduleSystem.load_schedule_data("res://data/npcs/demo_npcs.json")
	TravelSystem.load_route_data("res://data/world/travel_routes.json")
	EventSystem.load_event_data("res://data/story/events.json")
	GameplayModuleSystem.load_module_data("res://data/gameplay/modules.json")
	GameplayModuleSystem.load_prototype_data("res://data/gameplay/module_prototypes.json")
	_simulate_a_route()
	_simulate_b_route()
	if failures.is_empty():
		print("SEVEN DAY SIMULATION PASS: both A and B have a data-valid route to 12 confirmations")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _simulate_a_route() -> void:
	ChapterSystem.start_new_game("A")
	_context(1, 540, "print_shop")
	_event("a_d1_print_help")
	_context(1, 700, "cafe")
	_event("a_d1_mossner_coffee")
	_context(1, 900, "theatre")
	_event("a_d1_theatre_rehearsal")
	_context(1, 1080, "park")
	_module_event("a_d1_evening_photo", "photography", "photograph_people")

	_context(2, 660, "night_market")
	_module_event("a_d2_restaurant_shift", "cooking", "improvise")

	_context(3, 900, "park")
	_event("a_d3_social_chain")

	_context(4, 600, "cafe")
	_event("a_d4_confirmation_withdrawn")
	_context(4, 1140, "tarot_stall")
	_event("a_d4_listen_to_xia")

	_context(5, 780, "library")
	_event("a_d5_library_rescue")
	_context(5, 900, "night_market")
	_module_event("a_d5_translation", "translation", "hold_both_meanings")

	_context(6, 1080, "park")
	_choice_event("a_d6_last_full_block", "watch_stars")

	var audit := ChapterSystem.residency_audit("A")
	_check(bool(audit.get("passed", false)), "A route should reach 12 confirmations, got %d" % int(audit.get("confirmed", 0)))


func _simulate_b_route() -> void:
	ChapterSystem.start_new_game("B")
	_context(1, 660, "cafeteria")
	_event("b_d1_cafeteria_observe")
	_context(1, 1080, "library")
	_event("b_d1_library_wait")
	_context(1, 1200, "residence")
	_event("b_d1_notebook_anomaly")

	_context(2, 660, "cafeteria")
	_event("b_d2_careful_questions")
	_context(2, 1140, "tarot_stall")
	var tarot_event := EventSystem.trigger("b_d2_tarot_deduction")
	_check(bool(tarot_event.get("ok", false)), "B tarot entry event should trigger")
	_check(GameplayModuleSystem.begin_session("tarot", "b_d2_tarot_deduction"), "B tarot session should begin")
	_check(
		GameplayModuleSystem.complete_external(
			"tarot",
			{"method": "deduction"},
			{
				"encounters": ["xia_touming"],
				"relationship_flags": {"xia_touming": ["认真完成过关系推理"]},
				"confirmations": {"xia_touming": "granted"}
			}
		),
		"B tarot session should complete"
	)

	_context(3, 540, "residence")
	_event("b_d3_work_interruption")
	_context(3, 840, "night_market")
	_event("b_d3_help_market")
	_context(3, 840, "record_store")
	_module_event("b_d3_sound_session", "sound_sampling", "planned_route")

	_context(4, 840, "library")
	_event("b_d4_missed_window")
	_context(4, 1080, "theatre")
	_event("b_d4_salvage_rehearsal")

	_context(5, 840, "library")
	_module_event("b_d5_ghostwriting", "ghostwriting", "listen_then_cut")
	_context(5, 1080, "park")
	_module_event("b_d5_resume_chess", "chess", "finish_game")

	_context(6, 1080, "library")
	_event("b_d6_key_meeting")
	_context(6, 1170, "park")
	_choice_event("b_d6_boundary_choice", "decline_kindly")

	_context(7, 1080, "residence")
	_event("b_d7_last_note")

	var audit := ChapterSystem.residency_audit("B")
	_check(bool(audit.get("passed", false)), "B route should reach 12 confirmations, got %d" % int(audit.get("confirmed", 0)))


func _context(day: int, minute: int, location: String) -> void:
	GameState.current_day = day
	GameState.current_minute = minute
	GameState.current_location = location
	GameState.commit_active_role_state()


func _event(event_id: String) -> void:
	var result := EventSystem.trigger(event_id)
	_check(bool(result.get("ok", false)), "Event %s failed: %s" % [event_id, str(result.get("message", ""))])


func _choice_event(event_id: String, choice_id: String) -> void:
	var result := EventSystem.trigger(event_id, choice_id)
	_check(bool(result.get("ok", false)), "Choice event %s/%s failed: %s" % [event_id, choice_id, str(result.get("message", ""))])


func _module_event(event_id: String, expected_module_id: String, choice_id: String) -> void:
	var result := EventSystem.trigger(event_id)
	_check(bool(result.get("ok", false)), "Module entry event %s failed: %s" % [event_id, str(result.get("message", ""))])
	var module_id := str(result.get("launch_module", ""))
	_check(module_id == expected_module_id, "Event %s should launch %s, got %s" % [event_id, expected_module_id, module_id])
	if module_id.is_empty():
		return
	_check(GameplayModuleSystem.begin_session(module_id, event_id), "Module %s should begin" % module_id)
	var prototype := GameplayModuleSystem.prototype_for(module_id)
	var interaction: Dictionary = prototype.get("interaction", {})
	var selected_tokens: Array[String] = []
	var minimum := int(interaction.get("min_select", 0))
	for token in interaction.get("tokens", []):
		if selected_tokens.size() >= minimum:
			break
		selected_tokens.append(str(token.get("id", "")))
	var completion := GameplayModuleSystem.complete_choice(
		choice_id,
		{"mode": str(interaction.get("mode", "toggle")), "selected_tokens": selected_tokens}
	)
	_check(bool(completion.get("ok", false)), "Module %s choice %s failed: %s" % [module_id, choice_id, str(completion.get("message", ""))])


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
