extends RefCounted
## Coastal activity backed by the same role save, inventory and material archive.
const LOCATIONS := ["port","park"]
static var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/coastal_fish.json"))
static var SPECIES: Array = catalog.species
static func species(id: String) -> Dictionary:
	for row: Dictionary in SPECIES:
		if row.id==id: return row.duplicate(true)
	return {}
static func sample_length(row: Dictionary, rng: RandomNumberGenerator) -> float:
	var bucket := rng.randf()
	var lower := float(row.common_min_cm)
	var upper := float(row.common_max_cm)
	if bucket < .10: lower=float(row.min_cm); upper=float(row.common_min_cm)
	elif bucket > .95: lower=float(row.common_max_cm); upper=float(row.max_cm)
	return snappedf(rng.randf_range(lower,upper),.1)
static func size_description(fish: Dictionary) -> String:
	var row := species(str(fish.get("id","")))
	if row.is_empty(): return "历史鱼获"
	var length := float(fish.get("length_cm",0))
	if length>float(row.max_cm): return "旧版尺寸记录"
	return "较小个体" if length<float(row.common_min_cm) else "较大个体" if length>float(row.common_max_cm) else "常见体型"
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
	var rng := RandomNumberGenerator.new(); rng.randomize()
	fish["length_cm"]=sample_length(fish,rng)
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
	ResidencySystem._add(str(fish.catch_id),"object",title,{"asset_id":fish.id,"source":fish.catch_id,"text":("带回厨房" if keep else "放回海里")+" · "+size_description(fish),"length_cm":fish.length_cm,"species_id":fish.id,"scientific_name":species(str(fish.id)).get("scientific_name",""),"day":fish.day,"minute":fish.minute,"location":fish.location})
	GameState.add_journal_entry({"id":fish.catch_id,"kind":"fishing","text":title+("，收进随身包，可以入菜。" if keep else "，又回到了海里。")})
	GameState.commit_active_role_state()
	if not SaveManager.save_or_report("鱼获保存失败"):
		GameState.load_save_data(before); return {"ok":false,"message":"没能保存，鱼仍留在这里，请重试。"}
	return {"ok":true,"message":"鱼已收进随身包，厨房也能用了。" if keep else "鱼摆了摆尾，回到海里。"}
