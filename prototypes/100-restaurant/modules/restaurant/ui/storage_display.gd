extends Control

signal ingredient_chosen(definition: Dictionary)
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
	var cold: = ["tomato", "egg", "mushroom", "shrimp", "tofu", "cheese", "carrot", "onion", "broccoli", "lettuce", "milk", "pumpkin"]
	for i in cold.size():
		if catalog.has(cold[i]): _slot(_content, catalog[cold[i]], Vector2(35 + (i % 3) * 96, 205 + (i / 3) * 89), Vector2(90, 79), 0.72, Color("453f35"))
	var counter: = ["rice", "noodles", "chili", "oil", "ketchup", "salt", "pepper", "soy_sauce"]
	for i in counter.size():
		if catalog.has(counter[i]): _slot(_content, catalog[counter[i]], Vector2(414 + i * 101, 432), Vector2(94, 92), 0.78, Color("fff0bd"))
	var odd: = []
	for id in ["baseball_bat", "computer_mouse", "slipper", "perfume", "doll", "lipstick", "rubber_duck", "rock"]:
		if catalog.has(id): odd.append(catalog[id])
	for item in definitions:
		if item.get("category", "") == "odd" and not odd.has(item): odd.append(item)
	for i in mini(odd.size(), 16):
		_slot(_content, odd[i], Vector2(1325 + (i % 4) * 67, 214 + (i / 4) * 76), Vector2(65, 70), 0.61, Color("e5d2ae"))
	_heading("奇异食材", Vector2(1381, 160), Vector2(200, 35), Color("e5d2ae"), 22)
	var browse: = Button.new()
	browse.name = "BrowseIngredientCupboard"
	browse.text = "打开全部食材"
	browse.position = Vector2(72, 144)
	browse.size = Vector2(228, 34)
	browse.pressed.connect( func(): browse_requested.emit())
	_content.add_child(browse)
	var mystery: = Button.new()
	mystery.name = "MysteryStock"
	mystery.text = "?  奇物箱 · 拿一件"
	mystery.position = Vector2(1340, 529)
	mystery.size = Vector2(242, 33)
	mystery.add_theme_font_size_override("font_size", 16)
	mystery.pressed.connect( func(): mystery_requested.emit())
	_content.add_child(mystery)
	queue_redraw()

func _heading(words: String, location: Vector2, dimensions: Vector2, color: Color, font_size: int) -> void :
	var label: = Label.new()
	label.text = words
	label.position = location
	label.size = dimensions
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
	button.pressed.connect( func(): ingredient_chosen.emit(item.duplicate(true)))
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
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", name_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

func _transparent_button(button: Button, _header: bool = false) -> void :
	var normal: = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", normal)
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
	pass
