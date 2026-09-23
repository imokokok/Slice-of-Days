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
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	label("潮汐饭店 · 今天的采购" if mode == "restaurant" else "留在房间里的小东西" if mode == "collections" else "杂货店柜台",30)
	label("第 %d 天 · %s · 余额 %d 元" % [GameState.current_day,GameState.clock_text(),GameState.money],17)
	if not status.is_empty(): label(status,21,Color("9b583e"))
	match mode:
		"restaurant": restaurant()
		"collections": collections()
		"grocery": grocery()
	button("收起  ·  "+SettingsSystem.binding_text("ui_cancel"),queue_free)

func restaurant() -> void:
	var outer := body
	var columns := HBoxContainer.new(); columns.add_theme_constant_override("separation",48); outer.add_child(columns)
	var actions := VBoxContainer.new(); actions.custom_minimum_size.x=605; actions.add_theme_constant_override("separation",19); columns.add_child(actions)
	var receipts := PanelContainer.new(); receipts.size_flags_horizontal=SIZE_EXPAND_FILL; columns.add_child(receipts)
	var paper := StyleBoxFlat.new(); paper.bg_color=Color("faf7ee"); paper.set_content_margin_all(24); receipts.add_theme_stylebox_override("panel",paper)
	var receipt_rows := VBoxContainer.new(); receipt_rows.add_theme_constant_override("separation",15); receipts.add_child(receipt_rows)
	body=actions
	var order := EconomySystem.active_order()
	var work: Dictionary = EconomySystem.config.work.restaurant
	label("石泳琪把一张小清单推到出餐口。番茄、香草，再挑一样奇怪的食材。买齐后带上小票回来。")
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
	body=receipt_rows
	label("今天的小票",26)
	var receipt_count := 0
	for receipt in EconomySystem.state().receipts.values():
		if str(receipt.get("procurement_id","")) != str(order.get("id","pending")): continue
		var description := str(receipt.title)+"\n"
		for line in receipt.line_items: description += "%s ×%d   %d元\n" % [line.name,line.quantity,line.total]
		description += "合计 %d 元  %s" % [receipt.total,str(receipt.stamp)]
		label(description,18,Color("405653")); receipt_count+=1
	if receipt_count==0: label("还没有这次采购的小票。\n\n买到食材后，小票会留在这里。",19)
	body=outer

func _start_shift() -> void:
	var minutes := int(EconomySystem.config.work.restaurant.minutes)
	var sheet := preload("res://scripts/ui/components/confirm_sheet.gd").new(); sheet.heading="开始料理班次？"; sheet.description="本次班次预计 %d 分钟。进入料理台后可查看采购要求和真实食材库存。" % minutes; sheet.confirm_text="上料理台"; add_child(sheet)
	sheet.accepted.connect(func() -> void:
		if SceneRouter.request_gameplay("cooking","restaurant_procurement:"+str(EconomySystem.active_order().id)): queue_free()
		else: sheet.queue_free())

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
