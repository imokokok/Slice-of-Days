extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var model := Arrangement.new()
	model.project_path = "user://tests/project_" + Crypto.new().generate_random_bytes(6).hex_encode() + "/current.json"
	model.add_sample({"id": "test", "name": "test", "duration": 2.0}, 0, 0)
	check(model.save_project(), "Valid project failed to save")
	check(model.load_project(), "Valid project failed to reload")
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(model.project_path))
	var original := model.clips.duplicate(true)
	var cases: Array[Dictionary] = []
	for field in ["muted", "gains"]:
		var wrong := valid.duplicate(true)
		wrong[field] = 17
		cases.append(wrong)
	for field in ["start", "track", "source_start", "speed"]:
		var wrong := valid.duplicate(true)
		wrong.clips[0][field] = "bad"
		cases.append(wrong)
	var wrong_source := valid.duplicate(true)
	wrong_source.clips[0].source_end = -1
	cases.append(wrong_source)
	for wrong in cases:
		var file := FileAccess.open(model.project_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(wrong))
		file.close()
		check(not model.load_project(), "Invalid project accepted")
		check(model.clips == original, "Invalid load destroyed current arrangement")
	print("PROJECT_VALIDATION_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
