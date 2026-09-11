extends Control

const TRANSITIONS_PATH := "res://data/story/transitions.json"
const FALLBACK_BACKGROUND := preload("res://art/ui/title-screen-background.png")
const PAPER := Color("fff8eb")
const INK := Color("4a342b")
const MUTED := Color("806b5c")
const TERRACOTTA := Color("c85f43")
const TEAL := Color("4f7d83")
const LINE := Color("b88963")

var moving_card: Panel
var alignment_slider: HSlider
var instruction_label: Label
var continue_button: Button
var transition_id := ""
var beat: Dictionary = {}
var context: Dictionary = {}
var target_position := Vector2(660, 232)
var motion_vector := Vector2(250, 18)


func _ready() -> void:
	_prepare_capture_context()
	context = ChapterSystem.transition_context()
	transition_id = str(context.get("transition_id", "transition"))
	beat = _resolve_beat(context)
	_build_ui()
	_update_alignment(10.0)
	if _capture_requested():
		_capture.call_deferred("chapter-transition.png")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("ead9bd"))
	draw_texture_rect(FALLBACK_BACKGROUND, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color("fff5df", 0.58))
	for y in range(178, 700, 34):
		draw_line(Vector2(120, y), Vector2(1480, y), Color("b8a98e", 0.08), 1)


func _build_ui() -> void:
	var heading_wash := ColorRect.new()
	heading_wash.position = Vector2(58, 32)
	heading_wash.size = Vector2(1484, 172)
	heading_wash.color = Color(PAPER, 0.66)
	heading_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(heading_wash)
	var eyebrow := _make_label(self, str(beat.get("eyebrow", "两段生活之间")), Vector2(92, 54), Vector2(800, 28), 15, TEAL)
	eyebrow.add_theme_color_override("font_shadow_color", Color(PAPER, 0.5))
	_make_label(self, str(beat.get("title", "两份记录在边缘相遇")), Vector2(88, 88), Vector2(1180, 52), 34, INK)
	var body := _make_label(self, str(beat.get("body", "")), Vector2(92, 145), Vector2(1050, 54), 16, MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var motif := _make_label(self, str(beat.get("motif", "照片与记录")), Vector2(1210, 94), Vector2(290, 30), 15, MUTED)
	motif.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var current: Dictionary = context.get("from", {})
	var next: Dictionary = context.get("to", {})
	var from_role := str(current.get("role", GameState.current_role))
	var to_role := str(next.get("role", "B" if from_role == "A" else "A"))
	var role_rows: Dictionary = beat.get("roles", {})
	_make_memory_card(Vector2(235, 236), from_role, role_rows.get(from_role, {}), false)
	moving_card = _make_memory_card(Vector2(910, 254), to_role, role_rows.get(to_role, {}), true)
	motion_vector = _motion_for(str(beat.get("motion", "horizontal")))
	if SettingsSystem.reduced_motion():
		motion_vector = Vector2.ZERO

	instruction_label = _make_label(
		self,
		str(beat.get("instruction", "移动右侧记录，让两份生活在边缘相遇。")),
		Vector2(360, 665),
		Vector2(880, 52),
		16,
		INK
	)
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	alignment_slider = HSlider.new()
	alignment_slider.position = Vector2(500, 728)
	alignment_slider.size = Vector2(600, 34)
	alignment_slider.min_value = 0
	alignment_slider.max_value = 100
	alignment_slider.step = 1
	alignment_slider.value = 10
	alignment_slider.value_changed.connect(_update_alignment)
	add_child(alignment_slider)

	var align := _make_button(self, "轻轻对齐", Vector2(570, 790), Vector2(200, 50), TEAL)
	align.pressed.connect(func() -> void: alignment_slider.value = 50)
	continue_button = _make_button(self, "继续", Vector2(830, 790), Vector2(200, 50), TERRACOTTA)
	continue_button.disabled = true
	continue_button.pressed.connect(_continue_journey)


func _make_memory_card(at: Vector2, role: String, role_data: Dictionary, moving: bool) -> Panel:
	var tint := Color(str(role_data.get("tint", "4f7d83" if role == "B" else "c85f43")))
	var panel := Panel.new()
	panel.position = at
	panel.size = Vector2(430, 350)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PAPER, 0.97)
	style.border_color = tint
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(INK, 0.24)
	style.shadow_size = 14 if moving else 10
	style.shadow_offset = Vector2(0, 7)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var image := TextureRect.new()
	image.position = Vector2(16, 16)
	image.size = Vector2(398, 218)
	image.texture = _texture_for(role_data)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.modulate = Color(1, 1, 1, 0.90)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(image)

	var wash := ColorRect.new()
	wash.position = image.position
	wash.size = image.size
	wash.color = Color(tint, 0.16)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(wash)

	var role_mark := _make_label(panel, role, Vector2(30, 30), Vector2(56, 42), 28, PAPER)
	role_mark.add_theme_color_override("font_shadow_color", Color(INK, 0.52))
	role_mark.add_theme_constant_override("shadow_offset_x", 2)
	role_mark.add_theme_constant_override("shadow_offset_y", 2)
	_make_label(panel, str(role_data.get("label", "%s的记录" % role)), Vector2(24, 250), Vector2(380, 30), 18, tint)
	var caption := _make_label(panel, str(role_data.get("caption", "")), Vector2(24, 286), Vector2(380, 48), 14, INK)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return panel


func _texture_for(role_data: Dictionary) -> Texture2D:
	var path := str(role_data.get("image_path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Texture2D:
			return loaded
	return FALLBACK_BACKGROUND


func _resolve_beat(transition_context: Dictionary) -> Dictionary:
	var data := _load_json(TRANSITIONS_PATH)
	var current: Dictionary = transition_context.get("from", {})
	var next: Dictionary = transition_context.get("to", {})
	if bool(transition_context.get("is_final", false)):
		return data.get("final", {})
	var day := int(current.get("day", 1))
	var key := "same_day" if int(next.get("day", day)) == day else "next_day"
	for row in data.get("days", []):
		if int(row.get("day", 0)) == day:
			return row.get(key, {})
	return {}


func _motion_for(kind: String) -> Vector2:
	match kind:
		"vertical":
			return Vector2(250, -118)
		"diagonal":
			return Vector2(260, 112)
		"insert":
			return Vector2(260, 58)
		_:
			return Vector2(250, 18)


func _update_alignment(value: float) -> void:
	if moving_card == null:
		return
	var offset := (50.0 - value) / 50.0
	moving_card.position = target_position + motion_vector * offset
	var aligned: bool = abs(value - 50.0) <= 3.0
	if continue_button != null:
		continue_button.disabled = not aligned
	if instruction_label != null:
		instruction_label.text = str(beat.get("completion", "两份记录已经在边缘重叠。")) if aligned else str(beat.get("instruction", "移动右侧记录。"))


func _continue_journey() -> void:
	ChapterSystem.mark_transition_complete(transition_id)
	var result := ChapterSystem.advance_chapter()
	SaveManager.save_game()
	if bool(result.get("complete", false)):
		SceneRouter.ending()
	else:
		SceneRouter.town_day()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Transition data not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid transition data: %s" % path)
		return {}
	return parsed


func _prepare_capture_context() -> void:
	var requested := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-transition="):
			requested = arg.trim_prefix("--capture-transition=")
			break
	if requested.is_empty():
		return
	var parts := requested.split("_to_")
	if parts.is_empty():
		return
	var from_id := str(parts[0])
	var role := "B" if from_id.ends_with("_b") else "A"
	ChapterSystem.start_new_game(role)
	var sequence := ChapterSystem.chapter_sequence()
	for index in sequence.size():
		if str(sequence[index].get("id", "")) == from_id:
			GameState.shared_state["chapter_index"] = index
			var chapter: Dictionary = sequence[index]
			GameState.switch_to_role(str(chapter.get("role", role)), int(chapter.get("day", 1)), true)
			break


func _capture_requested() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-transition="):
			return true
	return false


func _capture(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory.path_join(filename))
	get_tree().quit()


func _make_label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = button_size
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = color.darkened(0.15)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color(INK, 0.16)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0, 3)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.1)
	button.add_theme_stylebox_override("hover", hover)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color("cfc5b5")
	disabled.border_color = LINE
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", PAPER)
	button.add_theme_color_override("font_disabled_color", Color(PAPER, 0.72))
	parent.add_child(button)
	return button
