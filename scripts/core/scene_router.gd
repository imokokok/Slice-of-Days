extends Node

const MAIN_MENU := "res://scenes/main_menu.tscn"
const TOWN_DAY := "res://scenes/town_day.tscn"
const TAROT_TABLE := "res://scenes/tarot_table.tscn"
const NPC_SURVEY_RESULTS := "res://scenes/npc_survey_results.tscn"


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


func npc_survey_results() -> void:
	go_to(NPC_SURVEY_RESULTS)
