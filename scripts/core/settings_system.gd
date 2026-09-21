extends Node

signal settings_changed
signal language_changed(locale: String)
signal audio_settings_changed(master: int, music: int, sound_effects: int, muted: bool)

const SETTINGS_PATH := "user://solmere_settings.json"
const SUPPORTED_LANGUAGES := ["zh_CN", "en"]
const DEFAULTS := {
	"language": "zh_CN",
	"master_volume": 80,
	"music_volume": 100,
	"sound_effects_volume": 100,
	"audio_muted": false,
	"fullscreen": false,
	"reduced_motion": false,
	"voice_opacity": 0.86,
	"voice_size": 21,
}
const AUDIO_BUS_LAYOUT := [
	["Music", "Master"],
	["SoundEffects", "Master"],
	# Town World is the recorder's capture mix. Its children retain independent
	# listening controls while still reaching that capture bus.
	["TownWorld", "Master"],
	["TownWorldMusic", "TownWorld"],
	["TownWorldSoundEffects", "TownWorld"],
]
const DEFAULT_INPUT_ACTIONS := {
	"nebula_left": [KEY_A,KEY_LEFT],
	"nebula_right": [KEY_D,KEY_RIGHT],
	"nebula_up": [KEY_W,KEY_UP],
	"nebula_down": [KEY_S,KEY_DOWN],
	"nebula_near": [KEY_Q],
	"nebula_far": [KEY_E],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_fast": [KEY_SHIFT],
	"talk": [KEY_W],
	"interact": [KEY_E],
	"move_forward": [KEY_W,KEY_UP],
	"move_backward": [KEY_S,KEY_DOWN],
	"ask_directly": [KEY_1],
	"dialogue_advance": [KEY_SPACE, KEY_ENTER],
	"open_journal": [KEY_J],
	"open_notebook": [KEY_J],
	"open_archive": [KEY_F],
	"open_bag": [KEY_B,KEY_I],
	"open_plan": [KEY_T],
	"camera_shutter": [KEY_SPACE],
	"record_mark": [KEY_SPACE],
	"portfolio_delete": [KEY_DELETE],
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
	_ensure_audio_buses()
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

	for action in {"open_notebook":JOY_BUTTON_BACK,"open_archive":JOY_BUTTON_Y,"interact":JOY_BUTTON_A,"talk":JOY_BUTTON_X,"open_camera":JOY_BUTTON_LEFT_SHOULDER,"open_recorder":JOY_BUTTON_RIGHT_SHOULDER,"camera_shutter":JOY_BUTTON_A,"record_mark":JOY_BUTTON_X}:
		var pad := InputEventJoypadButton.new(); pad.button_index={"open_notebook":JOY_BUTTON_BACK,"open_archive":JOY_BUTTON_Y,"interact":JOY_BUTTON_A,"talk":JOY_BUTTON_X,"open_camera":JOY_BUTTON_LEFT_SHOULDER,"open_recorder":JOY_BUTTON_RIGHT_SHOULDER,"camera_shutter":JOY_BUTTON_A,"record_mark":JOY_BUTTON_X}[action]
		if not InputMap.action_has_event(action,pad): InputMap.action_add_event(action,pad)

	for binding in [["nebula_left",JOY_AXIS_RIGHT_X,-1.0],["nebula_right",JOY_AXIS_RIGHT_X,1.0],["nebula_up",JOY_AXIS_RIGHT_Y,-1.0],["nebula_down",JOY_AXIS_RIGHT_Y,1.0],["nebula_near",JOY_AXIS_TRIGGER_LEFT,1.0],["nebula_far",JOY_AXIS_TRIGGER_RIGHT,1.0]]:
		var motion := InputEventJoypadMotion.new()
		motion.axis=int(binding[1]); motion.axis_value=float(binding[2])
		if not InputMap.action_has_event(binding[0],motion): InputMap.action_add_event(binding[0],motion)


func _ensure_audio_buses() -> void:
	for route in AUDIO_BUS_LAYOUT:
		var bus_name := str(route[0])
		var send_name := str(route[1])
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			AudioServer.add_bus()
			bus_index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus_index, bus_name)
		# These buses are owned by SettingsSystem, so repairing their send target
		# is safe when an older runtime-created layout is still in memory.
		AudioServer.set_bus_send(bus_index, send_name)


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
	apply_audio_settings()
	if not DisplayServer.get_name().contains("headless"):
		DisplayServer.window_set_title(LocalizationSystem.text("Solmere"))
		var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(values.get("fullscreen", false)) else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(target_mode)


func apply_audio_settings() -> void:
	_ensure_audio_buses()
	_apply_bus_volume("Master", master_volume(), is_audio_muted())
	_apply_bus_volume("Music", music_volume())
	_apply_bus_volume("TownWorldMusic", music_volume())
	_apply_bus_volume("SoundEffects", sound_effects_volume())
	_apply_bus_volume("TownWorldSoundEffects", sound_effects_volume())


func _apply_bus_volume(bus_name: String, volume: int, force_mute := false) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var normalized := clampf(float(volume) / 100.0, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(normalized, 0.0001)))
	AudioServer.set_bus_mute(bus_index, force_mute or volume <= 0)


func master_volume() -> int:
	return clampi(int(values.get("master_volume", 80)), 0, 100)


func music_volume() -> int:
	return clampi(int(values.get("music_volume", 100)), 0, 100)


func sound_effects_volume() -> int:
	return clampi(int(values.get("sound_effects_volume", 100)), 0, 100)


func is_audio_muted() -> bool:
	return bool(values.get("audio_muted", false)) or master_volume() <= 0


func language() -> String:
	var configured := str(values.get("language", "zh_CN"))
	return configured if SUPPORTED_LANGUAGES.has(configured) else "zh_CN"


func reduced_motion() -> bool:
	return bool(values.get("reduced_motion", false))


func fullscreen() -> bool:
	return bool(values.get("fullscreen", false))


func set_master_volume(value: float) -> void:
	values["master_volume"] = clampi(int(round(value)), 0, 100)
	# Moving the master slider is an explicit request to hear the new level.
	values["audio_muted"] = master_volume() <= 0
	_commit_audio_settings()


func set_music_volume(value: float) -> void:
	values["music_volume"] = clampi(int(round(value)), 0, 100)
	_commit_audio_settings()


func set_sound_effects_volume(value: float) -> void:
	values["sound_effects_volume"] = clampi(int(round(value)), 0, 100)
	_commit_audio_settings()


func set_audio_muted(muted: bool) -> void:
	if not muted and master_volume() <= 0:
		values["master_volume"] = int(DEFAULTS.master_volume)
	values["audio_muted"] = muted
	_commit_audio_settings()


func _commit_audio_settings() -> void:
	apply_audio_settings()
	save_settings()
	audio_settings_changed.emit(master_volume(), music_volume(), sound_effects_volume(), is_audio_muted())
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
		DisplayServer.window_set_title(LocalizationSystem.text("Solmere"))
	save_settings()
	language_changed.emit(locale)
	settings_changed.emit()

func binding_text(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode if event.physical_keycode!=0 else event.keycode)
	return InputMap.action_get_events(action)[0].as_text() if not InputMap.action_get_events(action).is_empty() else "未绑定"
