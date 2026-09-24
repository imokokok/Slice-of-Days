extends SceneTree
## Tape property, input geometry, undo and portable-storage regression.
## Godot --headless --path <project> --script res://tests/test_tape_editing.gd

const Canvas = preload("res://modules/restaurant/ui/poster_canvas.gd")
const Repository = preload("res://modules/restaurant/storage/recipe_repository.gd")
const PosterStore = preload("res://modules/restaurant/ui/poster_store.gd")
var canvas
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	Engine.max_fps = 120
	call_deferred("_run")

func _run() -> void:
	canvas = Canvas.new()
	root.add_child(canvas)
	canvas.position = Vector2(70, 90)
	canvas.size = Vector2(900, 600)
	await process_frame
	_test_validation()
	_test_defaults_and_selection()
	_test_live_property_limits()
	_test_property_undo()
	await _test_geometry_input()
	await _test_endpoint_drag()
	_test_portable_storage()
	canvas.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: tape editing, %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: tape editing, %d / %d checks" % [failures.size(), checks])
		quit(1)

func _legacy_tape() -> Dictionary:
	return {"kind": "tape", "position": [0.35, 0.48], "scale": 0.1}

func _paper(layers: Array) -> Dictionary:
	return {"version": 1, "caption": "", "strokes": [], "stickers": layers.duplicate(true)}

func _test_validation() -> void:
	_expect(Canvas.validate_sticker(_legacy_tape()), "legacy tape without added fields remains valid")
	for length_value in [0.5, 1.0, 6.0]:
		var tape := _legacy_tape()
		tape["length"] = length_value
		_expect(Canvas.validate_sticker(tape), "tape accepts inclusive length boundary %s" % length_value)
	for width_value in [0.4, 1.0, 3.0]:
		var tape := _legacy_tape()
		tape["width"] = width_value
		_expect(Canvas.validate_sticker(tape), "tape accepts inclusive width boundary %s" % width_value)
	for invalid_length in [0.499, 6.001, -1.0, NAN, INF, "2", true]:
		var tape := _legacy_tape()
		tape["length"] = invalid_length
		_expect(not Canvas.validate_sticker(tape), "tape rejects invalid length %s" % str(invalid_length))
	for invalid_width in [0.399, 3.001, -1.0, NAN, INF, "2", false]:
		var tape := _legacy_tape()
		tape["width"] = invalid_width
		_expect(not Canvas.validate_sticker(tape), "tape rejects invalid width %s" % str(invalid_width))
	for valid_color in ["baa977", "ad6f47bf"]:
		var tape := _legacy_tape()
		tape["color"] = valid_color
		_expect(Canvas.validate_sticker(tape), "tape accepts RGB or RGBA color %s" % valid_color)
	for invalid_color in ["not-a-color", "", 25, true, Color.RED]:
		var tape := _legacy_tape()
		tape["color"] = invalid_color
		_expect(not Canvas.validate_sticker(tape), "serialized tape rejects non-HTML color %s" % str(invalid_color))
	var extra := _legacy_tape()
	extra["path"] = "unexpected-field"
	_expect(not Canvas.validate_sticker(extra), "new tape fields do not allow unrelated serialized fields")
	for tape_field in ["length", "width"]:
		var star := {"kind": "star", "position": [0.5, 0.5], "scale": 0.1}
		star[tape_field] = 2.0
		_expect(Canvas.validate_sticker(star), "decoration %s is accepted for independently stretching stickers" % tape_field)

func _test_defaults_and_selection() -> void:
	canvas.import_data(_paper([_legacy_tape()]))
	canvas.selected_index = 0
	var settings: Dictionary = canvas.selected_tape_settings()
	_expect(is_equal_approx(float(settings.get("length", 0.0)), 1.0) and is_equal_approx(float(settings.get("width", 0.0)), 1.0), "legacy tape exposes default independent length and width")
	_expect(_color(settings.get("color")) == Color("baa977"), "legacy tape exposes its original warm tape color")
	_expect(canvas._base_extent(0).is_equal_approx(Vector2(80, 32)), "legacy tape uses the default 80 by 32 geometry")
	canvas.clear_canvas()
	canvas.add_sticker("tape")
	settings = canvas.selected_tape_settings()
	_expect(is_equal_approx(float(settings.get("length", 0.0)), 1.0) and is_equal_approx(float(settings.get("width", 0.0)), 1.0), "new tape starts with the same compatible shape defaults")

	var second := _legacy_tape()
	second.position = [0.8, 0.75]
	second.color = "72a68fff"
	second.length = 1.5
	second.width = 1.4
	var star := {"kind": "star", "position": [0.8, 0.2], "scale": 0.08}
	canvas.import_data(_paper([_legacy_tape(), second, star]))
	canvas.selected_index = 0
	var before_second: Dictionary = canvas.stickers[1].duplicate(true)
	var before_star: Dictionary = canvas.stickers[2].duplicate(true)
	canvas.set_tape_color(Color("ad6f47bf"))
	canvas.set_tape_length(4.0)
	canvas.set_tape_width(0.6)
	settings = canvas.selected_tape_settings()
	_expect(_color(settings.get("color")) == Color("ad6f47bf"), "selected tape color is independently editable including alpha")
	_expect(is_equal_approx(float(settings.get("length", 0)), 4.0) and is_equal_approx(float(settings.get("width", 0)), 0.6), "selected tape stores its independent length and width")
	_expect(canvas.stickers[1] == before_second and canvas.stickers[2] == before_star, "editing one tape never changes another tape or decoration")
	_expect(is_equal_approx(float(canvas.stickers[0].scale), 0.1) and not canvas.stickers[0].has("rotation"), "length and width edits leave uniform scale and rotation unchanged")
	_expect(canvas._base_extent(0).is_equal_approx(Vector2(320, 19.2)), "independent dimensions update geometry rather than just metadata")
	var selected_before: Dictionary = canvas.stickers[0].duplicate(true)
	canvas.selected_index = 2
	_expect(canvas.selected_tape_settings().is_empty(), "a non-tape selection exposes no tape properties")
	canvas.set_tape_length(5)
	canvas.set_tape_width(2)
	canvas.set_tape_color(Color.RED)
	_expect(canvas.stickers[0] == selected_before and canvas.stickers[2] != before_star and is_equal_approx(float(canvas.stickers[2].length), 5.0) and is_equal_approx(float(canvas.stickers[2].width), 2.0), "the same controls stretch and recolor a selected sticker without changing tape")
	canvas.selected_index = -1
	var no_selection_before: Dictionary = canvas.export_data()
	_expect(canvas.selected_tape_settings().is_empty(), "missing selection exposes no tape properties")
	canvas.set_tape_length(2)
	canvas.set_tape_width(2)
	canvas.set_tape_color(Color.BLUE)
	_expect(canvas.export_data() == no_selection_before, "tape controls are harmless with no selection")
	canvas.selected_index = 0

func _test_property_undo() -> void:
	var before: Dictionary = canvas.export_data()
	canvas.begin_property_edit()
	for value in [4.1, 4.2, 4.4, 4.7, 5.0, 5.4]:
		canvas.set_tape_length(value)
	canvas.end_property_edit()
	_expect(is_equal_approx(float(canvas.selected_tape_settings().get("length", 0)), 5.4), "one property drag applies its final length")
	canvas.undo()
	_expect(canvas.export_data() == before, "one undo restores the full state before a multi-value length drag")
	canvas.selected_index = 0
	before = canvas.export_data()
	canvas.set_tape_length(4.25)
	canvas.begin_property_edit()
	canvas.end_property_edit()
	canvas.undo()
	_expect(canvas.export_data() == before, "empty property interaction does not insert a redundant undo step")
	canvas.selected_index = 0
	before = canvas.export_data()
	canvas.begin_property_edit()
	for value in [0.7, 0.8, 0.9, 1.0, 1.3, 1.8]:
		canvas.set_tape_width(value)
	canvas.end_property_edit()
	_expect(is_equal_approx(float(canvas.selected_tape_settings().get("width", 0)), 1.8), "one property drag applies its final width")
	canvas.undo()
	_expect(canvas.export_data() == before, "one undo restores the full state before a multi-value width drag")
	canvas.selected_index = 0

func _test_live_property_limits() -> void:
	var original: Dictionary = canvas.export_data()
	canvas.set_tape_length(-8)
	canvas.set_tape_width(20)
	var settings: Dictionary = canvas.selected_tape_settings()
	_expect(is_equal_approx(float(settings.get("length", 0)), 0.5) and is_equal_approx(float(settings.get("width", 0)), 3.0), "live property edits clamp finite values to the low-length and high-width limits")
	canvas.set_tape_length(20)
	canvas.set_tape_width(-8)
	settings = canvas.selected_tape_settings()
	_expect(is_equal_approx(float(settings.get("length", 0)), 6.0) and is_equal_approx(float(settings.get("width", 0)), 0.4), "live property edits clamp finite values to the high-length and low-width limits")
	var clamped: Dictionary = canvas.export_data()
	canvas.set_tape_length(NAN)
	canvas.set_tape_length(INF)
	canvas.set_tape_width(NAN)
	canvas.set_tape_width(INF)
	_expect(canvas.export_data() == clamped, "non-finite live property values are ignored without corrupting tape")
	canvas.import_data(original)
	canvas.selected_index = 0
	canvas.editable = false
	canvas.set_tape_length(2)
	canvas.set_tape_width(2)
	canvas.set_tape_color(Color.BLUE)
	_expect(canvas.export_data() == original, "read-only paper rejects tape property mutations")
	canvas.editable = true

func _test_geometry_input() -> void:
	# A 4x-long / 0.6x-wide tape rotated 90 degrees must be selectable along
	# its visibly long axis, but not in the empty area beyond its narrow side.
	canvas.rotate_selected(PI / 2)
	await process_frame
	var center: Vector2 = canvas.global_position + Vector2(0.35, 0.48) * canvas.size
	var uniform_factor: float = 0.1 * minf(canvas.size.x, canvas.size.y) / 40.0
	var long_axis: Vector2 = center + Vector2(0, 120.0 * uniform_factor)
	await _click(long_axis)
	var selected: Dictionary = canvas.selected_tape_settings()
	_expect(is_equal_approx(float(selected.get("length", 0)), 4.0), "real GUI click can select the rotated tape near its elongated end")
	_expect(canvas._layer_nodes[canvas.selected_index].rotation > 1.5, "selected tape keeps its independent visual rotation")
	var outside_narrow_side: Vector2 = center + Vector2(18.0 * uniform_factor, 0)
	await _click(outside_narrow_side)
	_expect(canvas.selected_index == -1, "real GUI click outside the narrow rotated edge does not hit the old square bounds")
	await _click(center)
	_expect(not canvas.selected_tape_settings().is_empty(), "rotated tape remains selectable at its center")
	# Uniform scale continues to work without changing the independent dimensions.
	var before_scale: float = float(canvas.stickers[canvas.selected_index].scale)
	canvas.resize_selected(1.2)
	selected = canvas.selected_tape_settings()
	_expect(is_equal_approx(float(selected.get("length", 0)), 4.0) and is_equal_approx(float(selected.get("width", 0)), 0.6), "uniform resizing does not rewrite independent tape dimensions")
	_expect(is_equal_approx(float(canvas.stickers[canvas.selected_index].scale), before_scale * 1.2), "uniform scale remains independently adjustable")

func _test_endpoint_drag() -> void:
	var tape := _legacy_tape()
	tape.position = [0.45, 0.45]
	tape.color = "ad6f47bf"
	tape.length = 2.0
	tape.width = 1.4
	tape.rotation = PI / 4.0
	canvas.import_data(_paper([tape]))
	canvas.selected_index = 0
	await process_frame
	var before: Dictionary = canvas.export_data()
	var center: Vector2 = canvas.global_position + Vector2(0.45, 0.45) * canvas.size
	var factor: float = 0.1 * minf(canvas.size.x, canvas.size.y) / 40.0
	var axis := Vector2.RIGHT.rotated(PI / 4.0)
	var fixed_end: Vector2 = center - axis * 80.0 * factor
	var moving_end: Vector2 = center + axis * 80.0 * factor
	var destination: Vector2 = moving_end + axis * 90.0
	_mouse_button(moving_end, true)
	await process_frame
	_mouse_motion(destination, true)
	await process_frame
	var settings: Dictionary = canvas.selected_tape_settings()
	var new_center: Vector2 = canvas.global_position + Vector2(float(canvas.stickers[0].position[0]), float(canvas.stickers[0].position[1])) * canvas.size
	var half_length: float = 40.0 * float(settings.get("length", 0)) * factor
	_expect((new_center - axis * half_length).distance_to(fixed_end) < 0.1, "dragging a rotated tape endpoint keeps its opposite endpoint fixed")
	_expect((new_center + axis * half_length).distance_to(destination) < 0.1, "the dragged tape endpoint follows the real mouse position")
	_expect(is_equal_approx(float(settings.get("width", 0)), 1.4) and is_equal_approx(float(canvas.stickers[0].scale), 0.1), "endpoint length drag preserves tape width and uniform scale")
	var blocking := Button.new()
	blocking.position = Vector2(1090, 150)
	blocking.size = Vector2(220, 80)
	blocking.text = "Release target"
	root.add_child(blocking)
	await process_frame
	_mouse_button(blocking.get_global_rect().get_center(), false)
	await process_frame
	var released: Dictionary = canvas.export_data()
	_mouse_motion(center + Vector2(30, 20), false)
	await process_frame
	_expect(canvas.export_data() == released, "release over a sibling GUI button stops endpoint movement without sticking")
	canvas.undo()
	_expect(canvas.export_data() == before, "one undo restores an entire mouse-driven endpoint drag")
	canvas.selected_index = 0
	blocking.queue_free()

func _test_portable_storage() -> void:
	var folder := "user://tape_editing_" + Crypto.new().generate_random_bytes(8).hex_encode()
	var paper: Dictionary = canvas.export_data()
	var book = Repository.new(folder + "/book.json")
	var record := {"id": "tape_editing_recipe", "title": "胶带拼贴菜谱", "author": "回归测试主厨", "notes": "独立长宽、颜色、旋转都应保留。", "dish": {"ingredients": []}, "poster": paper}
	_expect(book.save_recipe(record), "colored and resized tape is valid paper-only recipe content: %s" % book.last_error)
	var reloaded = Repository.new(folder + "/book.json")
	var loaded: Array = reloaded.load_recipes()
	_expect(loaded.size() == 1 and _same_json(loaded[0].get("poster", {}), paper), "recipe JSON reload preserves all tape properties and transforms")
	_expect(book.export_to(folder + "/portable.json") == OK, "recipe with custom tape exports to portable JSON")
	var imported = Repository.new(folder + "/imported.json")
	var result: Dictionary = imported.import_from(folder + "/portable.json")
	_expect(result.get("added", 0) == 1 and result.get("error", "").is_empty(), "portable recipe containing custom tape imports successfully")
	var imported_records: Array = imported.load_recipes()
	_expect(imported_records.size() == 1 and _same_json(imported_records[0].get("poster", {}), paper), "recipe import preserves tape color, dimensions, position, scale and rotation")
	var store = PosterStore.new(folder + "/poster.json")
	var poster: Dictionary = paper.duplicate(true)
	poster["tags"] = ["sweet"]
	_expect(store.save_poster(poster), "wall poster accepts the same editable tape format: %s" % store.last_error)
	var fresh_store = PosterStore.new(folder + "/poster.json")
	_expect(_same_json(fresh_store.load_poster(), poster), "wall poster JSON reload preserves custom tape and recruitment tags")
	var copy_error: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(folder + "/poster.json"), ProjectSettings.globalize_path(folder + "/transferred_poster.json"))
	_expect(copy_error == OK, "poster JSON can be transferred as a standalone file")
	var transferred = PosterStore.new(folder + "/transferred_poster.json")
	var transferred_data: Dictionary = transferred.load_poster()
	_expect(_same_json(transferred_data, poster), "independently opened transferred poster retains every tape field")
	var imported_canvas = Canvas.new()
	root.add_child(imported_canvas)
	imported_canvas.import_data(transferred_data)
	_expect(_same_json(imported_canvas.export_data(), paper), "canvas import rebuilds the same custom tape data from transferred JSON")
	for index in imported_canvas.stickers.size():
		if imported_canvas.stickers[index].kind == "tape":
			var tape: Dictionary = imported_canvas.stickers[index]
			_expect(imported_canvas._base_extent(index).is_equal_approx(Vector2(80.0 * float(tape.get("length", 1.0)), 32.0 * float(tape.get("width", 1.0)))), "imported tape geometry is rebuilt from stored independent dimensions")
	imported_canvas.queue_free()

func _color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is String:
		return Color.from_string(value, Color.TRANSPARENT)
	return Color.TRANSPARENT

func _click(point: Vector2) -> void:
	_mouse_motion(point, false)
	await process_frame
	_mouse_button(point, true)
	await process_frame
	_mouse_button(point, false)
	await process_frame

func _mouse_button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	Input.parse_input_event(event)

func _mouse_motion(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * point
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)

func _same_json(actual: Variant, expected: Variant) -> bool:
	if (actual is int or actual is float) and (expected is int or expected is float):
		return absf(float(actual) - float(expected)) < 0.00000001
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size(): return false
		for key in expected:
			if not actual.has(key) or not _same_json(actual[key], expected[key]): return false
		return true
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for index in expected.size():
			if not _same_json(actual[index], expected[index]): return false
		return true
	return typeof(actual) == typeof(expected) and actual == expected

func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
