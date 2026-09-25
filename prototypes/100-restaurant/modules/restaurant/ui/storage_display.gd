extends Control

signal ingredient_chosen(definition: Dictionary, press_position: Vector2)

const FoodArt = preload("res://modules/restaurant/assets/food_art.gd")
const ROOM = preload("res://modules/restaurant/assets/kitchen_reference_no_recipe_stand.png")
const FRIDGE: = Rect2(30, 175, 330, 360)
const SHELVES: = Rect2(390, 421, 840, 114)
const BASKETS: = Rect2(1260, 155, 326, 635)
const COLD_IDS: = ["egg", "shrimp", "fish", "salmon", "squid", "mussel", "chicken", "pork", "beef", "sausage", "milk", "yogurt", "butter", "cheese", "ice_cream", "tofu"]
const AMBIENT_IDS: = ["noodles", "bread", "seaweed", "potato", "onion", "mushroom", "corn", "pumpkin", "lotus_root", "bean_sprout", "cabbage", "broccoli", "eggplant"]
const FRIDGE_PAGE_SIZE := 15
const FEATURED_FOODS_FIRST := ["tomato", "potato", "carrot", "onion", "eggplant", "bell_pepper_yellow", "zucchini", "bell_pepper_lavender", "bell_pepper_gold", "bell_pepper_purple", "bell_pepper_brown", "bell_pepper_white", "bell_pepper_orange", "bell_pepper_green", "mushroom", "egg", "noodles", "bread"]

var definitions: Array = []
var sections: Dictionary = {"fridge": [], "shelves": [], "baskets": []}
var section_counts: Dictionary = {"fridge": 0, "shelves": 0, "baskets": 0}
var fridge_open: = true:
	set(value):
		fridge_open = value
		if is_instance_valid(_fridge_items):
			_fridge_items.visible = fridge_open
		if is_instance_valid(_fridge_toggle):
			_fridge_toggle.text = "冷藏柜  ·  打开" if not fridge_open else "冷藏柜  ·  已打开"
		queue_redraw()

var _fridge_items: Control
var _fridge_toggle: Button
var _content: Control
var stock: Dictionary = {}
var fridge_page := 0
var fridge_scroll_row := 0
var odd_page := 0
var _cold_catalog: Array = []
var _odd_catalog: Array = []

func set_available(id: String, available: bool) -> void:
	stock[id] = available
	var button := find_child("Ingredient_" + id, true, false) as Button
	if button == null: return
	button.disabled = not available
	button.mouse_filter = Control.MOUSE_FILTER_STOP if available else Control.MOUSE_FILTER_IGNORE
	button.get_node("FoodArt").visible = available
	button.get_node("IngredientName").text = str(button.get_meta("definition").name) if available else "空位"
	queue_redraw()

func slot_at(id: String, point: Vector2) -> bool:
	var button := find_child("Ingredient_" + id, true, false) as Button
	return button != null and button.is_visible_in_tree() and button.get_global_rect().has_point(point)

func reveal_ingredient(id: String) -> void:
	# Opening the full cupboard also reveals the item's physical return slot.
	for section in ["fridge", "odd"]:
		var items: Array = _cold_catalog if section == "fridge" else _odd_catalog
		for index in items.size():
			if str(items[index].id) != id: continue
			if section == "fridge":
				var page := 0 if index < FEATURED_FOODS_FIRST.size() else 1 + (index - FEATURED_FOODS_FIRST.size()) / FRIDGE_PAGE_SIZE
				var scroll_row := 1 if page == 0 and index >= FRIDGE_PAGE_SIZE else 0
				if fridge_page == page and (page != 0 or index >= fridge_scroll_row * 3 and index < fridge_scroll_row * 3 + FRIDGE_PAGE_SIZE): return
				fridge_page = page
				fridge_scroll_row = scroll_row
			else:
				var page := index / 12
				if odd_page == page: return
				odd_page = page
			_build_items()
			return

func _turn_page(section: String, step: int) -> void:
	if section == "fridge":
		fridge_page = posmod(fridge_page + step, _fridge_page_count())
		fridge_scroll_row = 0
	else:
		odd_page = posmod(odd_page + step, maxi(1, ceili(_odd_catalog.size() / 12.0)))
	_build_items()

func _fridge_page_count() -> int:
	return 1 + ceili(float(maxi(0, _cold_catalog.size() - FEATURED_FOODS_FIRST.size())) / FRIDGE_PAGE_SIZE)

func _fridge_page_start() -> int:
	if fridge_page == 0: return fridge_scroll_row * 3
	return FEATURED_FOODS_FIRST.size() + (fridge_page - 1) * FRIDGE_PAGE_SIZE

func _scroll_fridge(step: int) -> void:
	if fridge_page != 0: return
	var max_row := maxi(0, ceili(float(FEATURED_FOODS_FIRST.size() - FRIDGE_PAGE_SIZE) / 3.0))
	fridge_scroll_row = clampi(fridge_scroll_row + step, 0, max_row)
	_build_items()

func _fridge_scroll_controls() -> void:
	if fridge_page != 0 or FEATURED_FOODS_FIRST.size() <= FRIDGE_PAGE_SIZE: return
	_heading("原画", Vector2(345, 289), Vector2(38, 19), Color("554738"), 12)
	for direction in [-1, 1]:
		var button := Button.new()
		button.name = "FridgeScrollUp" if direction < 0 else "FridgeScrollDown"
		button.text = "⌃" if direction < 0 else "⌄"
		button.tooltip_text = "冰箱第一页向上滚动" if direction < 0 else "冰箱第一页向下滚动"
		button.position = Vector2(348, 310 if direction < 0 else 342)
		button.size = Vector2(30, 27)
		button.disabled = fridge_scroll_row == 0 if direction < 0 else fridge_scroll_row >= ceili(float(FEATURED_FOODS_FIRST.size() - FRIDGE_PAGE_SIZE) / 3.0)
		_compact_sign(button)
		button.pressed.connect(_scroll_fridge.bind(direction))
		_content.add_child(button)

func _page_controls(section: String, location: Vector2, width: float, page: int, count: int) -> void:
	if count <= 1: return
	if section == "fridge":
		# The fridge's side rail holds the page tabs. Below the cabinet is the
		# sink; controls there would be crossed by the physical faucet stream.
		_heading("%d/%d" % [page + 1, count], Vector2(340, 411), Vector2(48, 24), Color("554738"), 13)
		location = Vector2(348, 378)
		width = 30
	else:
		_heading("%d / %d" % [page + 1, count], location + Vector2(42, 3), Vector2(width - 84, 24), Color("fff0d5"), 16)
	for direction in [-1, 1]:
		var button := Button.new()
		button.name = section.capitalize() + ("PreviousPage" if direction < 0 else "NextPage")
		button.text = "‹" if direction < 0 else "›"
		button.tooltip_text = "上一层" if direction < 0 else "下一层"
		button.position = location + (Vector2(0, 0 if direction < 0 else 67) if section == "fridge" else Vector2(0 if direction < 0 else width - 34, 0))
		button.size = Vector2(30, 28) if section == "fridge" else Vector2(34, 28)
		_compact_sign(button)
		button.pressed.connect(_turn_page.bind(section, direction))
		_content.add_child(button)

func setup(defs: Array) -> void :
	definitions.clear()
	var seen: Dictionary = {}
	for value in defs:
		if not value is Dictionary or not value.get("id") is String or not value.get("name") is String:
			continue
		if seen.has(value.id):
			continue
		seen[value.id] = true
		definitions.append(value.duplicate(true))
	_organize()
	if is_node_ready():
		_build_items()
	queue_redraw()

func _ready() -> void :
	size = Vector2(1600, 900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_items()

func _organize() -> void :
	sections = {"fridge": [], "shelves": [], "baskets": []}
	var catalog: Dictionary = {}
	var used: Dictionary = {}
	for item in definitions:
		catalog[item.id] = item
	for id in COLD_IDS:
		if catalog.has(id):
			sections.fridge.append(catalog[id])
			used[id] = true
	for item in definitions:
		if item.get("category") == "seasoning" and not used.has(item.id):
			sections.shelves.append(item)
			used[item.id] = true
	for id in AMBIENT_IDS:
		if catalog.has(id) and not used.has(id) and sections.shelves.size() < 30:
			sections.shelves.append(catalog[id])
			used[id] = true

	for group in ["sweet", "basic", "odd", "seasoning"]:
		for item in definitions:
			if not used.has(item.id) and item.get("category") == group:
				sections.baskets.append(item)
				used[item.id] = true
	for item in definitions:
		if not used.has(item.id):
			sections.baskets.append(item)
	for key in sections:
		section_counts[key] = sections[key].size()

signal browse_requested
func _build_items() -> void :
	if is_instance_valid(_content):
		remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	var catalog: = {}
	for item in definitions: catalog[item.id] = item
	var cold: = FEATURED_FOODS_FIRST + ["shrimp", "tofu", "cheese", "broccoli", "lettuce", "milk", "pumpkin", "chicken"]
	_cold_catalog.clear()
	for id in cold:
		if catalog.has(id): _cold_catalog.append(catalog[id])
	for item in definitions:
		if item.get("category", "") in ["basic", "sweet"] and not cold.has(str(item.id)): _cold_catalog.append(item)
	var fridge_start := _fridge_page_start()
	var fridge_end := mini(FEATURED_FOODS_FIRST.size(), _cold_catalog.size()) if fridge_page == 0 else _cold_catalog.size()
	var fridge_count := maxi(0, mini(FRIDGE_PAGE_SIZE, fridge_end - fridge_start))
	for i in fridge_count:
		var shelf_row := i / 3
		var floor_y := 245.0 + shelf_row * 77.0
		_slot(_content, _cold_catalog[fridge_start + i], Vector2(51 + (i % 3) * 94, floor_y - 69.0), Vector2(90, 69), 0.76, Color("344854"), "fridge")
	for row in 5:
		_surface_front(_content, Rect2(51, 245 + row * 77, 281, 12))
	_fridge_scroll_controls()
	_page_controls("fridge", Vector2(66, 563), 244, fridge_page, _fridge_page_count())
	var counter: = ["ketchup", "mayonnaise", "mustard", "chili_sauce", "vinegar"]
	for i in counter.size():
		if catalog.has(counter[i]): _slot(_content, catalog[counter[i]], Vector2(688 + i * 77, 495), Vector2(75, 92), preload("res://modules/restaurant/assets/sprite_library.gd").physical_art_scale(counter[i]), Color("fff0d5"), "rack")
	# The authored room already has the rack's front board. Repainting it in
	# the HUD placed that rear board in front of the skillet's upper rim.
	# Separate condiment rack at the exact left-hand position in the source.
	for spec in [["oil", 364.0], ["pepper", 415.0], ["salt", 460.0], ["sugar", 497.0], ["soy_sauce", 534.0]]:
		if catalog.has(spec[0]):
			_counter_slot(catalog[spec[0]], spec[1])
			# The crowded left rack uses hover labels rather than painting text over bottles.
			_content.get_node("Ingredient_" + spec[0] + "/IngredientName").hide()
	var odd: = []
	for id in ["sock", "confetti", "toilet_paper", "soap", "soap_smooth", "toothpaste", "resignation_letter", "alarm_clock", "yarn_ball", "tennis_ball", "dentures", "eraser", "sponge", "baseball_bat", "computer_mouse", "slipper", "rubber_duck", "rock"]:
		if catalog.has(id): odd.append(catalog[id])
	for item in definitions:
		if item.get("category", "") == "odd" and not odd.has(item): odd.append(item)
	_odd_catalog = odd
	var odd_count := mini(odd.size() - odd_page * 12, 12)
	for i in odd_count:
		var shelf_row := (2 - i / 4) if odd_count < 12 else i / 4
		var floor_y := 300.0 + shelf_row * 105.0
		_slot(_content, odd[odd_page * 12 + i], Vector2(1326 + (i % 4) * 67, floor_y - 75.0), Vector2(64, 75), 0.70, Color("fff0d5"), "odd")
	for row in 3:
		_surface_front(_content, Rect2(1320, 300 + row * 105, 274, 20))
	_page_controls("odd", Vector2(1340, 518), 242, odd_page, ceili(odd.size() / 12.0))
	var browse: = Button.new()
	browse.name = "BrowseIngredientCupboard"
	browse.text = ""
	browse.tooltip_text = "打开全部食材"
	browse.position = Vector2(64, 122)
	browse.size = Vector2(228, 34)
	_transparent_button(browse)
	browse.pressed.connect( func(): browse_requested.emit())
	_content.add_child(browse)
	for id in stock: set_available(id, bool(stock[id]))
	queue_redraw()

func _surface_front(parent: Control, region: Rect2) -> void:
	var front := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = ROOM
	atlas.region = Rect2(region.position * Vector2(ROOM.get_size()) / Vector2(1600, 900), region.size * Vector2(ROOM.get_size()) / Vector2(1600, 900))
	front.texture = atlas
	front.position = region.position
	front.size = region.size
	front.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	front.stretch_mode = TextureRect.STRETCH_SCALE
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(front)

func _counter_slot(item: Dictionary, center_x: float) -> void:
	var art_library = preload("res://modules/restaurant/assets/sprite_library.gd")
	var scale: float = art_library.physical_art_scale(str(item.id))
	var texture: Texture2D = art_library.food(str(item.id))
	var footprint := Vector2(78, 78)
	if texture != null: footprint = art_library.fit(texture, Vector2.ZERO, Vector2(78, 78)).size
	footprint *= scale
	var dimensions := Vector2(maxf(footprint.x + 6.0, 24.0), footprint.y + 9.0)
	_slot(_content, item, Vector2(center_x - dimensions.x * 0.5, 612.0 - dimensions.y), dimensions, scale, Color("493b2d"), "counter")

func _compact_sign(button: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var paper := StyleBoxFlat.new()
		paper.bg_color = Color("f1d5a5") if state == "normal" else Color("ffe7b8")
		paper.set_content_margin_all(5)
		button.add_theme_stylebox_override(state, paper)
	button.add_theme_font_size_override("font_size", 16)

func _heading(words: String, location: Vector2, dimensions: Vector2, color: Color, font_size: int) -> void :
	var label: = Label.new()
	label.text = words
	label.position = location
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(label)

func _slot(parent: Control, item: Dictionary, location: Vector2, dimensions: Vector2, icon_scale: float, name_color: Color, surface: String = "") -> void :
	var button: = Button.new()
	button.name = "Ingredient_" + str(item.id)
	button.position = location
	button.size = dimensions
	button.set_meta("ingredient_id", item.id)
	button.set_meta("definition", item.duplicate(true))
	button.set_meta("display_surface", surface)
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.tooltip_text = "%s\n按住即可拖出；也可单击拿起，再点击放下\n调料容器拿到锅上方，按住左键出料\n重量：%d 克%s" % [item.name, roundi(float(item.get("mass", 0.1)) * 1000), " · 需要加热" if item.get("needs_cook", false) else ""]
	_transparent_button(button)
	# Use the actual press event, not the OS cursor's later position. A quick
	# drag can enqueue press/motion/release before the next game frame.
	button.gui_input.connect(func(event: InputEvent):
		if not button.disabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Consume before hiding/disabling the emptied slot. Otherwise this same
			# press falls through to the kitchen and immediately puts the item back.
			button.accept_event()
			ingredient_chosen.emit(item.duplicate(true), button.get_global_transform_with_canvas() * event.position))
	parent.add_child(button)
	var label_height: = 19.0
	var icon_center := Vector2(dimensions.x * 0.5, (dimensions.y - label_height) * 0.47)
	if surface in ["fridge", "odd", "rack"]:
		var library = preload("res://modules/restaurant/assets/sprite_library.gd")
		var texture: Texture2D = library.food(str(item.id))
		var art_rect: Rect2 = library.fit(texture, Vector2.ZERO, Vector2(78, 78)) if texture != null else Rect2(-39, -39, 78, 78)
		icon_center.y = (586.0 - location.y if surface == "rack" else dimensions.y - 4.0) - art_rect.end.y * icon_scale
	if surface == "counter": icon_center = Vector2(dimensions.x * 0.5, dimensions.y - 4.0 - (dimensions.y - 9.0) * 0.5)
	var art: = FoodArt.new()
	art.name = "FoodArt"
	art.definition = item.duplicate(true)
	art.position = icon_center
	art.scale = Vector2.ONE * icon_scale
	art.shadows = true
	button.add_child(art)
	var label: = Label.new()
	label.name = "IngredientName"
	label.text = item.name
	label.position = Vector2(0, dimensions.y - 4.0 if surface in ["fridge", "odd"] else (dimensions.y + 4.0 if surface == "rack" else dimensions.y - label_height))
	label.size = Vector2(dimensions.x, label_height)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14 if surface in ["fridge", "odd"] else 12)
	label.add_theme_color_override("font_color", name_color)
	if surface in ["fridge", "odd"]:
		label.add_theme_color_override("font_outline_color", Color("f7eed8") if surface == "fridge" else Color("302820"))
		label.add_theme_constant_override("outline_size", 2)
	if surface in ["fridge", "rack", "odd"]: label.z_index = 1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

func _transparent_button(button: Button, _header: bool = false) -> void :
	var normal: = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("disabled", normal)
	var hover: = StyleBoxFlat.new()
	hover.bg_color = Color.TRANSPARENT
	hover.border_color = Color("8b7d62")
	hover.set_border_width_all(0)
	hover.set_corner_radius_all(0)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: = hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color.TRANSPARENT
	button.add_theme_stylebox_override("pressed", pressed)
	var focus: = StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("453f35")
	focus.set_border_width_all(0)
	focus.set_corner_radius_all(0)
	button.add_theme_stylebox_override("focus", focus)

func _panel(rect: Rect2, color: Color, edge: Color, _radius: int = 0, _width: int = 1) -> void :
	var style: = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	draw_style_box(style, rect)

func _draw() -> void :
	# Small contact shadows connect the separate art nodes to the shelf floor.
	if not is_instance_valid(_content): return
	for slot in _content.get_children():
		if not slot is Button or slot.disabled or not slot.has_meta("display_surface"): continue
		var surface: String = slot.get_meta("display_surface")
		if surface not in ["fridge", "rack", "odd", "counter"]: continue
		var button := slot as Button
		var center: float = button.position.x + button.size.x * 0.5
		var floor_y: float = button.position.y + (button.size.y - 3.0 if surface in ["fridge", "odd", "counter"] else 63.0)
		var radius: float = 25.0 if surface == "fridge" else (19.0 if surface == "odd" else 16.0)
		var points := PackedVector2Array()
		for step in 16:
			var angle := TAU * step / 16.0
			points.append(Vector2(center + cos(angle) * radius, floor_y + sin(angle) * 3.0))
		draw_colored_polygon(points, Color("172c38", 0.20) if surface == "fridge" else Color("2d2019", 0.28))
