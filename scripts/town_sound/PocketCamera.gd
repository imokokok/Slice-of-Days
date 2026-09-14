extends Control

const SUBJECTS_PATH := "res://data/photography/subjects.json"
const INK := Color("f5ead2")
const MUTED := Color("aeb5b2")
const AMBER := Color("e7bd61")
const DARK := Color("0a0d10")

var source: Image
var context: Dictionary = {}
var library := PhotoLibrary.new()
var subjects: Array[Dictionary] = []
var current_subject: Dictionary = {}
var preview: TextureRect
var preview_frame: Panel
var overlay: Control
var focus_label: Label
var zoom_label: Label
var count_label: Label
var shutter: Button
var flash: ColorRect
var capture_card: Panel
var capture_image: TextureRect
var capture_category: Label
var capture_word: Label
var capture_title: Label
var capture_note: Label
var zoom_value := 1.22
var pan := Vector2(0.5, 0.5)
var dragging := false
var card_back := false


func _ready() -> void:
	theme = preload("res://scripts/town_sound/MediaTheme.gd").build()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_load_subjects()
	_build_camera()
	update_preview()


func _build_camera() -> void:
	var background := ColorRect.new()
	background.color = DARK
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)

	var top := ColorRect.new()
	top.color = Color("10151a")
	top.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	top.offset_bottom = 68
	add_child(top)
	_make_label(top, "SOLMERE  /  POCKET 35", Vector2(28, 14), Vector2(280, 30), 17, INK)
	var location := _make_label(top, str(context.get("title", "小镇")), Vector2.ZERO, Vector2.ZERO, 21, Color("fff4d8"))
	location.anchor_left = 0.5
	location.anchor_right = 0.5
	location.offset_left = -220
	location.offset_right = 220
	location.offset_top = 13
	location.offset_bottom = 49
	location.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var meta := _make_label(top, "DAY %02d  ·  %s  ·  %s" % [int(context.get("day", 1)), str(context.get("role", "")), _minute_text(int(context.get("game_minute", 0)))], Vector2.ZERO, Vector2.ZERO, 15, MUTED)
	meta.anchor_left = 1.0
	meta.anchor_right = 1.0
	meta.offset_left = -440
	meta.offset_right = -148
	meta.offset_top = 17
	meta.offset_bottom = 47
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var close := _make_button(top, "收起  Esc", Vector2.ZERO, Vector2.ZERO, false)
	close.anchor_left = 1.0
	close.anchor_right = 1.0
	close.offset_left = -128
	close.offset_right = -16
	close.offset_top = 10
	close.offset_bottom = 48
	close.pressed.connect(queue_free)

	preview_frame = Panel.new()
	preview_frame.anchor_left = 0.5
	preview_frame.anchor_right = 0.5
	preview_frame.offset_left = -620
	preview_frame.offset_right = 620
	preview_frame.offset_top = 82
	preview_frame.offset_bottom = 779
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("030405")
	frame_style.border_color = Color("3d4548")
	frame_style.set_border_width_all(2)
	preview_frame.add_theme_stylebox_override("panel", frame_style)
	preview_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_frame.gui_input.connect(_viewfinder_input)
	add_child(preview_frame)
	preview = TextureRect.new()
	preview.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	preview.offset_left = 3
	preview.offset_right = -3
	preview.offset_top = 3
	preview.offset_bottom = -3
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.mouse_filter = MOUSE_FILTER_IGNORE
	preview_frame.add_child(preview)
	overlay = preload("res://scripts/town_sound/viewfinder_overlay.gd").new()
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.offset_left = 3
	overlay.offset_right = -3
	overlay.offset_top = 3
	overlay.offset_bottom = -3
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.add_child(overlay)

	var auto_badge := _make_label(preview_frame, "  AUTO  ·  景物识别  ", Vector2(18, 18), Vector2(190, 30), 14, Color("14201d"))
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("d8c780", 0.88)
	badge_style.set_corner_radius_all(5)
	auto_badge.add_theme_stylebox_override("normal", badge_style)
	zoom_label = _make_label(preview_frame, "", Vector2.ZERO, Vector2(100, 30), 15, INK)
	zoom_label.anchor_left = 1.0
	zoom_label.anchor_right = 1.0
	zoom_label.offset_left = -120
	zoom_label.offset_right = -20
	zoom_label.offset_top = 18
	zoom_label.offset_bottom = 48
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var focus_pill := Panel.new()
	focus_pill.set_anchors_preset(PRESET_CENTER_BOTTOM)
	focus_pill.position = Vector2(-275, -82)
	focus_pill.size = Vector2(550, 64)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color("080b0d", 0.76)
	focus_style.border_color = Color("d2bc7d", 0.5)
	focus_style.set_border_width_all(1)
	focus_style.set_corner_radius_all(12)
	focus_pill.add_theme_stylebox_override("panel", focus_style)
	preview_frame.add_child(focus_pill)
	focus_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_label = _make_label(focus_pill, "", Vector2(18, 8), Vector2(514, 48), 16, INK)
	focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var bottom := ColorRect.new()
	bottom.color = Color("11171c")
	bottom.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	bottom.offset_top = -124
	add_child(bottom)
	var controls := _make_label(bottom, "滚轮  变焦\n拖动画面 / 方向键  构图", Vector2(30, 27), Vector2(410, 66), 15, MUTED)
	controls.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shutter = _make_button(bottom, "", Vector2.ZERO, Vector2.ZERO, true)
	shutter.anchor_left = 0.5
	shutter.anchor_right = 0.5
	shutter.anchor_top = 0.5
	shutter.anchor_bottom = 0.5
	shutter.offset_left = -39
	shutter.offset_right = 39
	shutter.offset_top = -48
	shutter.offset_bottom = 30
	shutter.tooltip_text = "按下快门 · Space / Enter"
	shutter.pressed.connect(take_photo)
	var space_hint := _make_label(bottom, "SPACE", Vector2.ZERO, Vector2.ZERO, 12, MUTED)
	space_hint.anchor_left = 0.5
	space_hint.anchor_right = 0.5
	space_hint.anchor_top = 0.5
	space_hint.anchor_bottom = 0.5
	space_hint.offset_left = -50
	space_hint.offset_right = 50
	space_hint.offset_top = 34
	space_hint.offset_bottom = 58
	space_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label = _make_label(bottom, "", Vector2.ZERO, Vector2.ZERO, 15, INK)
	count_label.anchor_left = 1.0
	count_label.anchor_right = 1.0
	count_label.anchor_top = 0.5
	count_label.anchor_bottom = 0.5
	count_label.offset_left = -340
	count_label.offset_right = -30
	count_label.offset_top = -30
	count_label.offset_bottom = 30
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_build_capture_card()
	flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	flash.mouse_filter = MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	add_child(flash)
	_refresh_count()


func _build_capture_card() -> void:
	capture_card = Panel.new()
	capture_card.set_anchors_preset(PRESET_TOP_RIGHT)
	capture_card.position = Vector2(-358, 94)
	capture_card.size = Vector2(324, 372)
	capture_card.pivot_offset = capture_card.size * 0.5
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f4ecd8")
	paper.border_color = Color("d7bd82")
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(8)
	paper.shadow_color = Color("000000", 0.42)
	paper.shadow_size = 18
	paper.shadow_offset = Vector2(0, 8)
	capture_card.add_theme_stylebox_override("panel", paper)
	add_child(capture_card)
	capture_category = _make_label(capture_card, "", Vector2(20, 14), Vector2(284, 24), 12, Color("8b5b44"))
	capture_image = TextureRect.new()
	capture_image.position = Vector2(18, 45)
	capture_image.size = Vector2(288, 162)
	capture_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	capture_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	capture_card.add_child(capture_image)
	capture_word = _make_label(capture_card, "", Vector2(20, 214), Vector2(284, 22), 13, Color("8b5b44"))
	capture_title = _make_label(capture_card, "", Vector2(20, 237), Vector2(284, 34), 24, Color("322923"))
	capture_note = _make_label(capture_card, "", Vector2(20, 274), Vector2(284, 54), 14, Color("6f625a"))
	capture_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var dismiss := _make_button(capture_card, "继续取景", Vector2(188, 334), Vector2(116, 28), false)
	dismiss.pressed.connect(func() -> void: capture_card.hide())
	var flip := _make_button(capture_card, "翻面 · 笔记", Vector2(20, 334), Vector2(130, 28), false)
	flip.pressed.connect(_flip_capture)
	capture_card.hide()


func _load_subjects() -> void:
	if context.has("subjects"):
		subjects.assign(context.subjects)
		return
	if not FileAccess.file_exists(SUBJECTS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SUBJECTS_PATH))
	if parsed is Dictionary:
		for raw in parsed.get("locations", {}).get(str(context.get("location", "")), []):
			if raw is Dictionary:
				subjects.append((raw as Dictionary).duplicate(true))


func cropped_image() -> Image:
	if source == null or source.is_empty():
		return Image.new()
	var width := maxi(1, int(source.get_width() / zoom_value))
	var height := maxi(1, int(source.get_height() / zoom_value))
	var x := int((source.get_width() - width) * pan.x)
	var y := int((source.get_height() - height) * pan.y)
	return source.get_region(Rect2i(x, y, width, height))


func update_preview() -> void:
	if preview == null or source == null:
		return
	preview.texture = ImageTexture.create_from_image(cropped_image())
	zoom_label.text = "%0.1fx" % zoom_value
	_update_focus()


func _update_focus() -> void:
	current_subject = {}
	var center := _view_center()
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for subject in subjects:
		var target_data: Array = subject.get("target", [0.5, 0.5])
		var target := Vector2(float(target_data[0]), float(target_data[1]))
		var distance := center.distance_to(target)
		if distance < nearest_distance:
			nearest = subject
			nearest_distance = distance
	if not nearest.is_empty() and nearest_distance <= 0.095:
		current_subject = nearest
		overlay.set_focus(true)
		focus_label.text = "● 已对焦  %s\n%s" % [str(nearest.get("name", "景物")), str(nearest.get("category", "小镇发现"))]
		focus_label.add_theme_color_override("font_color", AMBER)
	elif not nearest.is_empty() and nearest_distance <= 0.26:
		overlay.set_focus(false)
		focus_label.text = "○ 画面里有值得靠近的东西  ·  拖动构图让它进入中心"
		focus_label.add_theme_color_override("font_color", INK)
	else:
		overlay.set_focus(false)
		focus_label.text = "移动取景框，寻找一处想记住的景物"
		focus_label.add_theme_color_override("font_color", INK)


func _view_center() -> Vector2:
	var visible := 1.0 / zoom_value
	return Vector2((1.0 - visible) * pan.x + visible * 0.5, (1.0 - visible) * pan.y + visible * 0.5)


func take_photo() -> void:
	if shutter == null or shutter.disabled:
		return
	shutter.disabled = true
	_flash_shutter()
	var shot_context := context.duplicate(true)
	if not current_subject.is_empty():
		shot_context["subject_id"] = str(current_subject.get("id", ""))
		shot_context["subject_name"] = str(current_subject.get("name", ""))
		shot_context["subject_category"] = str(current_subject.get("category", ""))
		shot_context["subject_note"] = str(current_subject.get("note", ""))
		shot_context["subject_word"] = str(current_subject.get("word", current_subject.get("name", "")))
	var image := cropped_image()
	var photo := library.save_photo(image, shot_context)
	if photo.is_empty():
		focus_label.text = library.last_error
		shutter.disabled = false
		return
	var is_new_subject := not current_subject.is_empty() and not _subject_discovered(str(current_subject.get("id", "")))
	if has_node("/root/GameState"):
		var photo_title := str(current_subject.get("name", context.get("title", "小镇")))
		GameState.add_artifact("photos", {"id": str(photo.photo_id), "title": "%s · %s" % [photo_title, GameState.clock_text()], "kind": "photo", "location": str(context.get("location", ""))})
		if not current_subject.is_empty():
			GameState.add_artifact("photo_subjects", {"id": str(current_subject.get("id", "")), "title": str(current_subject.get("name", "景物")), "kind": "photo_subject", "location": str(context.get("location", "")), "note": str(current_subject.get("note", ""))})
		GameState.add_journal_entry({"id": "photo_%s" % str(photo.photo_id), "kind": "photo", "text": "在%s拍下%s，画面已留在本地相册。" % [str(context.get("title", "小镇")), photo_title]})
		SaveManager.save_or_report("拍照后保存失败")
		WorldSound.play_ui("shutter")
	_show_capture(image, current_subject, is_new_subject)
	_refresh_count()
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if is_instance_valid(shutter): shutter.disabled = false)


func _show_capture(image: Image, subject: Dictionary, is_new: bool) -> void:
	capture_image.texture = ImageTexture.create_from_image(image)
	if subject.is_empty():
		capture_category.text = "自由摄影  ·  已收入本地相册"
		capture_word.text = "SOLMERE FIELD NOTE"
		capture_title.text = str(context.get("title", "小镇的一刻"))
		capture_note.text = "这张照片没有被标签定义，但仍属于今天。"
		focus_label.text = "咔嚓 · 自由照片已保存"
	else:
		capture_category.text = ("新发现  ·  " if is_new else "再次拍到  ·  ") + str(subject.get("category", "小镇发现"))
		capture_word.text = str(subject.get("word", subject.get("name", "景物"))).to_upper() + "  /  小镇词卡"
		capture_title.text = str(subject.get("name", "景物"))
		capture_note.text = str(subject.get("note", ""))
		focus_label.text = "咔嚓 · %s已进入景物图鉴" % str(subject.get("name", "这处景物"))
	capture_card.show()
	card_back = false
	capture_image.show()
	capture_note.position = Vector2(20, 274)
	capture_note.size = Vector2(284, 54)
	capture_card.modulate = Color(1, 1, 1, 0)
	capture_card.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(capture_card, "modulate:a", 1.0, 0.18)
	tween.tween_property(capture_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _subject_discovered(subject_id: String) -> bool:
	if subject_id.is_empty() or not has_node("/root/GameState"):
		return false
	for artifact in GameState.artifacts.get("photo_subjects", []):
		if str(artifact.get("id", "")) == subject_id:
			return true
	return false


func _flash_shutter() -> void:
	flash.modulate.a = 0.72
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.22)


func _refresh_count() -> void:
	if count_label == null:
		return
	var discovered := 0
	if has_node("/root/GameState"):
		discovered = (GameState.artifacts.get("photo_subjects", []) as Array).size()
	count_label.text = "本地相册  %d / 128\n景物图鉴  %d 已发现" % [library.list_photos().size(), discovered]


func _set_zoom(value: float) -> void:
	zoom_value = clampf(value, 1.0, 4.0)
	capture_card.hide()
	update_preview()

func _flip_capture() -> void:
	card_back = not card_back
	capture_image.visible = not card_back
	capture_note.position = Vector2(20, 60) if card_back else Vector2(20, 274)
	capture_note.size = Vector2(284, 140) if card_back else Vector2(284, 54)
	WorldSound.play_ui("dialogue")

func _viewfinder_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_set_zoom(zoom_value + (0.14 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.14))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		preview_frame.accept_event()
	elif event is InputEventMouseMotion and dragging:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_move_pan(-event.relative / preview_frame.size.max(Vector2.ONE) * 1.8)
		else: dragging = false
		preview_frame.accept_event()


func _move_pan(delta: Vector2) -> void:
	pan = (pan + delta).clamp(Vector2.ZERO, Vector2.ONE)
	capture_card.hide()
	update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("dialogue_advance"):
			take_photo()
		elif event.is_action_pressed("ui_cancel"):
			queue_free()
		elif event.is_action_pressed("ui_left") or event.physical_keycode == KEY_A:
			_move_pan(Vector2(-0.035, 0))
		elif event.is_action_pressed("ui_right") or event.physical_keycode == KEY_D:
			_move_pan(Vector2(0.035, 0))
		elif event.is_action_pressed("ui_up") or event.physical_keycode == KEY_W:
			_move_pan(Vector2(0, -0.035))
		elif event.is_action_pressed("ui_down") or event.physical_keycode == KEY_S:
			_move_pan(Vector2(0, 0.035))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			_set_zoom(zoom_value + (0.14 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.14))
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed and preview_frame.get_global_rect().has_point(event.position)
	elif event is InputEventMouseMotion and dragging:
		var frame_size := preview_frame.size.max(Vector2.ONE)
		_move_pan(-event.relative / frame_size * 1.8)
		get_viewport().set_input_as_handled()


func _make_label(parent: Node, value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_button(parent: Node, value: String, at: Vector2, button_size: Vector2, round := false) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = button_size
	button.add_theme_font_size_override("font_size", 14)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("171d21") if not round else Color("eee5cf")
	normal.border_color = Color("777e7d") if not round else Color("ffffff")
	normal.set_border_width_all(2 if not round else 6)
	normal.set_corner_radius_all(9 if not round else 39)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.14)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.16)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", INK)
	parent.add_child(button)
	return button


func _minute_text(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]
