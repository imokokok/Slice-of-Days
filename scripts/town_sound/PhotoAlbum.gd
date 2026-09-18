extends Control

signal photo_selected(image: Image, metadata: Dictionary)

const PAPER := Color("f3ead5")
const INK := Color("302923")
const MUTED := Color("766b63")
const AMBER := Color("b56b49")

var selection_mode := false
var library := PhotoLibrary.new()
var status: Label


func _ready() -> void:
	theme = preload("res://scripts/town_sound/MediaTheme.gd").build()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("172126")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	var album := Panel.new()
	album.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	album.offset_left = 28
	album.offset_right = -28
	album.offset_top = 24
	album.offset_bottom = -24
	var album_style := StyleBoxFlat.new()
	album_style.bg_color = Color("e5d8bd")
	album_style.border_color = Color("9e7959")
	album_style.set_border_width_all(2)
	album_style.set_corner_radius_all(16)
	album_style.shadow_color = Color("000000", 0.38)
	album_style.shadow_size = 18
	album_style.shadow_offset = Vector2(0, 8)
	album.add_theme_stylebox_override("panel", album_style)
	add_child(album)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	album.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 50
	column.add_child(header)
	var title := Label.new()
	title.text = LocalizationSystem.text("挑一张旅途照片" if selection_mode else "景物相册  /  SOLMERE FIELD NOTES")
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", INK)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	var photos := library.list_photos()
	var discovered := 0
	if has_node("/root/GameState"):
		discovered = (GameState.artifacts.get("photo_subjects", []) as Array).size()
	var stats := Label.new()
	stats.text = LocalizationSystem.text("%d 张照片  ·  %d 个景物" % [photos.size(), discovered])
	stats.add_theme_font_size_override("font_size", 15)
	stats.add_theme_color_override("font_color", MUTED)
	stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(stats)
	var close := Button.new()
	close.text = LocalizationSystem.text("返回  Esc")
	close.custom_minimum_size = Vector2(112, 40)
	close.pressed.connect(queue_free)
	header.add_child(close)
	status = Label.new()
	status.text = LocalizationSystem.text("每张照片保存在本机；对焦识别过的景物会带着当时的观察笔记。")
	status.add_theme_color_override("font_color", MUTED)
	status.add_theme_font_size_override("font_size", 15)
	column.add_child(status)
	var rule := HSeparator.new()
	column.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)
	if photos.is_empty():
		status.text = LocalizationSystem.text("相册还是空的。回到街道按 C，先寻找取景框中央会亮起名字的景物。")
	for item in photos:
		_add_photo_card(grid, item)


func _add_photo_card(grid: GridContainer, item: Dictionary) -> void:
	var full := library.load_photo(str(item.get("photo_id", "")))
	if full == null:
		return
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 285)
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER
	paper.border_color = Color("c7ad7b")
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(7)
	paper.shadow_color = Color("5a3e2e", 0.18)
	paper.shadow_size = 8
	paper.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", paper)
	grid.add_child(card)
	var inset := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + edge, 12)
	card.add_child(inset)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	inset.add_child(column)
	var category := Label.new()
	category.text = LocalizationSystem.text(str(item.get("subject_category", "自由摄影")).to_upper() + ("  ·  景物卡" if item.has("subject_id") else ""))
	category.add_theme_font_size_override("font_size", 12)
	category.add_theme_color_override("font_color", AMBER)
	column.add_child(category)
	var view := TextureRect.new()
	view.texture = ImageTexture.create_from_image(full)
	view.custom_minimum_size = Vector2(320, 180)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	column.add_child(view)
	var row := HBoxContainer.new()
	column.add_child(row)
	var caption := Label.new()
	caption.text = LocalizationSystem.text(str(item.get("subject_name", item.get("title", "小镇的一刻"))))
	caption.add_theme_font_size_override("font_size", 19)
	caption.add_theme_color_override("font_color", INK)
	caption.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(caption)
	var meta := Label.new()
	meta.text = "D%d · %s" % [int(item.get("day", 1)), _minute_text(int(item.get("game_minute", 0)))]
	meta.add_theme_font_size_override("font_size", 13)
	meta.add_theme_color_override("font_color", MUTED)
	row.add_child(meta)
	var action := Button.new()
	action.text = LocalizationSystem.text("用作唱片封面" if selection_mode else "翻看这张照片")
	action.custom_minimum_size.y = 34
	action.pressed.connect(func() -> void: _activate_photo(item))
	column.add_child(action)


func _activate_photo(item: Dictionary) -> void:
	var selected_image := library.load_photo(str(item.get("photo_id", "")))
	if selected_image == null:
		status.text = LocalizationSystem.text(library.last_error)
		return
	if selection_mode:
		photo_selected.emit(selected_image, item)
		queue_free()
		return
	var dialog := AcceptDialog.new()
	dialog.title = str(item.get("subject_name", item.get("title", "照片")))
	dialog.min_size = Vector2i(860, 610)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	dialog.add_child(column)
	var display := TextureRect.new()
	display.texture = ImageTexture.create_from_image(selected_image)
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.custom_minimum_size = Vector2(800, 450)
	column.add_child(display)
	var note := Label.new()
	note.text = LocalizationSystem.text(str(item.get("subject_word", item.get("subject_name", ""))) + "\n" + str(item.get("subject_note", "这张自由照片没有附加标签。")))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 17)
	note.add_theme_color_override("font_color", MUTED)
	column.add_child(note)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()


func _minute_text(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]
