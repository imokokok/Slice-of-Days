extends Control
signal photo_selected(image: Image, metadata: Dictionary)
var selection_mode := false
var library := PhotoLibrary.new()

func _ready() -> void:
	theme = preload("res://scripts/town_sound/MediaTheme.gd").build()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("eee5d3")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "选择一张照片做封面" if selection_mode else "本地相册 / 留在小镇的画面"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "返回"
	close.pressed.connect(queue_free)
	header.add_child(close)
	var status := Label.new()
	status.text = "拍下的照片只保存在本机。"
	column.add_child(status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	var photos := library.list_photos()
	if photos.is_empty(): status.text = "相册还是空的。回到小镇，点击右上角相机拍第一张照片。"
	for item in photos:
		var full := library.load_photo(item.photo_id)
		if full == null: continue
		var thumbnail := full.duplicate()
		thumbnail.resize(230, 130, Image.INTERPOLATE_LANCZOS)
		var card := VBoxContainer.new()
		grid.add_child(card)
		var view := TextureRect.new()
		view.texture = ImageTexture.create_from_image(thumbnail)
		view.custom_minimum_size = Vector2(230, 130)
		card.add_child(view)
		var caption := Label.new()
		caption.text = "%s · 第 %d 天" % [item.get("title", "小镇"), item.get("day", 1)]
		card.add_child(caption)
		var select := Button.new()
		select.text = "用作封面" if selection_mode else "查看照片"
		select.pressed.connect(func() -> void:
			var selected_image := library.load_photo(item.photo_id)
			if selected_image == null:
				status.text = library.last_error
				return
			if selection_mode:
				photo_selected.emit(selected_image, item)
				queue_free()
			else:
				var dialog := AcceptDialog.new()
				dialog.title = str(item.get("title", "照片"))
				var display := TextureRect.new()
				display.texture = ImageTexture.create_from_image(selected_image)
				display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				display.custom_minimum_size = Vector2(760, 430)
				dialog.add_child(display)
				add_child(dialog)
				dialog.popup_centered()
				dialog.confirmed.connect(dialog.queue_free)
				dialog.canceled.connect(dialog.queue_free))
		card.add_child(select)
