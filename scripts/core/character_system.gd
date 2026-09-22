extends Node

const CHARACTER_PATH := "res://data/story/characters.json"

var profiles: Dictionary = {}
var shared_direction: Dictionary = {}


func _ready() -> void:
	load_character_data(CHARACTER_PATH)


func load_character_data(path: String) -> bool:
	profiles.clear()
	shared_direction.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load character data: %s" % path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid character data: %s" % path)
		return false
	for row in parsed.get("characters", []):
		var role := str(row.get("role", ""))
		if not role.is_empty():
			profiles[role] = row.duplicate(true)
	shared_direction = parsed.get("shared_direction", {}).duplicate(true)
	return not profiles.is_empty()


func profile(role := "") -> Dictionary:
	var target := role if not role.is_empty() else GameState.current_role
	return (profiles.get(target, {}) as Dictionary).duplicate(true)


func job_title(role := "") -> String:
	var row := profile(role)
	return str(row.get("job_title_zh", row.get("job_title", "")))


func portrait_path(role := "") -> String:
	return str(profile(role).get("portrait_path", ""))

func switch_unlocked() -> bool:
	return GameState.current_day==5 and bool(ChapterSystem.story().reveal_completed) and bool(GameState.shared_state.get("character_switch_enabled",false))
func can_switch() -> bool:
	if not switch_unlocked() or SceneRouter.transitioning or not SceneRouter.active_space_id.is_empty(): return false
	if not GameplayModuleSystem.pending_module_id().is_empty() or MetaExperience.modal_open(): return false
	if not get_tree().get_nodes_in_group("world_tool").is_empty(): return false
	var scene := get_tree().current_scene
	if scene==null or scene.scene_file_path!=SceneRouter.TOWN_DAY: return false
	var shell := scene.get_node_or_null("GameplayShell")
	return shell!=null and not shell._blocked() and not is_instance_valid(shell.tool) and not is_instance_valid(shell.overlay)
func switch_character() -> bool:
	if not can_switch(): return false
	var scene := get_tree().current_scene
	var previous := GameState.current_role
	var target := "B" if previous=="A" else "A"
	var minute := GameState.current_minute
	var remainder := GameState.clock_remainder
	var location := GameState.current_location
	var x: float=scene.street.player_x
	var snapshot := GameState.to_save_data()
	scene._remember_position()
	GameState.switch_to_role(target,5,false)
	GameState.current_minute=minute
	GameState.clock_remainder=remainder
	GameState.current_location=location
	GameState.shared_state.get_or_add("street_positions",{})["%s_5_%s"%[target,scene.segment_id]]=x
	GameState.commit_active_role_state()
	if not SaveManager.save_or_report("切换视角未能保存"):
		GameState.load_save_data(snapshot)
		return false
	scene._refresh()
	GameState.state_changed.emit()
	return true
