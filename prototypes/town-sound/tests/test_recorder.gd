extends SceneTree
## Synthetic PCM is test input only; it is never substituted for microphone input.
const Store = preload("res://scripts/data/SampleStore.gd")
const Recorder = preload("res://scripts/audio/AudioRecorder.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test_path := "user://tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var store := Store.new(test_path)
	var wav := AudioStreamWAV.new()
	wav.mix_rate = 48000
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	var bytes := PackedByteArray()
	bytes.resize(9600)
	for i in 4800:
		bytes.encode_s16(i * 2, int(sin(float(i) * TAU * 440.0 / 48000.0) * 12000))
	wav.data = bytes
	var first: Dictionary
	for i in 20:
		var item := store.save_sample(wav, "测试声音 " + str(i))
		check(not item.is_empty(), "Consecutive save failed: " + str(i))
		if i == 0:
			first = item
	check(Store.new(test_path).list_samples().size() == 20, "Fresh store failed to restore 20 recordings")
	check(store.save_sample(wav, "over limit").is_empty(), "Limit not enforced")
	var restored := store.load_audio(first)
	check(restored != null, "WAV failed to load")
	if restored != null:
		check(absf(restored.get_length() - 0.1) < 0.001, "Incorrect saved duration")
		check(restored.data == bytes, "PCM altered during round trip")
	check(store.rename_sample(first.id, "钥匙 / 下午"), "Rename failed")
	check(not store.rename_sample(first.id, "   "), "Empty name accepted")
	var recovered_name := false
	for item in Store.new(test_path).list_samples():
		if item.id == first.id:
			recovered_name = item.name == "钥匙 / 下午"
	check(recovered_name, "Rename not persisted")
	check(store.delete_sample(first.id), "Delete failed")
	check(store.list_samples().size() == 19, "Deleted sample remained in list")
	check(FileAccess.file_exists(test_path.path_join("trash/" + first.id + ".wav")), "Trash did not preserve PCM")
	check(not store.delete_sample("../../escape"), "Untrusted id accepted")
	var corrupt := FileAccess.open(test_path.path_join("broken.json"), FileAccess.WRITE)
	corrupt.store_string("invalid JSON")
	corrupt.close()
	check(store.list_samples().size() == 19, "Bad metadata prevented library loading")
	var sample := store.list_samples()[0]
	DirAccess.remove_absolute(sample.file_path)
	check(store.load_audio(sample) == null, "Missing file did not return controlled failure")
	var unavailable := Store.new("res://project.godot/impossible")
	check(unavailable.save_sample(wav, "failure").is_empty(), "Invalid save target reported success")
	check(wav.data == bytes, "Failed save destroyed pending audio")
	var recorder := Recorder.new()
	root.add_child(recorder)
	var errors: Array[String] = []
	recorder.failed.connect(func(message: String) -> void: errors.append(message))
	check(not recorder.start("nonexistent device"), "Missing microphone accepted")
	check(errors.size() == 1, "Missing microphone did not notify UI")
	check(not recorder.capturing, "Failed start left recording active")
	recorder.free()
	print("TOWN_SOUND_TESTS: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
