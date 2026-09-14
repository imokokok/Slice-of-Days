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


func go_to(path: String) -> void:
	if transitioning: return
	if not ResourceLoader.exists(path):
		push_error("Scene does not exist: %s" % path)
		return
	transitioning = true
	var curtain := CanvasLayer.new()
	curtain.layer = 100
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color("172f43", 0.0) if GameState.current_minute >= 1080 else Color("f0e0b7",0.0)
	curtain.add_child(wash)
	add_child(curtain)
	var fade := create_tween()
	fade.tween_property(wash, "color:a", 0.95, 0.3)
	await fade.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	var reveal := create_tween()
	reveal.tween_property(wash, "color:a", 0.0, 0.3)
	await reveal.finished
	curtain.queue_free()
	transitioning = false


func main_menu() -> void:
	active_space_id = ""
	go_to(MAIN_MENU)


func town_day() -> void:
	if bool(GameState.shared_state.get("sleep_pending", false)):
		chapter_transition()
		return
	active_space_id = ""
	go_to(TOWN_DAY)


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
	go_to(JOURNAL)

func town_map(destination := "") -> void:
	if transitioning: return
	GameState.shared_state["map_destination"] = destination
	go_to("res://scenes/town_map.tscn")
func travel_to(destination: String, method: String) -> Dictionary:
	if transitioning: return {"ok":false,"message":"还在路上。"}
	var rollback_snapshot := GameState.to_save_data().duplicate(true)
	var result := TravelSystem.travel(destination,method)
	if not bool(result.get("ok",false)): return result
	active_space_id = ""
	GameState.shared_state["map_arrival"] = destination
	if not SaveManager.save_or_report("出行后保存失败"):
		GameState.load_save_data(rollback_snapshot)
		return {"ok": false, "message": "存档写入失败，本次出行已撤销。"}
	town_day()
	return result
