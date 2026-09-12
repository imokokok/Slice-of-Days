extends SceneTree
var failures := 0
var recorded: AudioStreamWAV
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func peak(wav: AudioStreamWAV) -> float:
	var result := 0.0
	for i in wav.data.size() / 2: result = maxf(result, absf(float(wav.data.decode_s16(i * 2))) / 32768)
	return result
func run() -> void:
	var world := root.get_node("WorldSound")
	world.set_location("park")
	world.set_active(true)
	check(AudioServer.get_driver_name() != "Dummy", "This integration test requires a real audio driver")
	if failures: quit(failures); return
	var recorder := FieldRecorder.new()
	root.add_child(recorder)
	recorder.completed.connect(func(wav: AudioStreamWAV, _warning: String) -> void: recorded = wav)
	var bus := AudioServer.get_bus_index("TownWorld")
	var effects := AudioServer.get_bus_effect_count(bus)
	check(recorder.start("intentionally missing microphone", "game"), "Game recording incorrectly requires microphone")
	check(not recorder.microphone.playing, "Game recording opened the microphone")
	await create_timer(0.8).timeout
	world.play_detail()
	await create_timer(0.6).timeout
	recorder.stop()
	check(recorded != null and peak(recorded) > 0.005, "World audio did not reach saved PCM")
	check(AudioServer.get_bus_effect_count(bus) == effects, "Capture effect leaked after stop")
	var store := SampleStore.new("user://tests/world_capture_" + Crypto.new().generate_random_bytes(6).hex_encode())
	var metadata := store.save_sample(recorded, "游戏声景回归测试")
	check(not metadata.is_empty(), "Captured world sound failed to save")
	check(store.load_audio(metadata).data == recorded.data, "World capture changed on local reload")
	# World source is stopped: a loud Master-bus preview must never enter capture.
	world.set_active(false)
	var preview := AudioStreamPlayer.new()
	preview.stream = world.make_detail("cafe")
	root.add_child(preview)
	check(recorder.start("", "game"), "Repeated recording failed")
	await create_timer(0.2).timeout
	preview.play()
	await create_timer(0.5).timeout
	recorder.stop()
	check(recorded != null and peak(recorded) < 0.0001, "Preview contaminated game recording")
	preview.stop()
	preview.free()
	world.set_active(true)
	check(recorder.start("", "game"), "Third recording failed")
	await create_timer(0.3).timeout
	recorder.free()
	check(AudioServer.get_bus_effect_count(bus) == effects, "Capture effect leaked on exit while recording")
	check(AudioServer.get_bus_index("TownSoundMicrophone") == -1, "Microphone bus leaked")
	world.set_active(false)
	print("WORLD_CAPTURE_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
