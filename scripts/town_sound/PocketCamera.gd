extends Control
var source: Image
var context: Dictionary = {}
var library := PhotoLibrary.new()
var preview: TextureRect
var zoom: HSlider
var pan_x: HSlider
var pan_y: HSlider
var status: Label
var shutter: Button

func _ready() -> void:
	theme = preload("res://scripts/town_sound/MediaTheme.gd").build()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("eee5d3")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.position = Vector2(maxf(24, (size.x - 1000) * 0.5), 28)
	column.size = Vector2(1000, 780)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var title := Label.new()
	title.text = "随身相机 / " + str(context.get("title", "小镇"))
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(960, 540)
	column.add_child(preview)
	zoom = make_slider(column, "取景放大", 1, 3, 1)
	pan_x = make_slider(column, "左右构图", 0, 1, 0.5)
	pan_y = make_slider(column, "上下构图", 0, 1, 0.5)
	var row := HBoxContainer.new()
	column.add_child(row)
	shutter = Button.new()
	shutter.text = "◎ 按下快门 · 保存本地"
	shutter.pressed.connect(take_photo)
	row.add_child(shutter)
	var back := Button.new()
	back.text = "收起相机"
	back.pressed.connect(queue_free)
	row.add_child(back)
	status = Label.new()
	status.text = "拍摄游戏中的画面，不启用电脑摄像头。"
	column.add_child(status)
	update_preview()

func make_slider(parent: Node, text: String, minimum: float, maximum: float, value: float) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	row.add_child(label)
	var slider := HSlider.new()
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.01
	slider.value = value
	slider.value_changed.connect(func(_value: float) -> void:
		if shutter != null: shutter.disabled = false
		update_preview())
	row.add_child(slider)
	return slider

func cropped_image() -> Image:
	var width := maxi(1, int(source.get_width() / zoom.value))
	var height := maxi(1, int(source.get_height() / zoom.value))
	return source.get_region(Rect2i(int((source.get_width() - width) * pan_x.value), int((source.get_height() - height) * pan_y.value), width, height))

func update_preview() -> void:
	if source == null or zoom == null or pan_x == null or pan_y == null: return
	preview.texture = ImageTexture.create_from_image(cropped_image())

func take_photo() -> void:
	shutter.disabled = true
	var photo := library.save_photo(cropped_image(), context)
	if photo.is_empty():
		status.text = library.last_error
		shutter.disabled = false
	else:
		status.text = "照片已保存在本地相册。去唱片店制作唱片时，可以选它做封面。"
