extends Control
signal photo_selected(image: Image, metadata: Dictionary)
const STYLE := preload("res://scripts/photography/photo_style.gd")
const PAGE_SIZE := 8
var selection_mode := false
var library := PhotoLibrary.new()
var status: Label
var prints: Dictionary = {}
var inscription: Control
var photos: Array[Dictionary] = []
var page := 0
var grids: Array[GridContainer] = []
var previous_button: Button
var next_button: Button
var page_label: Label

func _ready() -> void:
	add_to_group("world_tool")
	theme=STYLE.theme(18)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color=Color("a9d4ce")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(background)
	var book := preload("res://scripts/photography/photo_album_book.gd").new()
	book.position=Vector2(60,102); book.size=Vector2(1480,748); book.mouse_filter=MOUSE_FILTER_IGNORE; add_child(book)
	_words("挑一张旅途照片" if selection_mode else "旅途相册",Vector2(74,32),Vector2(1000,47),32)
	_button("返回  Esc",Vector2(1358,28),Vector2(174,52),queue_free)
	photos=library.list_photos()
	_words("%d 张照片" % photos.size(),Vector2(1278,139),Vector2(215,34),18)
	status=_words("选择照片，作为你的唱片封面。" if selection_mode else "拍下的风景，和当时想说的话。",Vector2(110,146),Vector2(610,35),19)
	_words("白边留给你写字。",Vector2(877,146),Vector2(345,35),19)
	for side in 2:
		var grid := GridContainer.new(); grid.columns=2
		grid.position=Vector2(110+side*766,199); grid.size=Vector2(616,545)
		grid.add_theme_constant_override("h_separation",18); grid.add_theme_constant_override("v_separation",18)
		add_child(grid); grids.append(grid)
	previous_button=_button("‹ 上一页",Vector2(461,786),Vector2(205,47),func() -> void: _turn_page(-1))
	next_button=_button("下一页 ›",Vector2(934,786),Vector2(205,47),func() -> void: _turn_page(1))
	page_label=_words("",Vector2(702,792),Vector2(196,35),21)
	page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_refresh_page()

func _words(text: String, at: Vector2, extent: Vector2, point: int) -> Label:
	var label := Label.new(); label.text=LocalizationSystem.text(text)
	label.position=at; label.size=extent
	label.add_theme_font_size_override("font_size",point); label.add_theme_color_override("font_color",STYLE.INK)
	label.mouse_filter=MOUSE_FILTER_IGNORE; add_child(label)
	return label

func _button(text: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var button := Button.new(); button.text=LocalizationSystem.text(text); button.position=at; button.size=extent
	button.pressed.connect(action); add_child(button)
	return button

func _turn_page(direction: int) -> void:
	if is_instance_valid(inscription): return
	page=clampi(page+direction,0,maxi(0,ceili(float(photos.size())/PAGE_SIZE)-1))
	WorldSound.play_ui("paper")
	_refresh_page()

func _refresh_page() -> void:
	prints.clear()
	for grid in grids:
		for child in grid.get_children(): grid.remove_child(child); child.queue_free()
	var pages := maxi(1,ceili(float(photos.size())/PAGE_SIZE))
	page_label.text="%d / %d" % [page+1,pages]
	previous_button.disabled=page==0; next_button.disabled=page>=pages-1
	if photos.is_empty():
		status.text=LocalizationSystem.text("相册还空着。拍一张照片，冲洗后带回来吧。")
		return
	for index in range(page*PAGE_SIZE,mini(photos.size(),(page+1)*PAGE_SIZE)):
		_add_photo_card(grids[(index%PAGE_SIZE)/4],photos[index])

func _add_photo_card(grid: GridContainer, item: Dictionary) -> void:
	var full := library.load_photo(str(item.get("photo_id","")))
	if full==null: return
	var card := VBoxContainer.new(); card.custom_minimum_size=Vector2(298,245)
	card.size_flags_horizontal=SIZE_EXPAND_FILL; card.add_theme_constant_override("separation",6); grid.add_child(card)
	var view := preload("res://scripts/photography/photo_print.gd").new()
	view.image=full; view.metadata=item; view.fit_height=true
	view.custom_minimum_size=Vector2(298,221); view.size_flags_horizontal=SIZE_EXPAND_FILL
	view.mouse_default_cursor_shape=CURSOR_POINTING_HAND
	view.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: _activate_photo(item))
	card.add_child(view); prints[str(item.photo_id)]=view
	var action := Button.new(); action.text=LocalizationSystem.text("用作唱片封面" if selection_mode else "翻看 · 写字")
	action.custom_minimum_size.y=34; action.add_theme_font_size_override("font_size",16)
	action.pressed.connect(func() -> void: _activate_photo(item)); card.add_child(action)

func _activate_photo(item: Dictionary) -> void:
	if is_instance_valid(inscription): return
	var selected_image := library.load_photo(str(item.get("photo_id","")))
	if selected_image==null: status.text=LocalizationSystem.text(library.last_error); return
	if selection_mode:
		photo_selected.emit(selected_image,item); queue_free(); return
	inscription=preload("res://scripts/photography/photo_inscription.gd").new()
	inscription.image=selected_image; inscription.metadata=item; inscription.library=library
	inscription.saved.connect(func(note: String) -> void:
		item["notes"]=note
		var view: Control=prints.get(str(item.photo_id))
		if is_instance_valid(view): view.note_label.text=note)
	inscription.closed.connect(func() -> void: inscription=null)
	add_child(inscription)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(inscription): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel"): queue_free()
		elif event.is_action_pressed("ui_left"): _turn_page(-1)
		elif event.is_action_pressed("ui_right"): _turn_page(1)
		else: return
		get_viewport().set_input_as_handled()
