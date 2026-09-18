extends Control
var mode := "restaurant"
var status := ""
var body: VBoxContainer

func _ready() -> void:
	add_to_group("meta_modal")
	add_to_group("economy_paper")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.1,0.16,0.16,.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var paper := PanelContainer.new()
	paper.position = Vector2(285,75)
	paper.size = Vector2(1030,750)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4ead5")
	style.set_content_margin_all(32)
	style.set_corner_radius_all(4)
	paper.add_theme_stylebox_override("panel",style)
	add_child(paper)
	var scroll := ScrollContainer.new()
	paper.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",15)
	scroll.add_child(body)
	build()

func label(text: String, size := 21, color := Color("39483f")) -> Label:
	var item := Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",color)
	body.add_child(item)
	return item

func button(text: String, action: Callable, disabled := false) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 48
	item.add_theme_font_size_override("font_size",20)
	item.disabled = disabled
	item.pressed.connect(action)
	body.add_child(item)
	return item

func build() -> void:
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	label("潮汐饭店 · 今天的采购" if mode == "restaurant" else "留在房间里的小东西" if mode == "collections" else "杂货店柜台",30)
	label("第 %d 天 · %s · 余额 %d 元" % [GameState.current_day,GameState.clock_text(),GameState.money],17)
	if not status.is_empty(): label(status,21,Color("9b583e"))
	match mode:
		"restaurant": restaurant()
		"collections": collections()
		"grocery": grocery()
	button("收起  ·  Esc",queue_free)

func restaurant() -> void:
	var order := EconomySystem.active_order()
	var work: Dictionary = EconomySystem.config.work.restaurant
	label("史勇奇把一张小清单推到出餐口。番茄、香草，再挑一样奇怪的食材。买齐后带上小票回来。")
	label("菜摊 10:30—18:30 · 便宜\n杂货店 08:00—22:00 · 有替代食材\n先垫采购费，交材料时凭小票报销。",19)
	label("料理班次 %d 分钟 · 工资 %d 元\n交材料 → 实际做菜出餐 → 工资到账 → 向店主领取收入证明" % [work.minutes,work.pay],19)
	if order.is_empty():
		button("收下采购清单",func() -> void: status = str(EconomySystem.accept_procurement().message); build())
	else:
		var summary := EconomySystem.procurement_summary()
		label(str(summary.next))
		var names := {"tomato":"番茄","herbs":"香草","sea_beans":"海盐豆罐头","star_salt":"星形盐片"}
		for id in names: label("%s  × %d" % [str(names[id]),int(GameState.inventory.get(id,0))],18)
		if not bool(order.get("delivered",false)):
			button("交材料并核对报销",func() -> void: status = str(EconomySystem.deliver_procurement().message); build(),str(summary.status) != "deliver")
		elif not bool(order.get("completed",false)):
			var end := GameState.current_minute+int(work.minutes)
			button("上料理台 · %d 分钟 · 预计 %02d:%02d 下班" % [work.minutes,end/60,end%60],_start_shift,not GameState.can_fit_now(int(work.minutes)))
		else: label("这一班已结算。原小票、工资记录和作品都已收好。",19)
	for receipt in EconomySystem.state().receipts.values():
		if str(receipt.get("procurement_id","")) != str(order.get("id","pending")): continue
		var description := str(receipt.title)+"\n"
		for line in receipt.line_items: description += "%s ×%d   %d元\n" % [line.name,line.quantity,line.total]
		description += "合计 %d 元  %s" % [receipt.total,str(receipt.stamp)]
		label(description,18,Color("6b634f"))

func _start_shift() -> void:
	if SceneRouter.gameplay_module("cooking","restaurant_procurement:"+str(EconomySystem.active_order().id)): queue_free()

func grocery() -> void:
	label("日用品、餐厅备料和每天新摆出来的旧物都在柜台旁。摄影货架负责胶卷、冲洗和取照片。",21)
	button("看看货架",func() -> void:
		var shop := preload("res://scripts/ui/shop_panel.gd").new()
		shop.shop_id = "grocery"
		get_parent().add_child(shop)
		queue_free())
	button("摄影与冲洗",func() -> void: FilmSystem.open_counter(get_parent()); queue_free())
	button("聊一会儿 · 15 分钟",func() -> void: _grocery_chat("greeting"))
	button("问营业时间 · 5 分钟",func() -> void: _grocery_chat("schedule_info"))

func _grocery_chat(topic: String) -> void:
	var parent := get_parent()
	queue_free()
	parent.call_deferred("_start_conversation","grocery",topic)

func collections() -> void:
	var entries: Dictionary = EconomySystem.state().collections
	if entries.is_empty(): label("货架还空着。杂货店每天会摆出两三件旧物，喜欢的可以买回来。"); return
	for id in entries:
		var item: Dictionary = entries[id]
		label(str(item.name),23)
		var nickname := LineEdit.new()
		nickname.placeholder_text = "给它起个名字"
		nickname.text = str(item.nickname)
		nickname.max_length = 32
		body.add_child(nickname)
		var note := LineEdit.new()
		note.placeholder_text = "为什么想留着它"
		note.text = str(item.note)
		note.max_length = 240
		body.add_child(note)
		var slot := OptionButton.new()
		for name in ["架子","桌面","墙上","抽屉展格"]: slot.add_item(name)
		slot.select(["shelf","desk","wall","drawer"].find(str(item.slot)))
		body.add_child(slot)
		button("摆好并记下",func() -> void:
			EconomySystem.name_collection(str(id),nickname.text,note.text,["shelf","desk","wall","drawer"][slot.selected])
			GameState.message_posted.emit("已摆好，回到房间就能看见。"))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
