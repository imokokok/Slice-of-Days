extends SceneTree
## Shared recipe/poster toolbar routing and grouped slider undo.
var game
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	Engine.max_fps = 120
	call_deferred("_run")

func _run() -> void:
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path": "user://tape_tools_%s/cookbook.json" % Time.get_ticks_usec()})
	root.add_child(game)
	await _layout()
	game._start_shift()
	for kind in ["recipe", "poster"]:
		if kind == "recipe": game._show_recipe_editor()
		else: game._show_poster()
		await _layout()
		var paper = game._recipe_canvas if kind == "recipe" else game._poster_canvas
		var dimensions: Control = game.modal_body.find_child("TapeDimensions", true, false)
		var picker: ColorPickerButton = game.modal_body.find_child("CollageColor", true, false)
		_expect(not dimensions.visible and not paper.has_content(), kind + " opens blank, with tape controls hidden")
		await _click(_button("胶带").get_global_rect().get_center())
		_expect(dimensions.visible and picker.text == "素材颜色", kind + " selecting tape exposes shared decoration properties")
		var rect: Rect2 = game.modal_panel.get_global_rect()
		_expect(rect.end.y <= 900 and rect.end.x <= 1600, kind + " expanded toolbar fits viewport")
		_expect(dimensions.get_global_rect().end.x <= rect.end.x, kind + " length and width stay within the panel")
		var length: HSlider = dimensions.find_child("TapeLength", true, false)
		var width: HSlider = dimensions.find_child("TapeWidth", true, false)
		var start: Vector2 = length.get_global_rect().position + Vector2(12, length.size.y / 2)
		_mouse(start, "press")
		await process_frame
		for fraction in [0.3, 0.5, 0.75]:
			_mouse(length.get_global_rect().position + Vector2(length.size.x * fraction, length.size.y / 2), "drag")
			await process_frame
		_mouse(length.get_global_rect().position + Vector2(length.size.x * 0.75, length.size.y / 2), "release")
		await _layout()
		_expect(float(paper.selected_tape_settings().length) > 3.0, kind + " actual slider drag lengthens tape")
		_expect(is_equal_approx(float(paper.selected_tape_settings().width), 1.0), kind + " length slider preserves width")
		await _click(_button("撤销").get_global_rect().get_center())
		_expect(paper.stickers.size() == 1 and is_equal_approx(float(paper.stickers[0].get("length", 1)), 1.0), kind + " one undo restores whole slider gesture")
		# Reselect after undo and route a distinct width gesture.
		await _click(paper.global_position + paper._pixel(paper.stickers[0].position))
		await _click(width.get_global_rect().position + Vector2(width.size.x * 0.8, width.size.y / 2))
		_expect(float(paper.selected_tape_settings().width) > 2.0, kind + " width slider is independent")
		var old_ink: Color = paper.ink
		await _click(picker.get_global_rect().get_center())
		_expect(picker.get_popup().visible, kind + " color swatch opens the actual color picker")
		picker.get_picker().color_changed.emit(Color("bd715d"))
		picker.get_picker().color_changed.emit(Color("537b78"))
		picker.get_popup().hide()
		await _layout()
		_expect(Color(str(paper.selected_tape_settings().color)).is_equal_approx(Color("537b78")), kind + " color picker routes to selected tape")
		_expect(paper.ink == old_ink, kind + " tape tint leaves brush color alone")
		await _click(_button("画笔涂鸦").get_global_rect().get_center())
		_expect(not dimensions.visible and picker.text == "画笔颜色", kind + " draw mode restores brush controls")
		picker.color_changed.emit(Color("a73320"))
		_expect(paper.ink == Color("a73320") and Color(str(paper.stickers[0].color)) == Color("537b78"), kind + " brush color changes leave tape tint alone")
		await _click(_button("移动素材").get_global_rect().get_center())
		_expect(dimensions.visible and picker.color == Color("537b78"), kind + " returning to selection restores tape color")
		await _click(_button("星星").get_global_rect().get_center())
		_expect(dimensions.visible and picker.text == "素材颜色" and not paper.selected_decoration_settings().is_empty(), kind + " every sticker exposes color and independent dimensions")
		game._close_modal()
		await _layout()
	game.world.audio.muted = true
	await create_timer(0.14).timeout
	game.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("%s: shared tape tools, %d checks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _button(title: String) -> Button:
	for button in game.modal_body.find_children("*", "Button", true, false):
		if button.text == title: return button
	return null

func _mouse(point: Vector2, kind: String) -> void:
	point = root.get_final_transform() * point
	if kind == "drag":
		var event := InputEventMouseMotion.new()
		event.position = point
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = kind == "press"
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if event.pressed else 0
		Input.parse_input_event(event)

func _click(point: Vector2) -> void:
	_mouse(point, "press")
	await process_frame
	_mouse(point, "release")
	await _layout()

func _layout() -> void:
	await process_frame
	await process_frame

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
