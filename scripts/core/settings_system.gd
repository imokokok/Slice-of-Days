extends Node

signal settings_changed
signal language_changed(locale: String)

const SETTINGS_PATH := "user://solmere_settings.json"
const SUPPORTED_LANGUAGES := ["zh_CN", "en"]
const DEFAULTS := {
	"language": "zh_CN",
	"master_volume": 80,
	"fullscreen": false,
	"reduced_motion": false,
	"voice_opacity": 0.86,
	"voice_size": 21,
}
const DEFAULT_INPUT_ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_fast": [KEY_SHIFT],
	"interact": [KEY_E],
	"ask_directly": [KEY_1],
	"dialogue_advance": [KEY_SPACE, KEY_ENTER],
	"open_journal": [KEY_J],
	"open_map": [KEY_TAB],
	"open_camera": [KEY_C],
	"open_recorder": [KEY_R],
	"open_album": [KEY_G],
	"open_fieldbook": [KEY_B],
	"open_dossier": [KEY_F],
	"open_home": [KEY_H],
	"toggle_typewriter": [KEY_T],
	"restart_module": [KEY_R],
}

var values: Dictionary = DEFAULTS.duplicate(true)


func _ready() -> void:
	_ensure_input_actions()
	load_settings()
	apply_settings()


func _ensure_input_actions() -> void:
	for action_name in DEFAULT_INPUT_ACTIONS:
		var action := StringName(action_name)
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode in DEFAULT_INPUT_ACTIONS[action_name]:
			var input := InputEventKey.new()
			input.physical_keycode = int(keycode)
			InputMap.action_add_event(action, input)


func load_settings(path := SETTINGS_PATH) -> bool:
	values = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	for key in DEFAULTS:
		if parsed.has(key):
			values[key] = parsed[key]
	return true


func save_settings(path := SETTINGS_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(values, "\t"))
	return true


func apply_settings() -> void:
	TranslationServer.set_locale(language())
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		var volume := clampf(float(values.get("master_volume", 80)), 0.0, 100.0)
		AudioServer.set_bus_mute(bus_index, volume <= 0.0)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume / 100.0, 0.0001)))
	if not DisplayServer.get_name().contains("headless"):
		DisplayServer.window_set_title(LocalizationSystem.text("Solmere · 七日档案 · 走动修复"))
		var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(values.get("fullscreen", false)) else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(target_mode)


func master_volume() -> int:
	return int(values.get("master_volume", 80))


func language() -> String:
	var configured := str(values.get("language", "zh_CN"))
	return configured if SUPPORTED_LANGUAGES.has(configured) else "zh_CN"


func reduced_motion() -> bool:
	return bool(values.get("reduced_motion", false))


func fullscreen() -> bool:
	return bool(values.get("fullscreen", false))


func set_master_volume(value: float) -> void:
	values["master_volume"] = clampi(int(round(value)), 0, 100)
	apply_settings()
	save_settings()
	settings_changed.emit()


func set_reduced_motion(enabled: bool) -> void:
	values["reduced_motion"] = enabled
	save_settings()
	settings_changed.emit()


func set_fullscreen(enabled: bool) -> void:
	values["fullscreen"] = enabled
	apply_settings()
	save_settings()
	settings_changed.emit()


func set_language(locale: String) -> void:
	if not SUPPORTED_LANGUAGES.has(locale) or locale == language():
		return
	values["language"] = locale
	TranslationServer.set_locale(locale)
	if not DisplayServer.get_name().contains("headless"):
		DisplayServer.window_set_title(LocalizationSystem.text("Solmere · 七日档案 · 走动修复"))
	save_settings()
	language_changed.emit(locale)
	settings_changed.emit()
