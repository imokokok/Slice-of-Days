extends Control

const CATALOG_PATH := "res://data/economy/shops.json"
const PAPER := Color("fff5df")
const INK := Color("382e29")
const MUTED := Color("75685e")
const TERRACOTTA := Color("bd6248")
const SEA := Color("537982")

var shop_id := ""
var shop: Dictionary = {}
var balance_label: Label
var budget_label: Label
var status_label: Label
var item_list: VBoxContainer
var buying := false
var last_purchase_msec := -1000


func _ready() -> void:
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_shop()
	_build_ui()
	_refresh()


func _load_shop() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not parsed is Dictionary:
		return
	for raw in parsed.get("shops", []):
		if raw is Dictionary and str(raw.get("id", "")) == shop_id:
			shop = (raw as Dictionary).duplicate(true)
			return


func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(330, 105)
	panel.size = Vector2(940, 690)
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = SEA
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 14
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var title := _label(panel, str(shop.get("name", "小镇商店")), Vector2(32, 24), Vector2(570, 45), 29, INK)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	balance_label = _label(panel, "", Vector2(620, 30), Vector2(275, 35), 21, TERRACOTTA, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(panel, "按标价结算 · 食材进入随身物品 · 每笔保留小票", Vector2(34, 75), Vector2(750, 30), 16, MUTED)
	budget_label = _label(panel, "", Vector2(34, 108), Vector2(870, 28), 17, SEA)
	var close := _button(panel, "收起  Esc", Vector2(744, 622), Vector2(160, 44), false)
	close.pressed.connect(queue_free)
	if shop_id == "grocery":
		var photo := _button(panel, "摄影与冲洗", Vector2(744, 567), Vector2(160, 44), false)
		photo.pressed.connect(func() -> void: FilmSystem.open_counter(get_parent()); queue_free())
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(32, 150)
	scroll.size = Vector2(876, 400)
	panel.add_child(scroll)
	item_list = VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.add_theme_constant_override("separation", 10)
	scroll.add_child(item_list)
	status_label = _label(panel, "", Vector2(34, 568), Vector2(680, 90), 17, SEA)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _refresh() -> void:
	if balance_label == null:
		return
	balance_label.text = LocalizationSystem.text("钱包  %d 元" % GameState.money)
	budget_label.text = GameState.spending_plan_text()
	budget_label.add_theme_color_override("font_color", TERRACOTTA if int(GameState.daily_spending_plan().over) > 0 else SEA)
	for child in item_list.get_children():
		item_list.remove_child(child)
		child.queue_free()
	if shop.is_empty():
		status_label.text = LocalizationSystem.text("摊位数据没有加载成功。")
		return
	for raw in EconomySystem.stock(shop_id):
		var item: Dictionary = raw.duplicate(true)
		item["shop_name"] = str(shop.get("name", "小镇商店"))
		var count := int(GameState.inventory.get(str(item.get("id", "")), 0))
		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color("f5e8ce")
		row_style.set_corner_radius_all(10)
		row_style.content_margin_left = 16
		row_style.content_margin_right = 16
		row_style.content_margin_top = 10
		row_style.content_margin_bottom = 10
		row.add_theme_stylebox_override("panel", row_style)
		item_list.add_child(row)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		row.add_child(line)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(copy)
		var name := Label.new()
		name.text = LocalizationSystem.text("%s  ·  %d元%s" % [str(item.get("name", "商品")), int(item.get("price", 0)), "  ·  已有%d" % count if count > 0 else ""])
		if str(item.get("category", "")) == "collection": name.text += "  ·  今日余%d件" % int(item.remaining)
		name.add_theme_font_size_override("font_size", 20)
		name.add_theme_color_override("font_color", INK)
		copy.add_child(name)
		var description := Label.new()
		description.text = LocalizationSystem.text(str(item.get("description", "")))
		description.add_theme_font_size_override("font_size", 15)
		description.add_theme_color_override("font_color", MUTED)
		copy.add_child(description)
		var buy := _button(line, "买一个", Vector2.ZERO, Vector2(130, 54), true)
		buy.disabled = GameState.money < int(item.get("price", 0)) or int(item.remaining) <= 0 or not EconomySystem.shop_open(shop_id)
		buy.pressed.connect(_buy.bind(item))
		if GameState.current_role == "A" and str(item.get("category", "")) == "collection":
			MetaExperience.queue_important("a_odd_collection", {"item_id":str(item.id)})
	status_label.text = LocalizationSystem.text("买到的食材会进入随身物品；在饭店选中同名材料完成出餐时会优先消耗。")


func _buy(item: Dictionary) -> void:
	if buying or Time.get_ticks_msec() - last_purchase_msec < 350: return
	buying = true
	var result := EconomySystem.purchase(shop_id, str(item.id))
	if not bool(result.get("ok", false)):
		buying = false
		WorldSound.play_ui("error")
		_refresh()
		status_label.text = LocalizationSystem.text(str(result.get("message", "这次没能买下。")))
		return
	WorldSound.play_ui("coin")
	last_purchase_msec = Time.get_ticks_msec()
	buying = false
	_refresh()
	status_label.text = LocalizationSystem.text(str(result.get("message", "")))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()


func _label(parent: Node, value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = LocalizationSystem.text(value)
	label.position = at
	label.size = label_size
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, value: String, at: Vector2, button_size: Vector2, primary: bool) -> Button:
	var button := Button.new()
	button.text = LocalizationSystem.text(value)
	button.position = at
	button.size = button_size
	button.custom_minimum_size = button_size
	button.add_theme_font_size_override("font_size", 17)
	var style := StyleBoxFlat.new()
	style.bg_color = TERRACOTTA if primary else Color("e8d8bc")
	style.set_corner_radius_all(9)
	button.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.08)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", PAPER if primary else INK)
	button.add_theme_color_override("font_hover_color", PAPER if primary else INK)
	parent.add_child(button)
	return button
