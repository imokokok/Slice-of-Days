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
var selected_item: Dictionary = {}
var selection_panel: Control
var purchase_button: Button


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
	shade.color=Color("16334b",.45); shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(shade)
	var panel := Panel.new()
	panel.name="ShopCounter"; panel.position=Vector2(120,85); panel.size=Vector2(1360,735)
	var style := StyleBoxFlat.new(); style.bg_color=Color("edf3f4"); style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel",style); add_child(panel)
	_label(panel,str(shop.get("name","小镇货架")),Vector2(45,24),Vector2(850,55),32,SEA)
	_label(panel,"挑一件，带进今天的生活。",Vector2(45,87),Vector2(830,34),22,MUTED)
	selection_panel=Control.new(); selection_panel.position=Vector2(990,95); selection_panel.size=Vector2(325,535); panel.add_child(selection_panel)
	balance_label=_label(selection_panel,"",Vector2(0,0),Vector2(310,40),24,SEA)
	budget_label=_label(selection_panel,"",Vector2(0,51),Vector2(310,50),17,MUTED)
	status_label=_label(selection_panel,"",Vector2(0,120),Vector2(310,285),21,SEA)
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	purchase_button=_button(selection_panel,"选择一件物品",Vector2(0,432),Vector2(310,52),true)
	purchase_button.name="ConfirmPurchase"; purchase_button.disabled=true; purchase_button.pressed.connect(_confirm_purchase)
	var scroll := ScrollContainer.new(); scroll.position=Vector2(40,150); scroll.size=Vector2(910,520)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
	item_list=GridContainer.new(); item_list.columns=3; item_list.add_theme_constant_override("h_separation",20); item_list.add_theme_constant_override("v_separation",20); scroll.add_child(item_list)
	var close := _button(panel,"收起",Vector2(1110,665),Vector2(200,42),false); close.tooltip_text=SettingsSystem.binding_text("ui_cancel"); close.pressed.connect(queue_free)
	if shop_id=="grocery":
		var photo := _button(panel,"摄影与冲洗",Vector2(45,670),Vector2(250,40),false)
		photo.pressed.connect(func() -> void: FilmSystem.open_counter(get_parent()); queue_free())


func _refresh() -> void:
	balance_label.text="钱包里 · %d 元" % GameState.money
	budget_label.text="Day %02d · 购买后小票会收进生活材料。" % GameState.current_day
	if not GameState.spending_plan_text().is_empty(): budget_label.text=GameState.spending_plan_text()
	budget_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for child in item_list.get_children(): item_list.remove_child(child); child.queue_free()
	for raw in EconomySystem.stock(shop_id):
		var item: Dictionary = raw.duplicate(true)
		var card := preload("res://scripts/ui/components/solmere_button.gd").new(); card.variant="outlined"; card.custom_minimum_size=Vector2(278,237); item_list.add_child(card)
		card.name="Select_"+str(item.id); card.selected=str(selected_item.get("id",""))==str(item.id); card.pressed.connect(_select.bind(item))
		var sketch := preload("res://scripts/ui/goods_sketch.gd").new(); sketch.item_id=str(item.id); sketch.position=Vector2(80,0); sketch.size=Vector2(115,95); card.add_child(sketch)
		_label(card,str(item.get("name","物件")),Vector2(8,97),Vector2(262,33),22,SEA,HORIZONTAL_ALIGNMENT_CENTER)
		var description := _label(card,str(item.get("description","")),Vector2(12,136),Vector2(254,51),16,MUTED)
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		_label(card,"%d 元     ·     剩余 %d" % [int(item.price),int(item.remaining)],Vector2(16,195),Vector2(246,30),18,SEA,HORIZONTAL_ALIGNMENT_CENTER)
	status_label.text="看看货架，挑一件喜欢的。\n\n购买前可以在这里核对价格。" if EconomySystem.shop_open(shop_id) else "柜台暂时无人。可以先看看货架，下次再来。"
	if not selected_item.is_empty(): _show_selection()
	elif item_list.get_child_count()>0: item_list.get_child(0).grab_focus()

func _select(item: Dictionary) -> void:
	selected_item=item.duplicate(true)
	for card in item_list.get_children(): card.selected=card.name=="Select_"+str(item.id)
	_show_selection()

func _show_selection() -> void:
	for item in EconomySystem.stock(shop_id):
		if str(item.id)==str(selected_item.id): selected_item=item.duplicate(true); break
	var reason := ""
	if not EconomySystem.shop_open(shop_id): reason="店主现在不在柜台"
	elif int(selected_item.remaining)<=0: reason="今天已经售完"
	elif int(selected_item.price)>GameState.money: reason="钱包余额不足"
	status_label.text="%s\n\n%s\n\n单价  %d 元\n数量  1\n\n%s" % [str(selected_item.name),str(selected_item.get("description","")),int(selected_item.price),reason if not reason.is_empty() else "物品放进随身包，小票收入生活记录。"]
	purchase_button.text="购买 · %d 元" % int(selected_item.price)
	purchase_button.disabled=not reason.is_empty()
	purchase_button.tooltip_text=reason

func _confirm_purchase() -> void:
	if selected_item.is_empty() or buying: return
	var chosen := selected_item.duplicate(true)
	var confirm := preload("res://scripts/ui/components/confirm_sheet.gd").new()
	confirm.heading="带上"+str(chosen.name)+"？"
	confirm.description="数量 1\n合计 %d 元\n购买后钱包余 %d 元\n\n物品与小票都会收好。" % [int(chosen.price),GameState.money-int(chosen.price)]
	confirm.confirm_text="确认购买"
	confirm.accepted.connect(func() -> void: _buy(chosen); confirm.queue_free())
	add_child(confirm)


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
	status_label.text="%s\n× 1\n\n实付  %d 元\n\n物品已放入随身包。\n小票已收入生活记录。" % [str(item.get("name",item.id)),int(receipt.get("total",item.get("price",0)))]


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
	label.mouse_filter=MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, value: String, at: Vector2, button_size: Vector2, primary: bool) -> Button:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new()
	button.variant="outlined"; button.selected=primary
	button.text = LocalizationSystem.text(value)
	button.position = at
	button.size = button_size
	button.custom_minimum_size = button_size
	button.add_theme_font_size_override("font_size", 17)
	parent.add_child(button)
	return button
