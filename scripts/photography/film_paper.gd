extends Control
var mode := "counter"
var photo_id := ""
var paper: Panel
var status: Label
var note := ""
var working := false
var film_page := 0
const INK := Color("31658b")

func _ready() -> void:
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter=MOUSE_FILTER_STOP
	theme=preload("res://art/ui/solmere_ui.tres")
	FilmSystem.developing_progress.connect(_progress)
	rebuild()

func _progress(index: int, total: int) -> void:
	if is_instance_valid(status): status.text=LocalizationSystem.text("把照片装进纸袋 · %d / %d" % [index,total])

func label(parent: Node, text: String, at: Vector2, dimensions: Vector2, font_size := 21) -> Label:
	var l:=Label.new()
	l.text=LocalizationSystem.text(text)
	l.position=at
	l.size=dimensions
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color",INK)
	l.add_theme_font_size_override("font_size",font_size)
	parent.add_child(l)
	return l

func button(parent: Node, title: String, at: Vector2, dimensions: Vector2, action: Callable, disabled := false) -> Button:
	var b:=preload("res://scripts/ui/components/solmere_button.gd").new()
	b.variant="outlined"
	b.text=LocalizationSystem.text(title)
	b.position=at
	b.size=dimensions
	b.disabled=disabled
	b.add_theme_font_size_override("font_size",18)
	b.add_theme_color_override("font_color",INK)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func rebuild() -> void:
	for child in get_children(): child.hide(); child.queue_free()
	var dim:=ColorRect.new()
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.color=Color("182e33",.55)
	add_child(dim)
	paper=Panel.new()
	paper.position=Vector2(180,62)
	paper.size=Vector2(1240,778)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("edf3f4")
	style.set_corner_radius_all(14)
	paper.add_theme_stylebox_override("panel",style)
	add_child(paper)
	label(paper,"杂货店 · 摄影柜台" if mode=="counter" else "这张照片，接下来",Vector2(38,22),Vector2(900,50),29)
	button(paper,"返回",Vector2(1080,25),Vector2(120,40),queue_free)
	status=label(paper,note,Vector2(38,703),Vector2(1160,58),19)
	if mode=="counter": _counter()
	elif mode=="receipts": _receipt_history()
	else: _photo_actions()

func _counter() -> void:
	FilmSystem.update_processing()
	var state:=FilmSystem.state()
	var hours: Array=FilmSystem.economy().shop_hours.grocery
	label(paper,"余额 $%d  ·  %02d:%02d—%02d:%02d" % [GameState.money,int(hours[0])/60,int(hours[0])%60,int(hours[1])/60,int(hours[1])%60],Vector2(790,81),Vector2(410,35),18)
	if not bool(state.camera_owned):
		var art: Control=load("res://scripts/photography/photo_objects.gd").new()
		art.kind="camera"
		art.position=Vector2(65,110)
		art.size=Vector2(235,150)
		paper.add_child(art)
		label(paper,"柜台上的二手胶片机",Vector2(340,123),Vector2(720,36),25)
		label(paper,"老板正把一箱旧货分成几堆，旁边放着还没贴好的标签。",Vector2(340,167),Vector2(815,50),20)
		button(paper,"看看相机 · $%d" % int(FilmSystem.economy().camera_price),Vector2(340,230),Vector2(240,45),func()->void: FilmSystem.notice_camera(); note="快门还能用。老板说，你要是有空，可以帮他把这箱旧货理出来。"; rebuild())
		button(paper,"帮忙贴标签 · 25 min",Vector2(600,230),Vector2(270,45),func()->void:_act("help"),not bool(state.camera_seen) or GameState.current_role == "A")
		button(paper,"买下相机",Vector2(890,230),Vector2(250,45),func()->void:_act("camera"),GameState.money<int(FilmSystem.economy().camera_price))
	else:
		label(paper,"相机在包里。这里可以买胶卷，交底片，或拿回冲好的照片。",Vector2(38,90),Vector2(740,65),21)
		var types: Array=["normal","expired","bw","night"]
		for i in types.size():
			var kind:=str(types[i])
			var price:=int(FilmSystem.economy().film_prices[kind])
			var art: Control=load("res://scripts/photography/photo_objects.gd").new()
			art.kind=kind
			art.position=Vector2(55+i*288,150)
			art.size=Vector2(90,110)
			paper.add_child(art)
			label(paper,str(FilmSystem.config.types[kind].name)+"\n24 张",Vector2(155+i*288,155),Vector2(175,62),20)
			button(paper,"$%d · 买一卷" % price,Vector2(150+i*288,224),Vector2(155,36),func()->void:_act("buy",kind),GameState.money<price)
	label(paper,"胶卷与取片凭条",Vector2(38,300),Vector2(600,35),24)
	button(paper,"付款小票",Vector2(950,294),Vector2(245,43),func(): mode="receipts"; rebuild())
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(38,343)
	scroll.size=Vector2(1165,343)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	paper.add_child(scroll)
	var list:=VBoxContainer.new()
	list.size_flags_horizontal=SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	if state.rolls.is_empty(): label(list,"还没有胶卷。",Vector2.ZERO,Vector2(1080,80),22)
	for roll in state.rolls.values():
		var row:=Control.new()
		row.custom_minimum_size=Vector2(1110,98)
		list.add_child(row)
		var caption:=str(FilmSystem.config.types[roll.film_type].name)+"  ·  %02d / 24" % int(roll.exposures_used)
		var description:=str({"UNEXPOSED":"未装入","IN_CAMERA":"相机中","EXPOSED_PARTIAL":"可继续拍，或提前送洗","EXPOSED_FULL":"这一卷拍满了","PROCESSING":"冲洗中","READY_FOR_PICKUP":"照片到了 · 柜台领取","DEVELOPED":"已取片 · 相册中"}.get(str(roll.state),roll.state))
		if roll.has("ready_day"): description+=" · Day %d %02d:%02d" % [int(roll.ready_day),int(roll.ready_minute)/60,int(roll.ready_minute)%60]
		label(row,caption,Vector2.ZERO,Vector2(480,35),22)
		label(row,description,Vector2(0,42),Vector2(585,50),18)
		var id:=str(roll.id)
		if str(roll.state)=="UNEXPOSED": button(row,"装进相机",Vector2(790,16),Vector2(280,46),func()->void:_act("equip",id))
		elif str(roll.state) in ["EXPOSED_PARTIAL","EXPOSED_FULL"]:
			button(row,"普通 $%d · 次日10点" % FilmSystem.processing_price("standard"),Vector2(585,14),Vector2(275,50),func()->void:_act("standard",id),GameState.money<FilmSystem.processing_price("standard"))
			button(row,"加急 $%d · 180 min" % FilmSystem.processing_price("rush"),Vector2(875,14),Vector2(255,50),func()->void:_act("rush",id),GameState.money<FilmSystem.processing_price("rush"))
		elif str(roll.state)=="READY_FOR_PICKUP": button(row,"拿回照片",Vector2(790,16),Vector2(280,46),func()->void:_act("pickup",id))

func _act(action: String, id := "") -> void:
	if working: return
	if action in ["help","camera","buy","standard","rush"]:
		var confirm := preload("res://scripts/ui/components/confirm_sheet.gd").new()
		confirm.heading={"help":"整理旧货","camera":"带走这台相机","buy":"买一卷胶片","standard":"普通冲洗","rush":"加急冲洗"}[action]
		var cost := int(FilmSystem.economy().camera_price) if action=="camera" else 0
		if action=="buy": cost=int(FilmSystem.economy().film_prices[id])
		if action in ["standard","rush"]:
			cost=FilmSystem.processing_price(action)
			var roll: Dictionary=FilmSystem.state().rolls.get(id,{})
			confirm.description="%d 张底片\n费用 %d 元\n%s\n\n冲好后，回到柜台领取照片。" % [int(roll.get("exposures_used",0)),cost,"次日 10:00 可以领取" if action=="standard" else "需要 180 分钟"]
		else: confirm.description="花费 %d 元\n钱包余额 %d 元\n\n%s" % [cost,GameState.money,"需要 25 分钟，整理完成后领取相机。" if action=="help" else "放入随身包，随时可以使用。"]
		confirm.accepted.connect(func() -> void: confirm.queue_free(); _execute(action,id))
		add_child(confirm)
	else: _execute(action,id)

func _execute(action: String, id := "") -> void:
	if working: return
	working=true
	_disable_buttons(self)
	var result: Dictionary={}
	match action:
		"help": result=FilmSystem.acquire_camera(true)
		"camera": result=FilmSystem.acquire_camera(false)
		"buy": result=FilmSystem.buy_roll(id)
		"equip": result=FilmSystem.equip_roll(id)
		"standard","rush": result=FilmSystem.dropoff(id,action)
		"pickup": result=await FilmSystem.pickup(id)
	note=str(result.get("message",""))
	working=false
	rebuild()
	if bool(result.get("ok",false)) and not result.get("receipt",{}).is_empty():
		_show_receipt(result.receipt,str(result.get("ticket",{}).get("text","")))

func _show_receipt(value: Dictionary, collection_note := "") -> void:
	var view := preload("res://scripts/ui/components/receipt_view.gd").new()
	view.receipt=value; view.collection_note=collection_note; add_child(view)

func _receipt_history() -> void:
	label(paper,"摄影柜台 · 付款小票",Vector2(38,100),Vector2(820,50),27)
	button(paper,"回到柜台",Vector2(955,99),Vector2(235,43),func(): mode="counter"; rebuild())
	var scroll := ScrollContainer.new(); scroll.position=Vector2(38,174); scroll.size=Vector2(1157,496)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; paper.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal=SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",12); scroll.add_child(list)
	var receipts: Array=EconomySystem.state().receipts.values().duplicate(); receipts.reverse()
	var handover: Dictionary=FilmSystem.state().get("camera_handover",{})
	if not handover.is_empty(): receipts.append(handover)
	var count := 0
	for entry in receipts:
		if str(entry.get("category",""))!="photography" and str(entry.get("kind",""))!="handover": continue
		count+=1
		var b := preload("res://scripts/ui/components/solmere_button.gd").new(); b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.text=LocalizationSystem.text("DAY %02d · %s · %s  ›" % [int(entry.day),LocalizationSystem.text(str(entry.line_items[0].name)),LocalizationSystem.text("交换凭条" if entry.get("kind","")=="handover" else "%d 元" % int(entry.total))])
		b.custom_minimum_size.y=58; b.pressed.connect(_show_receipt.bind(entry,"")); list.add_child(b)
	if count==0: label(list,"付款后，小票会留在这里，也会收进生活记录。",Vector2.ZERO,Vector2(1030,80),22)

func _disable_buttons(parent: Node) -> void:
	for child in parent.get_children():
		if child is Button: child.disabled=true
		_disable_buttons(child)

func _photo_actions() -> void:
	var photo:=FilmSystem.photo(photo_id)
	if photo.is_empty(): label(paper,"这张照片还没冲好。",Vector2(50,150),Vector2(900,80)); return
	var library:=PhotoLibrary.new()
	library.root_path=str(photo.get("library_root","user://photos"))
	var image:=library.load_photo(photo_id)
	if image!=null:
		var picture:=TextureRect.new()
		picture.texture=ImageTexture.create_from_image(image)
		picture.position=Vector2(40,112)
		picture.size=Vector2(720,480)
		picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		paper.add_child(picture)
	label(paper,"Day %d · %s\n原片留在相册，使用时取一张纸质副本。" % [int(photo.get("day",1)),TravelSystem.location_name(str(photo.get("location_id",photo.get("location",""))))],Vector2(40,603),Vector2(720,85),20)
	button(paper,"夹入今天的作品集",Vector2(800,127),Vector2(385,48),func()->void:
		var ok:=ResidencySystem.file_material(photo_id,"day_"+str(GameState.current_day))
		if ok: FilmSystem.mark_photo_use(photo_id,"dossier")
		note="照片副本夹进今天的页里了。" if ok else "先领取资料袋，再把照片夹进去。"; rebuild())
	button(paper,"带到拼贴桌",Vector2(800,190),Vector2(385,48),func()->void:
		FilmSystem.state().collage_selection=photo_id
		FilmSystem.persist()
		note="照片副本已放进拼贴素材夹。到书信事务所的桌边，就能剪贴。"; rebuild())
	var home:=GameState.current_location==("residence" if GameState.current_role=="A" else "dorm")
	button(paper,"摆在房间里",Vector2(800,253),Vector2(385,48),func()->void: FilmSystem.mark_photo_use(photo_id,"room"); note="照片放在了房间的照片绳上。"; rebuild(),not home)
	button(paper,"留在社区照片墙",Vector2(800,316),Vector2(385,48),func()->void:
		var result: Dictionary=ResidencySystem.accept_contribution(photo_id,"print_shop",{"accepted":true,"source":"public_photo_display"})
		note=str(result.get("message","")); rebuild(),GameState.current_location!="print_shop")
	label(paper,"给在附近的人看看",Vector2(800,394),Vector2(385,34),22)
	var people:=DialogueSystem.people_at(GameState.current_location, SceneRouter.active_space_id)
	for i in mini(3,people.size()):
		var npc:=str(people[i])
		var name:=str(ScheduleSystem.residents.get(npc,{}).get("display_name",npc))
		button(paper,name,Vector2(800,442+i*55),Vector2(385,45),func()->void:
			FilmSystem.mark_photo_use(photo_id,"npc",npc)
			note=name+"把照片接过去看了一会儿：你当时站在哪边拍的？"; rebuild())
	if people.is_empty(): label(paper,"下次碰见人时，再把照片拿出来。",Vector2(800,442),Vector2(385,100),19)

func _input(event: InputEvent) -> void:
	if not get_tree().get_nodes_in_group("native_confirmation").is_empty(): return
	if working:
		if event is InputEventKey or event is InputEventMouseButton: get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
