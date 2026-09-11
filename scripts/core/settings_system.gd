extends Node

signal settings_changed

const SETTINGS_PATH := "user://solmere_settings.json"
const DEFAULTS := {
	"master_volume": 80,
	"fullscreen": false,
	"reduced_motion": false,
}

var values: Dictionary = DEFAULTS.duplicate(true)


func _ready() -> void:
	load_settings()
	apply_settings()


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
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		var volume := clampf(float(values.get("master_volume", 80)), 0.0, 100.0)
		AudioServer.set_bus_mute(bus_index, volume <= 0.0)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume / 100.0, 0.0001)))
	if not DisplayServer.get_name().contains("headless"):
		var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(values.get("fullscreen", false)) else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(target_mode)


func master_volume() -> int:
	return int(values.get("master_volume", 80))


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
