extends Node
## Rolls belong to the active protagonist's existing artifact state; no second save system.
signal changed
signal developing_progress(index: int, total: int)
var config: Dictionary = {}
var last_error := ""
var busy := false
var library := PhotoLibrary.new()
var capture_root := "user://film_captures"

func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/photography/film_types.json"))
	GameState.state_changed.connect(update_processing)

func state() -> Dictionary:
	if not GameState.artifacts.get("film",{}) is Dictionary or GameState.artifacts.get("film",{}).is_empty():
		var legacy: bool = not GameState.artifacts.get("photos",[]).is_empty()
		# New journeys obtain the camera through the grocery-counter exchange.
		# Legacy photo saves keep camera ownership during migration.
		GameState.artifacts["film"] = {"version":1,"camera_owned":legacy,"camera_seen":false,"helped":false,"first_discount_used":false,"active_roll":"","rolls":{},"photo_uses":{},"room_display":[],"collage_selection":""}
		if bool(GameState.artifacts.film.camera_owned): _new_roll("normal",true)
	return GameState.artifacts.film

func camera_available(show_message := true) -> bool:
	var available := bool(state().camera_owned)
	if not available and show_message: GameState.message_posted.emit("那台二手相机还在杂货店的柜台上。")
	return available

func _new_roll(kind: String, equip := false) -> Dictionary:
	var s: Dictionary = GameState.artifacts.film
	var id := "roll_"+GameState.current_role+"_"+str(Time.get_ticks_usec())+"_"+str(randi())
	var roll := {"id":id,"film_type":kind,"protagonist":GameState.current_role,"state":"IN_CAMERA" if equip else "UNEXPOSED","exposures_used":0,"captures":[],"developed_photo_ids":[],"picked_up":false,"history":["UNEXPOSED"]}
	if equip: roll.history.append("IN_CAMERA"); s.active_roll=id
	s.rolls[id] = roll
	return roll

func active_roll() -> Dictionary:
	var s := state()
	return s.rolls.get(str(s.active_roll),{})

func persist() -> bool:
	GameState.commit_active_role_state()
	changed.emit()
	return SaveManager.save_or_report("保存胶卷记录失败")

func _fail(message: String) -> Dictionary:
	last_error = message
	return {"ok":false,"message":message}

func _result(message: String, data: Dictionary = {}) -> Dictionary:
	data["ok"] = true
	data["message"] = message
	GameState.message_posted.emit(message)
	return data

func at_counter() -> bool:
	var hours: Array=economy().shop_hours.grocery
	return GameState.current_location == str(config.location_id) and GameState.current_minute >= int(hours[0]) and GameState.current_minute < int(hours[1])

func economy() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/economy/economy_config.json"))

func _pay(amount: int, title: String, category := "photography") -> bool:
	if not GameState.spend_money(amount,title): return false
	var tx: Dictionary = GameState.money_ledger.back()
	var service := get_node_or_null("/root/EconomySystem")
	if service != null: service.record_service_receipt("grocery",[{"item_id":title,"name":title,"quantity":1,"unit_price":amount,"total":amount}],category,tx,false)
	return true

func _payment_receipt() -> Dictionary:
	if GameState.money_ledger.is_empty(): return {}
	var id := "receipt_"+str(GameState.money_ledger.back().get("transaction_id",""))
	return EconomySystem.state().receipts.get(id,{}).duplicate(true)

func buy_roll(kind: String) -> Dictionary:
	if busy or not at_counter(): return _fail("到杂货店营业时再来看看。")
	if not config.types.has(kind): return _fail("这卷胶片暂时没有货。")
	busy = true
	var before := GameState.to_save_data().duplicate(true)
	state()
	var price := int(economy().film_prices[kind])
	if not _pay(price,str(config.types[kind].name)+"胶卷 · 24张"): busy=false; return _fail("手边的钱还差一点。")
	var roll := _new_roll(kind,active_roll().is_empty() and camera_available(false))
	if not persist(): GameState.load_save_data(before); busy=false; return _fail("这笔购买暂时没有保存，请重试。")
	busy=false
	return _result("收好一卷"+str(config.types[kind].name)+" · 24张，小票一起收好了。",{"roll_id":roll.id,"receipt":_payment_receipt()})

func notice_camera() -> void:
	state().camera_seen = true
	persist()

func acquire_camera(help := true) -> Dictionary:
	var s := state()
	if busy or not at_counter(): return _fail("到杂货店柜台聊聊这台相机。")
	if bool(s.camera_owned): return _fail("这台相机已经在你的包里。")
	if help and GameState.current_role == "A": return _fail("我想按标价买下它。")
	if help and not bool(s.camera_seen): return _fail("先看看柜台上那台二手相机。")
	if help and not GameState.can_fit_now(int(config.help_minutes)): return _fail("整理旧货要25分钟，眼下的空闲不够。")
	busy = true
	var before := GameState.to_save_data().duplicate(true)
	if help: GameState.use_free_time(int(config.help_minutes))
	elif not _pay(int(economy().get("camera_price",240)),"二手胶片相机"): busy=false; return _fail("手边的钱还差一点。")
	s = state()
	s.camera_owned = true
	s.helped = help
	_new_roll("expired" if help else "normal",true)
	var receipt: Dictionary = _payment_receipt() if not help else {}
	if help:
		# This is an exchange record, never a fabricated cash transaction.
		receipt={"id":"camera_handover_"+GameState.current_role,"kind":"handover","title":"相机交接凭条","day":GameState.current_day,"minute":GameState.current_minute,"total":0,"balance":GameState.money,"help_minutes":int(config.help_minutes),"line_items":[{"name":"二手胶片相机与一卷旧库存","quantity":1,"total":0}],"source":"grocery_camera_exchange","valid_for_living_record":false}
		s.camera_handover=receipt
		ResidencySystem._add(str(receipt.id),"ticket",str(receipt.title),receipt)
	GameState.add_artifact("objects",{"id":"film_camera_"+GameState.current_role,"kind":"object","title":"二手胶片相机","day":GameState.current_day,"source":"杂货店 · 整理旧货" if help else "杂货店购买"})
	if not persist(): GameState.load_save_data(before); busy=false; return _fail("相机交接暂时没有保存，请重试。")
	busy=false
	return _result("那台你刚才一直看的，拿去吧。再带一卷旧库存，交接凭条一起收好。" if help else "相机和一卷胶片一起装好了，小票收好。",{"receipt":receipt})

func equip_roll(id: String) -> Dictionary:
	var s := state()
	if not camera_available(false): return _fail("先取得相机。")
	var roll: Dictionary=s.rolls.get(id,{})
	if roll.is_empty() or str(roll.state) not in ["UNEXPOSED","IN_CAMERA"]: return _fail("已曝光的胶卷需要先送去冲洗。")
	var active := active_roll()
	if not active.is_empty() and str(active.id)!=id:
		if int(active.exposures_used)>0: return _fail("相机里还有已曝光的胶卷，可到杂货店提前送洗。")
		active.state="UNEXPOSED"
	s.active_roll=id
	roll.state="IN_CAMERA"
	roll.history.append("IN_CAMERA")
	persist()
	return _result("装入"+str(config.types[roll.film_type].name)+"胶卷")

func capture(image: Image, context: Dictionary, photo_library: PhotoLibrary = null) -> Dictionary:
	last_error=""
	if busy or image==null or image.is_empty(): last_error="暂时没有可拍的画面。"; return {}
	if not camera_available(false): last_error="相机还在杂货店。"; return {}
	var roll := active_roll()
	if roll.is_empty(): last_error="先装一卷胶片。"; return {}
	if int(roll.exposures_used)>=int(config.exposures): last_error="这一卷拍满了，带去杂货店冲洗吧。"; return {}
	busy=true
	var before := GameState.to_save_data().duplicate(true)
	var capture_id := str(roll.id)+"_"+str(int(roll.exposures_used)+1).pad_zeros(2)
	DirAccess.make_dir_recursive_absolute(capture_root)
	var path := capture_root.path_join(capture_id+".png")
	if image.save_png(path)!=OK: busy=false; last_error="底片保存失败，请重试。"; return {}
	var item := context.duplicate(true)
	item.merge({"capture_id":capture_id,"roll_id":roll.id,"film_type":roll.film_type,"protagonist":GameState.current_role,"role":GameState.current_role,"day":GameState.current_day,"game_minute":GameState.current_minute,"location_id":GameState.current_location,"capture_path":path,"notes":"","used_in_collage":false,"shown_to_npcs":[],"submitted_to_dossier":false,"library_root":photo_library.root_path if photo_library!=null else library.root_path},true)
	item["minute"]=GameState.current_minute
	item["location"]=GameState.current_location
	roll.captures.append(item)
	roll.exposures_used=int(roll.exposures_used)+1
	roll.state="EXPOSED_FULL" if int(roll.exposures_used)==int(config.exposures) else "EXPOSED_PARTIAL"
	if not roll.history.has(roll.state): roll.history.append(roll.state)
	if not persist(): GameState.load_save_data(before); busy=false; last_error="底片记录没有保存，请再按一次快门。"; return {}
	busy=false
	return item

func processing_price(mode: String) -> int:
	var prices: Dictionary=economy().processing_prices
	if mode=="standard" and bool(state().helped) and not bool(state().first_discount_used): return int(prices.first_standard_after_help)
	return int(prices.get(mode,0))

func dropoff(id: String, mode: String) -> Dictionary:
	var s := state()
	var roll: Dictionary=s.rolls.get(id,{})
	if busy or not at_counter(): return _fail("请在杂货店营业时把胶卷交到柜台。")
	if roll.is_empty() or not str(roll.state) in ["EXPOSED_PARTIAL","EXPOSED_FULL"]: return _fail("这卷已经交过，或还没有拍摄。")
	if not config.processing.has(mode): return _fail("请选择普通或加急冲洗。")
	busy=true
	var before := GameState.to_save_data().duplicate(true)
	var price := processing_price(mode)
	if not _pay(price,"胶卷冲洗 · "+("加急" if mode=="rush" else "普通")): busy=false; return _fail("手边的钱还差一点。")
	if mode=="standard" and bool(s.helped): s.first_discount_used=true
	roll.state="DROPPED_OFF"
	roll.history.append("DROPPED_OFF")
	roll.dropoff_day=GameState.current_day
	roll.dropoff_minute=GameState.current_minute
	roll.processing_mode=mode
	roll.price_paid=price
	var ready := (GameState.current_day+1)*1440+int(config.processing.standard.ready_minute) if mode=="standard" else GameState.current_day*1440+GameState.current_minute+int(config.processing.rush.minutes)
	roll.ready_day=ready/1440
	roll.ready_minute=ready%1440
	roll.state="PROCESSING"
	roll.history.append("PROCESSING")
	if str(s.active_roll)==id: s.active_roll=""
	var ticket := {"id":"processing_"+id,"kind":"ticket","title":"胶卷冲洗凭条","day":GameState.current_day,"minute":GameState.current_minute,"roll_id":id,"amount":price,"ready_day":roll.ready_day,"ready_minute":roll.ready_minute,"picked_up":false,"text":"Day %d · %02d:%02d 后到杂货店取照片。" % [int(roll.ready_day),int(roll.ready_minute)/60,int(roll.ready_minute)%60]}
	GameState.add_artifact("film_tickets",ticket)
	ResidencySystem.state().materials[ticket.id]=ticket
	if not persist(): GameState.load_save_data(before); busy=false; return _fail("送洗记录暂时没有保存，请重试。")
	busy=false
	return _result("凭条收好。"+str(ticket.text),{"receipt":_payment_receipt(),"ticket":ticket})

func _finish_result(message: String) -> Dictionary:
	busy=false
	return _result(message)

func update_processing() -> void:
	if not GameState.artifacts.get("film",{}) is Dictionary or GameState.artifacts.get("film",{}).is_empty(): return
	var s: Dictionary=GameState.artifacts.film
	var now := GameState.current_day*1440+GameState.current_minute
	for roll in s.rolls.values():
		if str(roll.state)=="PROCESSING" and now>=int(roll.ready_day)*1440+int(roll.ready_minute):
			roll.state="READY_FOR_PICKUP"
			roll.history.append("READY_FOR_PICKUP")
	changed.emit()

func pickup(id: String) -> Dictionary:
	update_processing()
	var roll: Dictionary=state().rolls.get(id,{})
	if busy or not at_counter(): return _fail("照片留在杂货店，营业时去柜台拿。")
	if roll.is_empty() or str(roll.state)!="READY_FOR_PICKUP": return _fail("还没到取片时间，或这卷已经拿过了。")
	busy=true
	var before:=GameState.to_save_data().duplicate(true)
	for captured in roll.captures:
		developing_progress.emit(roll.captures.find(captured)+1,roll.captures.size())
		var image:=Image.load_from_file(str(captured.capture_path))
		if image==null: GameState.load_save_data(before); busy=false; return _fail("一张底片文件暂时无法读取。")
		var finished: Image=await _develop(image,str(roll.film_type),str(captured.capture_id))
		var photo_library:=PhotoLibrary.new()
		photo_library.root_path=str(captured.get("library_root",library.root_path))
		var photo:=photo_library.save_photo(finished,captured)
		if photo.is_empty(): GameState.load_save_data(before); busy=false; return _fail(photo_library.last_error)
		photo["status"]="DEVELOPED"
		photo["id"]=photo.photo_id
		photo["kind"]="photo"
		photo["developed_path"]=photo_library.root_path.path_join(str(photo.photo_id)).path_join("photo.png")
		if not photo_library.update_metadata(str(photo.photo_id),photo):
			GameState.load_save_data(before); busy=false; return _fail("照片信息暂时没有保存，请再取一次。")
		if not roll.developed_photo_ids.has(photo.photo_id): roll.developed_photo_ids.append(photo.photo_id)
		GameState.add_artifact("photos",photo)
	roll.state="DEVELOPED"
	roll.history.append("DEVELOPED")
	roll.picked_up=true
	for ticket in GameState.artifacts.get("film_tickets",[]):
		if str(ticket.roll_id)==id: ticket.picked_up=true; ticket["stamp"]="已取片"
	if ResidencySystem.state().materials.has("processing_"+id): ResidencySystem.state().materials["processing_"+id].merge({"picked_up":true,"stamp":"已取片"},true)
	if not persist(): GameState.load_save_data(before); busy=false; return _fail("取片记录暂时没有保存，请重试。")
	return _finish_result("照片装在纸袋里了。G 相册里可以翻看。")

func _develop(image: Image, kind: String, seed_id: String) -> Image:
	var result := image.duplicate() as Image
	result.convert(Image.FORMAT_RGB8)
	var bytes := result.get_data()
	var style: Dictionary=config.types[kind]
	var width:=result.get_width()
	var height:=result.get_height()
	var noise:=RandomNumberGenerator.new()
	noise.seed=hash(seed_id)
	for y in height:
		if y%64==0: await get_tree().process_frame
		for x in width:
			var i: int=(y*width+x)*3
			var color:=Vector3(bytes[i],bytes[i+1],bytes[i+2])/255.0
			if bool(style.get("monochrome",false)):
				var gray:=clampf((color.dot(Vector3(.299,.587,.114))-.5)*1.08+.5,0,1)
				color=Vector3(gray,gray,gray)
			var grain:=noise.randf_range(-float(style.grain),float(style.grain))
			var uv:=Vector2(float(x)/width-.5,float(y)/height-.5)
			var shade:=1.0-float(style.vignette)*uv.length_squared()*2
			color=color*Vector3(float(style.tint[0]),float(style.tint[1]),float(style.tint[2]))*shade+Vector3.ONE*grain
			if bool(style.get("light_leak",false)):
				var leak:=pow(maxf(0,1.0-float(x)/maxf(1,width*.16)),3)*.07
				color+=Vector3(leak,leak*.35,0)
			bytes[i]=clampi(roundi(color.x*255),0,255)
			bytes[i+1]=clampi(roundi(color.y*255),0,255)
			bytes[i+2]=clampi(roundi(color.z*255),0,255)
	return Image.create_from_data(width,height,false,Image.FORMAT_RGB8,bytes)

func developed_photos() -> Array:
	return GameState.artifacts.get("photos",[]).filter(func(item: Dictionary)->bool:return str(item.get("status","DEVELOPED"))=="DEVELOPED")

func photo(id: String) -> Dictionary:
	for row in developed_photos():
		if str(row.get("id",row.get("photo_id","")))==id: return row
	return {}

func mark_photo_use(id: String, use: String, target := "") -> bool:
	var item:=photo(id)
	if item.is_empty(): return false
	if use=="dossier": item.submitted_to_dossier=true
	elif use=="collage": item.used_in_collage=true
	elif use=="npc":
		if not item.get("shown_to_npcs",[]).has(target):
			if not item.has("shown_to_npcs"): item.shown_to_npcs=[]
			item.shown_to_npcs.append(target)
			RelationshipSystem.record_encounter(target,"photo_"+id,["看过我拍的照片"])
	elif use=="room":
		if not state().room_display.has(id): state().room_display.append(id)
	state().photo_uses[id] = {"last_use":use,"day":GameState.current_day,"target":target}
	var photo_library:=PhotoLibrary.new()
	photo_library.root_path=str(item.get("library_root",library.root_path))
	if not photo_library.update_metadata(id,item): return false
	return persist()

func open_counter(parent: Node) -> Control:
	var paper: Control = load("res://scripts/photography/film_paper.gd").new()
	parent.add_child(paper)
	return paper

func open_photo_actions(id: String, parent: Node) -> Control:
	var paper: Control = load("res://scripts/photography/film_paper.gd").new()
	paper.photo_id=id
	paper.mode="photo"
	parent.add_child(paper)
	return paper
