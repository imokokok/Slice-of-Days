extends Node

const MAIN_MENU := "res://scenes/main_menu.tscn"
const TOWN_DAY := "res://scenes/town_day.tscn"
const TAROT_TABLE := "res://scenes/tarot_table.tscn"
const CHAPTER_TRANSITION := "res://scenes/chapter_transition.tscn"
const MODULE_WORKBENCH := "res://scenes/module_workbench.tscn"
const ENDING := "res://scenes/ending.tscn"
const JOURNAL := "res://scenes/journal.tscn"


func go_to(path: String) -> void:
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		push_error("Scene does not exist: %s" % path)


func main_menu() -> void:
	go_to(MAIN_MENU)


func town_day() -> void:
	go_to(TOWN_DAY)


func tarot_table() -> void:
	go_to(TAROT_TABLE)


func chapter_transition() -> void:
	go_to(CHAPTER_TRANSITION)


func gameplay_module(module_id: String, source_event_id := "") -> void:
	if not GameplayModuleSystem.begin_session(module_id, source_event_id):
		push_warning("Unable to begin gameplay module: %s" % module_id)
		return
	var metadata: Dictionary = GameplayModuleSystem.modules.get(module_id, {})
	go_to(str(metadata.get("scene_path", MODULE_WORKBENCH)))


func ending() -> void:
	go_to(ENDING)


func journal() -> void:
	go_to(JOURNAL)
