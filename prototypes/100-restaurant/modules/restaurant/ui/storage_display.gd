extends Control

signal ingredient_chosen(definition: Dictionary, press_position: Vector2)
signal mystery_requested

const FoodArt = preload("res://modules/restaurant/assets/food_art.gd")
const FRIDGE: = Rect2(30, 175, 330, 360)
const SHELVES: = Rect2(390, 421, 840, 114)
const BASKETS: = Rect2(1260, 155, 326, 635)
const COLD_IDS: = ["egg", "shrimp", "fish", "salmon", "squid", "mussel", "chicken", "pork", "beef", "sausage", "milk", "yogurt", "butter", "cheese", "ice_cream", "tofu"]
const AMBIENT_IDS: = ["rice", "noodles", "bread", "seaweed", "potato", "onion", "mushroom", "corn", "pumpkin", "lotus_root", "bean_sprout", "cabbage", "broccoli", "eggplant"]

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

func slot_at(id: String, point: Vector2) -> bool:
	var button := find_child("Ingredient_" + id, true, false) as Button
	return button != null and button.is_visible_in_tree() and button.get_global_rect().has_point(point)

func reveal_ingredient(id: String) -> void:
	# Opening the full cupboard also reveals the item's physical return slot.
	for section in ["fridge", "odd"]:
		var items: Array = _cold_catalog if section == "fridge" else _odd_catalog
		var page_size := 15 if section == "fridge" else 12
		for index in items.size():
			if str(items[index].id) != id: continue
			var page := index / page_size
			if section == "fridge":
				if fridge_page == page: return
				fridge_page = page
			else:
				if odd_page == page: return
				odd_page = page
			_build_items()
			return

func _turn_page(section: String, step: int) -> void:
	if section == "fridge":
		fridge_page = posmod(fridge_page + step, maxi(1, ceili(_cold_catalog.size() / 15.0)))
	else:
		odd_page = posmod(odd_page + step, maxi(1, ceili(_odd_catalog.size() / 12.0)))
	_build_items()

func _page_controls(section: String, location: Vector2, width: float, page: int, count: int) -> void:
	if count <= 1: return
	_heading("%d / %d" % [page + 1, count], location + Vector2(42, 3), Vector2(width - 84, 24), Color("fff0d5"), 16)
	for direction in [-1, 1]:
		var button := Button.new()
		button.name = section.capitalize() + ("PreviousPage" if direction < 0 else "NextPage")
		button.text = "‹" if direction < 0 else "›"
		button.tooltip_text = "上一层" if direction < 0 else "下一层"
		button.position = location + Vector2(0 if direction < 0 else width - 34, 0)
		button.size = Vector2(34, 28)
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
	var cold: = ["tomato", "egg", "mushroom", "shrimp", "tofu", "cheese", "carrot", "onion", "broccoli", "lettuce", "milk", "pumpkin", "chicken", "potato", "rice"]
	_cold_catalog.clear()
	for id in cold:
		if catalog.has(id): _cold_catalog.append(catalog[id])
	for item in definitions:
		if item.get("category", "") in ["basic", "sweet"] and not cold.has(str(item.id)): _cold_catalog.append(item)
	for i in mini(15, _cold_catalog.size() - fridge_page * 15):
		_slot(_content, _cold_catalog[fridge_page * 15 + i], Vector2(45 + (i % 3) * 96, 181 + (i / 3) * 77), Vector2(90, 70), 0.76, Color("344854"))
	_page_controls("fridge", Vector2(66, 563), 244, fridge_page, ceili(_cold_catalog.size() / 15.0))
	var counter: = ["ketchup", "mayonnaise", "mustard", "chili_sauce", "vinegar"]
	for i in counter.size():
		if catalog.has(counter[i]): _slot(_content, catalog[counter[i]], Vector2(670 + i * 80, 549), Vector2(75, 66), preload("res://modules/restaurant/assets/sprite_library.gd").physical_art_scale(counter[i]), Color("493b2d"))
	# Separate condiment rack at the exact left-hand position in the source.
	for spec in [["oil", Vector2(367, 458), Vector2(64, 167), 1.85], ["pepper", Vector2(436, 491), Vector2(56, 125), 1.25], ["salt", Vector2(441, 572), Vector2(34, 51), 0.54], ["sugar", Vector2(480, 559), Vector2(38, 64), 0.65], ["soy_sauce", Vector2(513, 541), Vector2(30, 76), 0.68]]:
		if catalog.has(spec[0]):
			_slot(_content, catalog[spec[0]], spec[1], spec[2], preload("res://modules/restaurant/assets/sprite_library.gd").physical_art_scale(spec[0]), Color("493b2d"))
			# Narrow overlapping rack bottles are identified by their hover label.
			_content.get_node("Ingredient_" + spec[0] + "/IngredientName").hide()
	var odd: = []
	for id in ["sock", "confetti", "toilet_paper", "soap", "soap_smooth", "toothpaste", "resignation_letter", "alarm_clock", "yarn_ball", "tennis_ball", "dentures", "eraser", "sponge", "baseball_bat", "computer_mouse", "slipper", "rubber_duck", "rock"]:
		if catalog.has(id): odd.append(catalog[id])
	for item in definitions:
		if item.get("category", "") == "odd" and not odd.has(item): odd.append(item)
	_odd_catalog = odd
	for i in mini(odd.size() - odd_page * 12, 12):
		_slot(_content, odd[odd_page * 12 + i], Vector2(1325 + (i % 4) * 67, 224 + (i / 4) * 105), Vector2(65, 78), 0.70, Color("fff0d5"))
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
	var mystery: = Button.new()
	mystery.name = "MysteryStock"
	mystery.text = "?  奇物箱 · 拿一件"
	mystery.position = Vector2(1340, 550)
	mystery.size = Vector2(242, 33)
	_compact_sign(mystery)
	mystery.add_theme_font_size_override("font_size", 16)
	mystery.pressed.connect( func(): mystery_requested.emit())
	_content.add_child(mystery)
	for id in stock: set_available(id, bool(stock[id]))
	queue_redraw()

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

func _slot(parent: Control, item: Dictionary, location: Vector2, dimensions: Vector2, icon_scale: float, name_color: Color) -> void :
	var button: = Button.new()
	button.name = "Ingredient_" + str(item.id)
	button.position = location
	button.size = dimensions
	button.set_meta("ingredient_id", item.id)
	button.set_meta("definition", item.duplicate(true))
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
	var label_height: = 16.0
	var icon_center: = Vector2(dimensions.x * 0.5, (dimensions.y - label_height) * 0.47)
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
	label.position = Vector2(0, dimensions.y - label_height)
	label.size = Vector2(dimensions.x, label_height)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", name_color)
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
	# Both wooden holders are already drawn in the approved image.
	pass
