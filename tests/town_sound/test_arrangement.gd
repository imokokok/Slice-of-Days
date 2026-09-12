extends SceneTree
const Model = preload("res://scripts/town_sound/studio/Arrangement.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.get_node("GameState").current_location = "record_store"
	var model := Model.new()
	var pcm := PackedFloat32Array()
	pcm.resize(22050)
	pcm.fill(0.25)
	model.cache["test"] = {"pcm": pcm, "rate": 22050}
	model.add_sample({"id": "test", "name": "test", "duration": 1.0}, 0, 0)
	model.clips[0].loop = true
	model.clips[0].length = 3.0
	var original := model.mix().data
	check(model.split(0, 1.25), "Loop split failed")
	check(model.mix().data == original, "Split changed loop audio")
	model.muted[0] = true
	check(model.mix().data.decode_s16(1000) == 0, "Muted track still audible")
	model.muted[0] = false
	model.clips[0].fade_in = 1.0
	var faded := model.mix().data
	check(faded.decode_s16(0) == 0 and faded.decode_s16(22050) > 0, "Fade failed")
	model.duplicate_clip(0)
	check(model.clips.size() == 3, "Duplicate failed")
	var edit := Model.new()
	edit.cache["test"] = {"pcm": pcm, "rate": 22050}
	edit.add_sample({"id": "test", "name": "test", "duration": 1.0}, 0, 0)
	edit.clips[0].loop = true
	edit.clips[0].length = 5
	edit.remove_range(1.25, 2.75, 0)
	check(edit.clips.size() == 2, "Middle selection did not split into two clips")
	check(is_equal_approx(edit.clips[0].length, 1.25) and is_equal_approx(edit.clips[1].start, 2.75), "Wrong selection boundaries")
	var cut := edit.mix().data
	check(cut.decode_s16(2 * 22050 * 2) == 0, "Deleted region still audible")
	check(cut.decode_s16(3 * 22050 * 2) > 0, "Right segment was destroyed")
	edit.keep_range(3, 4, 0)
	check(edit.clips.size() == 1 and is_equal_approx(edit.clips[0].length, 1.0), "Keep selection failed")
	var timeline := SoundTimeline.new()
	timeline.arrangement = edit
	root.add_child(timeline)
	timeline.size = Vector2(1800, 310)
	timeline.selection_mode = true
	var selection: Array = []
	timeline.region_selected.connect(func(begin: float, end: float, track: int) -> void: selection.assign([begin, end, track]))
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(37.5, 55)
	timeline._gui_input(down)
	var move := InputEventMouseMotion.new()
	move.position = Vector2(82.5, 55)
	timeline._gui_input(move)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(82.5, 55)
	timeline._gui_input(up)
	check(selection.size() == 3 and is_equal_approx(selection[0], 1.25) and is_equal_approx(selection[1], 2.75), "Mouse range gesture did not select intended audio")
	# Loop left-trim must shift phase without shortening the repeating source.
	timeline.selection_mode = false
	edit.clips.clear()
	edit.add_sample({"id": "test", "name": "test", "duration": 1.0}, 0, 0)
	edit.clips[0].loop = true
	edit.clips[0].length = 3.0
	down.position = Vector2(1, 55)
	timeline._gui_input(down)
	move.position = Vector2(16, 55)
	timeline._gui_input(move)
	timeline._gui_input(up)
	check(is_equal_approx(edit.clips[0].source_end - edit.clips[0].source_start, 1.0), "Left trim changed loop period")
	check(is_equal_approx(edit.clips[0].get("phase", 0), 0.5), "Left trim lost loop phase")
	# A cleared selection must not cut a previously selected, invisible range.
	check(selection[0] == -1, "Move tool retained stale selection")
	var before_invalid := edit.clips.duplicate(true)
	edit.remove_range(2, 1, 0)
	check(edit.clips == before_invalid, "Reversed range damaged clips")
	timeline.free()
	var studio = load("res://scripts/town_sound/studio/StudioScreen.gd").new()
	root.add_child(studio)
	await process_frame
	studio.model.clips.clear()
	studio.model.add_sample({"id": "test", "name": "test", "duration": 1.0}, 0, 0)
	studio.selected = 0
	studio.hide()
	var delete_key := InputEventKey.new()
	delete_key.keycode = KEY_DELETE
	delete_key.pressed = true
	studio._unhandled_key_input(delete_key)
	check(studio.model.clips.size() == 1, "Hidden Studio handled destructive keyboard input")
	studio.free()
	print("ARRANGEMENT_TESTS: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
