extends RefCounted
## Coastal activity backed by the same role save, inventory and material archive.
const LOCATIONS := ["bus_stop","cafe","park"]
const SPECIES := [
	{"id":"sardine","name":"沙丁鱼","min_cm":12,"max_cm":24,"speed":0.42,"window":0.28},
	{"id":"sea_bream","name":"金鳍海鲷","min_cm":21,"max_cm":42,"speed":0.57,"window":0.23}]
static func state() -> Dictionary:
	if not GameState.artifacts.has("fishing"): GameState.artifacts.fishing={"catches":[],"pending":{},"relaxed":false}
	return GameState.artifacts.fishing
static func begin_cast() -> Dictionary:
	if not LOCATIONS.has(GameState.current_location): return {"ok":false,"message":"这里没有安全的海边钓位。"}
	if not state().pending.is_empty(): return {"ok":false,"message":"先收好或放回这条鱼。"}
	if not GameState.can_fit_now(10): return {"ok":false,"message":"这会儿时间不够，下一段空闲再来。"}
	var before := GameState.to_save_data().duplicate(true)
	GameState.use_free_time(10); GameState.commit_active_role_state()
	if not SaveManager.save_or_report("抛竿记录保存失败"):
		GameState.load_save_data(before); return {"ok":false,"message":"没能保存，时间已恢复。"}
	var fish: Dictionary=SPECIES[1 if randf()<.3 else 0].duplicate()
	fish["catch_id"]="catch_"+Crypto.new().generate_random_bytes(12).hex_encode()
	fish["length_cm"]=randf_range(float(fish.min_cm),float(fish.max_cm))
	fish["day"]=GameState.current_day; fish["minute"]=GameState.current_minute
	fish["location"]=GameState.current_location; fish["role"]=GameState.current_role
	return {"ok":true,"fish":fish}
static func land(fish: Dictionary) -> bool:
	if fish.is_empty() or not state().pending.is_empty(): return false
	for caught in state().catches:
		if str(caught.catch_id)==str(fish.get("catch_id","")): return false
	var before := GameState.to_save_data().duplicate(true)
	state().pending=fish.duplicate(true); GameState.commit_active_role_state()
	if SaveManager.save_or_report("鱼获记录保存失败"): return true
	GameState.load_save_data(before); return false
static func resolve(keep: bool) -> Dictionary:
	var fish: Dictionary=state().pending.duplicate(true)
	if fish.is_empty(): return {"ok":false,"message":"没有待处理的鱼获。"}
	var before := GameState.to_save_data().duplicate(true)
	fish["kept"]=keep
	state().catches.append(fish); state().pending={}
	if keep: GameState.inventory[fish.id]=int(GameState.inventory.get(fish.id,0))+1
	var title := "%s · %.1f cm" % [fish.name,float(fish.length_cm)]
	GameState.add_artifact("fishing_journal",fish)
	ResidencySystem._add(str(fish.catch_id),"object",title,{"asset_id":fish.id,"source":fish.catch_id,"text":"带回厨房" if keep else "放回海里","length_cm":fish.length_cm})
	GameState.add_journal_entry({"id":fish.catch_id,"kind":"fishing","text":title+("，收进随身包，可以入菜。" if keep else "，又回到了海里。")})
	GameState.commit_active_role_state()
	if not SaveManager.save_or_report("鱼获保存失败"):
		GameState.load_save_data(before); return {"ok":false,"message":"没能保存，鱼仍留在这里，请重试。"}
	return {"ok":true,"message":"鱼已收进随身包，厨房也能用了。" if keep else "鱼摆了摆尾，回到海里。"}
