extends SceneTree
const Settings = preload("res://scripts/town_sound/audio/SoundSettings.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(Settings.choose_device(PackedStringArray(["Default", "ToDesk Virtual Audio", "Realtek Microphone"]), "") == "Realtek Microphone")
	assert(Settings.choose_device(PackedStringArray(["Default", "ToDesk Virtual Audio", "Realtek Microphone"]), "ToDesk Virtual Audio") == "ToDesk Virtual Audio")
	assert(Settings.choose_device(PackedStringArray(["Default"]), "Missing") == "Default")
	var settings := root.get_node("SoundSettings")
	settings.play_test_tone()
	var data: PackedByteArray = settings.test_player.stream.data
	assert(data.size() == 88200)
	var peak := 0
	for i in data.size()/2: peak = maxi(peak, absi(data.decode_s16(i*2)))
	assert(peak > 6000 and peak < 6600)
	settings.test_player.stop()
	settings.test_player.stream = null
	await create_timer(0.15).timeout
	print("AUDIO_SETTINGS_TEST: PASS")
	quit()
