extends Control
var mode := "restaurant"
var status := ""
var body: VBoxContainer
var restaurant_frame: Control

func _ready() -> void:
	add_to_group("meta_modal")
	add_to_group("economy_paper")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.1,0.16,0.16,.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	if mode == "restaurant":
		theme=preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()
		restaurant_frame=Control.new(); restaurant_frame.name="ProcurementClipboard"
		restaurant_frame.size=Vector2(1440,810); add_child(restaurant_frame)
		resized.connect(_layout_clipboard)
		_layout_clipboard(); build()
		return
	var paper := PanelContainer.new()
	paper.position = Vector2(132,104)
	paper.size = Vector2(1336,690)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("eef3f4")
	style.set_content_margin_all(32)
	style.set_corner_radius_all(12)
	paper.add_theme_stylebox_override("panel",preload("res://scripts/ui/production_assets.gd").surface(Color("faf5e8"),32))
	add_child(paper)
	var scroll := ScrollContainer.new()
	paper.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",15)
	scroll.add_child(body)
	build()
	preload("res://scripts/ui/solmere_motion.gd").paper_open(paper,SettingsSystem.reduced_motion())

func label(text: String, size := 21, color := Color("405653")) -> Label:
	var item := Label.new()
	item.text = LocalizationSystem.text(text)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",color)
	body.add_child(item)
	return item

func button(text: String, action: Callable, disabled := false) -> Button:
	var item := preload("res://scripts/ui/components/solmere_button.gd").new()
	item.variant="outlined"; item.alignment=HORIZONTAL_ALIGNMENT_LEFT
	item.text = LocalizationSystem.text(text)
	item.custom_minimum_size.y = 48
	item.add_theme_font_size_override("font_size",20)
	item.disabled = disabled
	item.pressed.connect(action)
	body.add_child(item)
	return item

func build() -> void:
	if mode == "restaurant":
		_build_clipboard()
		return
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	label("潮汐饭店 · 今天的采购" if mode == "restaurant" else "留在房间里的小东西" if mode == "collections" else "杂货店柜台",30)
	label("第 %d 天 · %s · 余额 %d 元" % [GameState.current_day,GameState.clock_text(),GameState.money],17)
	if not status.is_empty(): label(status,21,Color("9b583e"))
	match mode:
		"collections": collections()
		"grocery": grocery()
	button("收起  ·  "+SettingsSystem.binding_text("ui_cancel"),queue_free)

func _layout_clipboard() -> void:
	if not is_instance_valid(restaurant_frame): return
	var fit := minf(1.0,minf(size.x/1480.0,size.y/850.0))
	restaurant_frame.scale=Vector2.ONE*fit
	restaurant_frame.position=(size-restaurant_frame.size*fit)*.5

func _clipboard_column(at: Vector2, dimensions: Vector2) -> VBoxContainer:
	var scroll := ScrollContainer.new(); scroll.position=at; scroll.size=dimensions
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	restaurant_frame.add_child(scroll)
	var column := VBoxContainer.new(); column.size_flags_horizontal=SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",14); scroll.add_child(column)
	return column

func _build_clipboard() -> void:
	for child in restaurant_frame.get_children(): restaurant_frame.remove_child(child); child.queue_free()
	var art := TextureRect.new(); art.name="ClipboardArtwork"
	art.texture=preload("res://art/ui/reference_paper/clipboard.png")
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.size=restaurant_frame.size
	art.mouse_filter=MOUSE_FILTER_IGNORE; restaurant_frame.add_child(art)
	var p=preload("res://scripts/ui/components/interface_palette.gd")
	var work: Dictionary=EconomySystem.config.work.restaurant
	p.words(restaurant_frame,"潮汐饭店",Vector2(130,143),600,32,p.INK)
	p.words(restaurant_frame,"额外料理委托   /   %d 分钟   /   报酬 %d 元" % [work.minutes,work.pay],Vector2(130,191),650,18,p.MUTED)
	p.words(restaurant_frame,"第 %d 天   %s   ·   余额 %d 元" % [GameState.current_day,GameState.clock_text(),GameState.money],Vector2(850,179),430,18,p.INK)
	var rule := ColorRect.new(); rule.position=Vector2(130,228); rule.size=Vector2(1180,1); rule.color=Color("c3b798"); restaurant_frame.add_child(rule)
	body=_clipboard_column(Vector2(130,252),Vector2(680,344)); body.name="ProcurementList"
	var order := EconomySystem.active_order()
	label("今天需要这些",23)
	label("石泳琪：番茄、香草，再挑一样有意思的食材。买齐以后，带上小票回来。",20)
	for row in [["tomato","番茄"],["herbs","香草"],["sea_beans","海盐豆罐头 / 星形盐片（二选一）"]]:
		var count := int(GameState.inventory.get(row[0],0))
		if row[0]=="sea_beans": count+=int(GameState.inventory.get("star_salt",0))
		var delivered := bool(order.get("delivered",false))
		label(("✓  " if delivered or count>0 else "□  ")+str(row[1])+"    "+("已交付" if delivered else "已备齐" if count>0 else "待采购"),20)
	label("菜摊 10:30—18:30  ·  杂货店 08:00—22:00\n先垫采购费，交材料时凭小票报销。",17,p.MUTED)
	label("交材料 → 做菜出餐 → 委托报酬到账\n14:00的固定班次另在随身本里安排，同一份出餐不会重复付酬。",17,p.MUTED)
	var separator := ColorRect.new(); separator.position=Vector2(838,254); separator.size=Vector2(1,340); separator.color=Color("c3b798"); restaurant_frame.add_child(separator)
	body=_clipboard_column(Vector2(878,252),Vector2(405,344)); body.name="ProcurementReceipts"
	label("采购小票",23)
	var count := 0
	for receipt in EconomySystem.state().receipts.values():
		if str(receipt.get("procurement_id","")) != str(order.get("id","pending")): continue
		label(str(receipt.title),19)
		for line in receipt.line_items: label("%s  ×%d     %d 元" % [line.name,line.quantity,line.total],18)
		label("合计 %d 元  ·  %s" % [receipt.total,str(receipt.stamp)],18)
		count+=1
	if count==0: label("还没有小票\n买好食材后，收据会留在这里。",19,p.MUTED)
	body=VBoxContainer.new(); body.position=Vector2(205,622); body.size=Vector2(715,55); restaurant_frame.add_child(body)
	var note := status
	if order.is_empty():
		button("收下采购清单",func() -> void: status=str(EconomySystem.accept_procurement().message); build()).name="AcceptProcurement"
	else:
		var summary := EconomySystem.procurement_summary()
		if not bool(order.get("delivered",false)):
			button("交材料并核对报销",func() -> void: status=str(EconomySystem.deliver_procurement().message); build(),str(summary.status)!="deliver").name="DeliverProcurement"
			if note.is_empty(): note=str(summary.next)
		elif not bool(order.get("completed",false)):
			var end := GameState.current_minute+int(work.minutes)
			var entry := GameplayModuleSystem.entry_check("cooking")
			button("开始这份委托 · %d 分钟 · 预计 %02d:%02d 完成" % [work.minutes,end/60,end%60],_start_shift,not bool(entry.ok)).name="StartRestaurantWork"
			if not bool(entry.ok): note=str(entry.reason)
		else: label("✓  这份委托已结算，小票与收入记录已收好。",21)
	if body.get_child_count()>0 and body.get_child(0) is Button:
		body.get_child(0).variant="primary"; body.get_child(0).refresh()
	body=VBoxContainer.new(); body.position=Vector2(1040,622); body.size=Vector2(242,55); restaurant_frame.add_child(body)
	button("收起 · "+SettingsSystem.binding_text("ui_cancel"),queue_free).name="CloseProcurement"
	var feedback := p.words(restaurant_frame,note,Vector2(225,690),1055,18,Color("77533c"))
	feedback.name="ProcurementFeedback"

func _start_shift() -> void:
	# The router owns the one confirmation. Nesting a confirmation here caused
	# its native_confirmation guard to reject every accepted work request.
	if SceneRouter.request_gameplay("cooking","restaurant_procurement:"+str(EconomySystem.active_order().get("id",""))):
		queue_free()
	else:
		var entry := GameplayModuleSystem.entry_check("cooking")
		status=str(entry.get("reason","")) if not bool(entry.ok) else "请先处理当前打开的确认，再开始工作。"
		build()

func grocery() -> void:
	label("日用品、餐厅备料和每天新摆出来的旧物都在柜台旁。摄影货架负责胶卷、冲洗和取照片。",21)
	button("看看货架",func() -> void:
		var shop := preload("res://scripts/ui/shop_panel.gd").new()
		shop.shop_id = "grocery"
		get_parent().add_child(shop)
		queue_free())
	button("摄影与冲洗",func() -> void: FilmSystem.open_counter(get_parent()); queue_free())
	label("柜台告示 · 每日 08:00—22:00。采购后请收好小票，冲洗后的照片凭取件条领取。",18)

func collections() -> void:
	var entries: Dictionary = EconomySystem.state().collections
	if entries.is_empty(): label("货架还空着。杂货店每天会摆出两三件旧物，喜欢的可以买回来。"); return
	for id in entries:
		var item: Dictionary = entries[id]
		label(str(item.name),23)
		var nickname := LineEdit.new()
		nickname.placeholder_text = LocalizationSystem.text("给它起个名字")
		nickname.text = LocalizationSystem.text(str(item.nickname))
		nickname.max_length = 32
		body.add_child(nickname)
		var note := LineEdit.new()
		note.placeholder_text = LocalizationSystem.text("为什么想留着它")
		note.text = LocalizationSystem.text(str(item.note))
		note.max_length = 240
		body.add_child(note)
		var slot := OptionButton.new()
		for name in ["架子","桌面","墙上","抽屉展格"]: slot.add_item(LocalizationSystem.text(name))
		slot.select(["shelf","desk","wall","drawer"].find(str(item.slot)))
		body.add_child(slot)
		button("摆好并记下",func() -> void:
			EconomySystem.name_collection(str(id),nickname.text,note.text,["shelf","desk","wall","drawer"][slot.selected])
			GameState.message_posted.emit("已摆好，回到房间就能看见。"))

func _input(event: InputEvent) -> void:
	if not get_tree().get_nodes_in_group("native_confirmation").is_empty(): return
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
