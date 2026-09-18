extends Node

var failures: Array[String] = []


func _ready() -> void:
	var previous_values := SettingsSystem.values.duplicate(true)
	var test_path := "user://audio_settings_test.json"
	SettingsSystem.values["master_volume"] = 35
	SettingsSystem.values["music_volume"] = 25
	SettingsSystem.values["sound_effects_volume"] = 65
	SettingsSystem.values["audio_muted"] = false
	SettingsSystem.apply_audio_settings()

	for bus_name in ["Music", "SoundEffects", "TownWorld", "TownWorldMusic", "TownWorldSoundEffects"]:
		_check(AudioServer.get_bus_index(bus_name) >= 0, "%s audio bus should exist" % bus_name)
	var master_bus := AudioServer.get_bus_index("Master")
	var music_bus := AudioServer.get_bus_index("Music")
	var town_music_bus := AudioServer.get_bus_index("TownWorldMusic")
	var sound_effects_bus := AudioServer.get_bus_index("SoundEffects")
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(master_bus)), 0.35), "Master volume should apply to the Master bus")
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_bus)), 0.25), "Music volume should apply to the Music bus")
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(town_music_bus)), 0.25), "Music volume should also apply to captured town ambience")
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(sound_effects_bus)), 0.65), "Sound-effects volume should apply to its bus")
	_check(AudioServer.get_bus_send(town_music_bus) == "TownWorld", "Town ambience should still feed the recorder mix")

	SoundSettings.build_dialog()
	_check(SoundSettings.volume_sliders.size() == 3, "The sound dialog should expose all three volume controls")
	_check(int((SoundSettings.volume_sliders.master as HSlider).value) == 35, "The sound dialog should reflect the current master volume")
	_test_volume_settings_surfaces()

	SettingsSystem.values["audio_muted"] = true
	SettingsSystem.apply_audio_settings()
	_check(AudioServer.is_bus_mute(master_bus), "Mute should silence the Master bus without discarding slider values")
	_check(SettingsSystem.save_settings(test_path), "Audio settings should save to disk")
	SettingsSystem.values = SettingsSystem.DEFAULTS.duplicate(true)
	_check(SettingsSystem.load_settings(test_path), "Audio settings should load from disk")
	_check(SettingsSystem.master_volume() == 35 and SettingsSystem.music_volume() == 25 and SettingsSystem.sound_effects_volume() == 65, "Saved audio slider values should round-trip")
	_check(SettingsSystem.is_audio_muted(), "Saved mute state should round-trip")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	SettingsSystem.values = previous_values
	SettingsSystem.apply_audio_settings()
	if failures.is_empty():
		print("AUDIO SETTINGS TEST PASS: buses, levels, mute and persistence")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)


func _test_volume_settings_surfaces() -> void:
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	menu._build_modal_shell()
	menu._show_settings()
	_check(_count_sliders(menu.modal_panel) == 5, "The main settings menu should include three audio and two accessibility sliders")
	menu.free()

	var overlay = load("res://scripts/residency/paper_overlay.gd").new()
	overlay.body = Control.new()
	overlay.add_child(overlay.body)
	overlay.mode = "settings"
	overlay._home()
	_check(_count_sliders(overlay.body) == 3, "The in-game settings page should include all three audio sliders")
	overlay.free()


func _count_sliders(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		if child is HSlider:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
