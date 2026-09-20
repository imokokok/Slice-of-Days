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
var item_list: GridContainer
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
	shade.color=Color("234d68",.18); shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(shade)
	var panel := Panel.new()
	panel.name="ShopCounter"; panel.position=Vector2(120,85); panel.size=Vector2(1360,735)
	var style := StyleBoxFlat.new(); style.bg_color=Color("faf7ee"); style.border_color=Color("31658b",.35); style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel",style); add_child(panel)
	_label(panel,str(shop.get("name","小镇货架")),Vector2(45,24),Vector2(850,55),32,SEA)
	_label(panel,"挑一件，带进今天的生活。",Vector2(45,87),Vector2(830,34),22,MUTED)
	var receipt := Panel.new(); receipt.position=Vector2(990,95); receipt.size=Vector2(325,535); receipt.rotation=.012; panel.add_child(receipt)
	_label(receipt,"S O L M E R E",Vector2(22,20),Vector2(280,35),22,SEA)
	_label(receipt,"小票 / Receipt",Vector2(22,65),Vector2(280,32),21,SEA)
	balance_label=_label(receipt,"",Vector2(22,125),Vector2(280,40),24,SEA)
	budget_label=_label(receipt,"",Vector2(22,175),Vector2(280,55),17,MUTED)
	status_label=_label(receipt,"",Vector2(22,250),Vector2(280,235),21,SEA)
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new(); scroll.position=Vector2(40,150); scroll.size=Vector2(910,520)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
	item_list=GridContainer.new(); item_list.columns=3; item_list.add_theme_constant_override("h_separation",20); item_list.add_theme_constant_override("v_separation",20); scroll.add_child(item_list)
	var close := _button(panel,"收起 · Esc",Vector2(1110,665),Vector2(200,42),false); close.pressed.connect(queue_free)
	if shop_id=="grocery":
		var photo := _button(panel,"摄影与冲洗",Vector2(45,670),Vector2(250,40),false)
		photo.pressed.connect(func() -> void: FilmSystem.open_counter(get_parent()); queue_free())


func _refresh() -> void:
	balance_label.text="钱包里 · %d 元" % GameState.money
	budget_label.text="Day %02d · 购买后小票会收进生活材料。" % GameState.current_day
	budget_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for child in item_list.get_children(): item_list.remove_child(child); child.queue_free()
	for raw in EconomySystem.stock(shop_id):
		var item: Dictionary = raw.duplicate(true)
		var card := Control.new(); card.custom_minimum_size=Vector2(278,237); item_list.add_child(card)
		var sketch := preload("res://scripts/ui/goods_sketch.gd").new(); sketch.item_id=str(item.id); sketch.position=Vector2(80,0); sketch.size=Vector2(115,95); card.add_child(sketch)
		_label(card,str(item.get("name","物件")),Vector2(8,97),Vector2(262,33),22,SEA,HORIZONTAL_ALIGNMENT_CENTER)
		var description := _label(card,str(item.get("description","")),Vector2(12,136),Vector2(254,51),16,MUTED)
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var buy := _button(card,"%d 元 · 带上它" % int(item.price),Vector2(16,193),Vector2(246,38),true)
		buy.name="Buy_"+str(item.id)
		buy.disabled=GameState.money<int(item.price) or int(item.remaining)<=0 or not EconomySystem.shop_open(shop_id)
		buy.pressed.connect(_buy.bind(item))
	status_label.text="小票留在这里。\n\n买下的东西会放进随身包。"


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
	var receipt: Dictionary = result.get("receipt",{})
	status_label.text="%s\n× 1      %d 元\n\n实付  %d 元\n\n小票已收好。" % [str(item.get("name",item.id)),int(item.price),int(receipt.get("total",item.price))]


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
