extends Node

const MAIN_MENU := "res://scenes/main_menu.tscn"
const TOWN_DAY := "res://scenes/town_day.tscn"
const TAROT_TABLE := "res://scenes/tarot_table.tscn"
const CHAPTER_TRANSITION := "res://scenes/chapter_transition.tscn"
const MODULE_WORKBENCH := "res://scenes/module_workbench.tscn"
const ENDING := "res://scenes/ending.tscn"
const JOURNAL := "res://scenes/journal.tscn"
const INTERACTIVE_SPACE := "res://scenes/interactive_space.tscn"
const EXTENSION_HOST := "res://scenes/extension_host.tscn"

var active_space_id := ""
var room_positions: Dictionary = {}
var transitioning := false
var pending_journey: Dictionary = {}


func go_to(path: String, fade_duration := .3) -> void:
	if transitioning: return
	if not ResourceLoader.exists(path):
		push_error("Scene does not exist: %s" % path)
		return
	transitioning = true
	var journey := pending_journey.duplicate(true)
	pending_journey.clear()
	if not journey.is_empty(): fade_duration=.5
	var curtain := CanvasLayer.new()
	curtain.layer = 100
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color("172f43", 0.0) if GameState.current_minute >= 1080 else Color("f0e0b7",0.0)
	curtain.add_child(wash)
	add_child(curtain)
	var fade := create_tween()
	fade.tween_property(wash, "color:a", 0.95, fade_duration)
	await fade.finished
	if not journey.is_empty():
		var card := preload("res://scripts/ui/components/travel_card.gd").new(); card.journey=journey; curtain.add_child(card)
		await get_tree().create_timer(1.8).timeout
		card.queue_free()
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	var reveal := create_tween()
	reveal.tween_property(wash, "color:a", 0.0, fade_duration)
	await reveal.finished
	if not journey.is_empty():
		var arrival := Label.new(); arrival.text=TravelSystem.location_name(str(journey.to))+"  ·  "+GameState.clock_text(); arrival.position=Vector2(400,695); arrival.size=Vector2(800,70); arrival.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; arrival.add_theme_font_size_override("font_size",29); arrival.add_theme_color_override("font_color",Color("fff9ec")); arrival.add_theme_color_override("font_outline_color",Color("1b3e57")); arrival.add_theme_constant_override("outline_size",2); curtain.add_child(arrival)
		await get_tree().create_timer(1).timeout
	curtain.queue_free()
	transitioning = false


func main_menu() -> void:
	active_space_id = ""
	go_to(MAIN_MENU)


func town_day(fade_duration := .3) -> void:
	if bool(GameState.shared_state.get("sleep_pending", false)):
		chapter_transition()
		return
	active_space_id = ""
	go_to(TOWN_DAY,fade_duration)


func enter_space(space_id: String) -> void:
	if transitioning: return
	active_space_id = space_id
	go_to(INTERACTIVE_SPACE)


func interactive_space() -> void:
	go_to(INTERACTIVE_SPACE)


func tarot_table() -> void:
	go_to(TAROT_TABLE)


func chapter_transition() -> void:
	go_to(CHAPTER_TRANSITION)


func gameplay_module(module_id: String, source_event_id := "", rollback_snapshot: Dictionary = {}) -> bool:
	if transitioning: return false
	var session_snapshot := rollback_snapshot.duplicate(true)
	if session_snapshot.is_empty():
		session_snapshot = GameState.to_save_data().duplicate(true)
	if not GameplayModuleSystem.begin_session(module_id, source_event_id, session_snapshot):
		push_warning("Unable to begin gameplay module: %s" % module_id)
		return false
	if not SaveManager.save_or_report("进入玩法时保存失败"):
		GameplayModuleSystem.cancel_session()
		return false
	var metadata: Dictionary = GameplayModuleSystem.modules.get(module_id, {})
	go_to(str(metadata.get("scene_path", MODULE_WORKBENCH)))
	return true


func return_from_gameplay() -> void:
	if not active_space_id.is_empty():
		interactive_space()
	else:
		town_day()


func leave_space() -> void:
	room_positions.erase(active_space_id)
	active_space_id = ""
	# Clean up navigation values written by development builds before interiors became transient.
	GameState.shared_state.erase("active_space_id")
	GameState.shared_state.erase("active_object_id")
	GameState.commit_active_role_state()
	town_day()


func ending() -> void:
	go_to(ENDING)


func journal() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_node("GameplayShell"):
		scene.get_node("GameplayShell").open_paper("notebook")
	else:
		var book = preload("res://scripts/residency/living_objects.gd").new()
		book.mode="notebook"
		get_tree().root.add_child(book)

func town_map(destination := "") -> void:
	if transitioning: return
	GameState.shared_state["map_destination"] = destination
	go_to("res://scenes/town_map.tscn")
func travel_to(destination: String, method: String) -> Dictionary:
	if transitioning: return {"ok":false,"message":"还在路上。"}
	var previous_space := active_space_id
	var rollback_snapshot := GameState.to_save_data().duplicate(true)
	var origin := GameState.current_location
	var start_minute := GameState.current_minute
	var option := TravelSystem.route(origin,destination,method,GameState.current_role,start_minute)
	var before_materials: Array=GameState.artifacts.get("collage_materials",[]).duplicate(true)
	var before_facts := KnowledgeSystem.facts()
	var result := TravelSystem.travel(destination,method)
	if not bool(result.get("ok",false)): return result
	active_space_id = ""
	GameState.shared_state["map_arrival"] = destination
	GameState.shared_state["route_arrival"] = TravelSystem.arrival_for(destination)
	if not SaveManager.save_or_report("出行后保存失败"):
		GameState.load_save_data(rollback_snapshot)
		active_space_id = previous_space
		return {"ok": false, "message": "存档写入失败，本次出行已撤销。"}
	var events: Array=[]
	for material in GameState.artifacts.get("collage_materials",[]):
		if not before_materials.any(func(before: Dictionary) -> bool: return before.get("id","")==material.get("id","")): events.append(str(material.get("title","路上的发现")))
	for fact in KnowledgeSystem.facts():
		if not before_facts.any(func(before: Dictionary) -> bool: return before.get("id","")==fact.get("id","")): events.append(str(fact.get("text","听来一条消息")))
	pending_journey={"from":origin,"to":destination,"start":start_minute,"finish":GameState.current_minute,"minutes":GameState.current_minute-start_minute,"method":str(option.get("label","")),"cost":int(option.get("cost",0)),"events":events}
	GameEvents.publish("TravelCompleted",pending_journey)
	town_day()
	return result
