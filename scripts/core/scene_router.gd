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
	wash.color = Color("18252a", 0.0)
	curtain.add_child(wash)
	add_child(curtain)
	var scene := get_tree().current_scene
	if scene != null and not SettingsSystem.reduced_motion():
		for child in scene.get_children():
			if child.get_script() == load("res://scripts/ui/walk_stage.gd"):
				child.pivot_offset = Vector2(child.player_x - child.camera_x, 580)
				create_tween().tween_property(child, "scale", Vector2(1.08, 1.08), 0.28)
	var fade := create_tween()
	fade.tween_property(wash, "color:a", 1.0, 0.3)
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


func gameplay_module(module_id: String, source_event_id := "") -> void:
	if transitioning: return
	if not GameplayModuleSystem.begin_session(module_id, source_event_id):
		push_warning("Unable to begin gameplay module: %s" % module_id)
		return
	var metadata: Dictionary = GameplayModuleSystem.modules.get(module_id, {})
	go_to(str(metadata.get("scene_path", MODULE_WORKBENCH)))


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
