extends Control
const ART = preload("res://scripts/ui/components/handmade_assets.gd")
const P = preload("res://scripts/ui/components/interface_palette.gd")
const ITEM = preload("res://scripts/ui/components/handmade_item.gd")
var shop_id := "grocery"
var shop: Dictionary={}
var selected_item: Dictionary={}
var item_list: Control
var selection_panel: Control
var balance_label: Label
var budget_label: Label
var status_label: Label
var purchase_button: Button
var basket_button: Button
var right: Control
var mode := "shelf"
var buying := false
var last_purchase_msec := -1000
var receipt: Dictionary={}
func _ready() -> void:
	add_to_group("meta_modal"); set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme=P.theme_for_tools()
	shop=EconomySystem.catalog.get(shop_id,{})
	var backdrop := ColorRect.new(); backdrop.color=Color("f4f1e6"); backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT); add_child(backdrop)
	P.words(self,str(shop.get("name","小镇杂货")) ,Vector2(80,42),830,32)
	P.words(self,"挑些今天用得上的。",Vector2(82,91),580,19,P.MUTED)
	balance_label=P.words(self,"",Vector2(1090,54),310,22)
	budget_label=P.words(self,"",Vector2(780,112),690,17,P.MUTED)
	_btn(self,"收起 · "+SettingsSystem.binding_text("ui_cancel"),Vector2(1360,40),Vector2(175,48),queue_free)
	ART.picture(self,"crates" if shop_id=="produce_stall" else "shelf",Vector2(70,170),Vector2(845,590),true)
	item_list=Control.new(); item_list.position=Vector2(70,170); item_list.size=Vector2(845,590); add_child(item_list)
	right=Control.new(); right.position=Vector2(975,165); right.size=Vector2(550,645); add_child(right)
	selection_panel=right
	status_label=P.words(self,"点击货品看价签，再放进篮子。",Vector2(80,815),1080,20)
	_btn(self,"买过的东西 / 小票",Vector2(1180,815),Vector2(345,48),func(): mode="history"; _refresh_right())
	if shop_id=="grocery":
		_btn(self,"摄影 · 冲洗",Vector2(80,754),Vector2(235,44),func(): FilmSystem.open_counter(self))
	_refresh()
func _btn(parent: Node, text: String, at: Vector2, extent: Vector2, action: Callable) -> Button:
	var b := preload("res://scripts/ui/components/solmere_button.gd").new()
	b.text=LocalizationSystem.text(text); b.variant="quiet"; b.position=at; b.size=extent; b.pressed.connect(action); parent.add_child(b)
	return b
func _clear(node: Node) -> void:
	for child in node.get_children(): node.remove_child(child); child.queue_free()
func _refresh() -> void:
	balance_label.text=LocalizationSystem.text_with_values("钱包  %d 元", [GameState.money])
	budget_label.text=LocalizationSystem.text(GameState.spending_plan_text())
	var focused := ""
	var owner := get_viewport().gui_get_focus_owner()
	if is_instance_valid(owner): focused=str(owner.name)
	_clear(item_list)
	var stock := EconomySystem.stock(shop_id)
	for i in stock.size():
		var item: Dictionary=stock[i]
		var b := ITEM.new(); b.name="Select_"+str(item.id); b.item_id=item.id
		b.caption={"hotel_307_tag":"307 房牌","misprint_postcard":"海湾明信片","crooked_cup":"缺口杯"}.get(str(item.id),str(item.name)); b.size=Vector2(175,150)
		if shop_id=="produce_stall":
			b.position=Vector2(49+(i%3)*261,48) if i<3 else Vector2(343,334)
			b.size=Vector2(210,220) if i<3 else Vector2(210,175)
		else: b.position=Vector2(48+(i%4)*190+(22 if i%4==0 else 0),[55,205,330][i/4])
		b.selected=selected_item.get("id","")==item.id
		b.disabled=int(item.remaining)<=0
		b.pressed.connect(_select.bind(item)); item_list.add_child(b)
		if str(b.name)==focused: b.grab_focus()
	_refresh_right()
func _select(item: Dictionary) -> void:
	selected_item=item.duplicate(true); mode="shelf"; WorldSound.play_ui("paper"); _refresh()
func _refresh_right() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	var previous := str(owner.name) if is_instance_valid(owner) and right.is_ancestor_of(owner) else ""
	_clear(right)
	match mode:
		"basket": _basket()
		"history": _history()
		"receipt": _receipt()
		_: _tag()
	if not previous.is_empty():
		var replacement := right.find_child(previous,true,false) as Button
		if is_instance_valid(replacement) and not replacement.disabled: replacement.grab_focus()
	if get_viewport().gui_get_focus_owner()==null:
		for candidate in right.find_children("*","Button",true,false):
			if candidate.visible and not candidate.disabled: candidate.grab_focus(); break
func _tag() -> void:
	ART.picture(right,"tag",Vector2(0,5),Vector2(530,280),true)
	if selected_item.is_empty():
		P.words(right,"挑一件看看",Vector2(178,135),292,27)
		P.words(right,"价格写在这里。",Vector2(178,184),290,20,P.MUTED)
	else:
		var available := 0
		for item in EconomySystem.stock(shop_id):
			if item.id==selected_item.id: available=int(item.remaining)
		P.words(right,str(selected_item.name),Vector2(178,130),288,23)
		P.words(right,"%d 元 / 件" % int(selected_item.price),Vector2(178,173),290,29)
		P.words(right,"剩余 %d · 已有 %d" % [available,int(GameState.inventory.get(selected_item.id,0))],Vector2(178,216),240,17,P.MUTED)
		P.words(right,str(selected_item.get("description","")),Vector2(34,302),470,21)
		purchase_button=_btn(right,"放进购物篮  +",Vector2(30,370),Vector2(470,48),func(): _change(selected_item.id,1,false))
		purchase_button.name="AddToBasket"
		purchase_button.disabled=available<=int(EconomySystem.cart(shop_id).get(selected_item.id,0)) or not EconomySystem.shop_open(shop_id)
	var count := 0
	for q in EconomySystem.cart(shop_id).values(): count+=int(q)
	basket_button=ITEM.new(); basket_button.item_id="basket"; basket_button.caption="打开购物篮 · %d 件" % count
	basket_button.position=Vector2(36,430); basket_button.size=Vector2(470,212)
	basket_button.pressed.connect(func():mode="basket"; _refresh_right()); right.add_child(basket_button)
	basket_button.name="OpenBasket"
func _scroll(at: Vector2, extent: Vector2) -> VBoxContainer:
	var scroll := ScrollContainer.new(); scroll.position=at; scroll.size=extent; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; right.add_child(scroll)
	var rows := VBoxContainer.new(); rows.size_flags_horizontal=SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation",12); scroll.add_child(rows)
	return rows
func _basket() -> void:
	P.words(right,"带走这些",Vector2(24,10),350,31)
	_btn(right,"返回货架",Vector2(365,4),Vector2(155,42),func():mode="shelf"; _refresh_right())
	var rows := _scroll(Vector2(15,73),Vector2(520,408))
	var basket := EconomySystem.cart(shop_id)
	for id in basket:
		var item: Dictionary={}
		for candidate in shop.items:
			if candidate.id==id: item=candidate
		var row := Control.new(); row.custom_minimum_size=Vector2(495,95); rows.add_child(row)
		ART.picture(row,str(id),Vector2(0,2),Vector2(90,83))
		P.words(row,str(item.get("name",id)),Vector2(105,1),380,20)
		P.words(row,"%d 元 × %d" % [int(item.get("price",0)),int(basket[id])],Vector2(106,48),200,18)
		_btn(row,"−",Vector2(310,43),Vector2(46,42),_change.bind(str(id),-1,true)).name="Less_"+str(id)
		_btn(row,"+",Vector2(367,43),Vector2(46,42),_change.bind(str(id),1,true)).name="More_"+str(id)
		_btn(row,"取出",Vector2(420,43),Vector2(73,42),func():_quantity(str(id),0))
	if basket.is_empty():
		var label := Label.new(); label.text=LocalizationSystem.text("篮子空着，还没选东西。"); rows.add_child(label)
	var quote := EconomySystem.cart_quote(shop_id)
	P.words(right,"合计  %d 元" % int(quote.get("total",0)),Vector2(24,499),480,28)
	P.words(right,"结账后，小票和物品一起收好。",Vector2(24,545),480,18,P.MUTED)
	purchase_button=_btn(right,"结账 · %d 元" % int(quote.get("total",0)),Vector2(24,586),Vector2(480,52),_checkout)
	purchase_button.name="Checkout"
	purchase_button.disabled=buying or not bool(quote.ok) or int(quote.get("total",0))>GameState.money or not EconomySystem.shop_open(shop_id)
	if not bool(quote.ok) and not basket.is_empty(): status_label.text=str(quote.message)
func _change(id: String, delta: int, in_basket: bool) -> void:
	mode="basket" if in_basket else "shelf"
	_quantity(id,int(EconomySystem.cart(shop_id).get(id,0))+delta)
func _quantity(id: String, count: int) -> void:
	var result := EconomySystem.set_cart_quantity(shop_id,id,count)
	_refresh(); status_label.text=str(result.message)
	WorldSound.play_ui("paper" if result.ok else "error")
	if mode=="shelf" and is_instance_valid(purchase_button): purchase_button.grab_focus()
func _checkout() -> void:
	if buying or Time.get_ticks_msec()-last_purchase_msec<350: return
	buying=true
	var result := EconomySystem.purchase_cart(shop_id)
	buying=false; status_label.text=str(result.message)
	if result.ok:
		receipt=result.receipt; mode="receipt"; last_purchase_msec=Time.get_ticks_msec(); WorldSound.play_ui("coin")
	else: WorldSound.play_ui("error")
	_refresh()
func _receipt() -> void:
	ART.picture(right,"receipt",Vector2(12,0),Vector2(520,632),true)
	P.words(right,"SOLMERE · 小票",Vector2(100,105),355,27)
	P.words(right,"DAY %02d · %02d:%02d" % [int(receipt.get("day",1)),int(receipt.get("minute",0))/60,int(receipt.get("minute",0))%60],Vector2(100,150),355,17)
	var rows := _scroll(Vector2(100,200),Vector2(355,208))
	for line in receipt.get("line_items",[]):
		var label := Label.new(); label.text=LocalizationSystem.text("%s ×%d\n%d 元" % [LocalizationSystem.text(line.name),line.quantity,line.total]); label.add_theme_font_size_override("font_size",20)
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.custom_maximum_size.x=345; label.size_flags_horizontal=SIZE_EXPAND_FILL; rows.add_child(label)
	P.words(right,"实付  %d 元" % int(receipt.get("total",0)),Vector2(100,430),355,28)
	P.words(right,"已报销 %d 元 · 原票保留" % int(receipt.get("reimbursed_amount",0)) if bool(receipt.get("reimbursed",false)) else "收进生活记录了。",Vector2(100,472),355,19,P.MUTED)
	_btn(right,"继续挑选",Vector2(90,527),Vector2(280,48),func(): mode="shelf"; _refresh_right()).grab_focus()
func _history() -> void:
	P.words(right,"买过的东西",Vector2(20,8),335,31)
	_btn(right,"返回",Vector2(390,5),Vector2(130,43),func():mode="shelf";_refresh_right())
	var rows := _scroll(Vector2(14,75),Vector2(526,540))
	var all_receipts: Array=EconomySystem.state().receipts.values().duplicate()
	all_receipts.reverse()
	var found := false
	for entry in all_receipts:
		if entry.get("merchant_id","")!=shop_id: continue
		found=true
		var box := VBoxContainer.new(); rows.add_child(box)
		for line in entry.get("line_items",[]):
			var row := Control.new(); row.custom_minimum_size=Vector2(486,70); box.add_child(row)
			ART.picture(row,str(line.item_id),Vector2(0,0),Vector2(70,65))
			P.words(row,"%s ×%d" % [line.name,line.quantity],Vector2(83,15),392,20)
		var b := preload("res://scripts/ui/components/solmere_button.gd").new()
		b.text=LocalizationSystem.text("DAY %02d · 合计 %d 元 · 看小票" % [int(entry.day),int(entry.total)])
		b.custom_minimum_size.y=46; box.add_child(b)
		b.pressed.connect(func():receipt=entry; mode="receipt"; _refresh_right())
	if not found:
		var empty := Label.new(); empty.text=LocalizationSystem.text("还没有在这里买过东西。"); rows.add_child(empty)
func _buy(item: Dictionary) -> void:
	# Existing callers keep the real one-item checkout path.
	if buying or Time.get_ticks_msec()-last_purchase_msec<350: return
	buying=true
	var result := EconomySystem.purchase(shop_id,str(item.id))
	buying=false
	if result.ok: receipt=result.receipt; mode="receipt"; last_purchase_msec=Time.get_ticks_msec(); WorldSound.play_ui("coin")
	_refresh(); status_label.text=str(result.message)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if mode!="shelf": mode="shelf"; _refresh_right()
		else: queue_free()
		get_viewport().set_input_as_handled()
