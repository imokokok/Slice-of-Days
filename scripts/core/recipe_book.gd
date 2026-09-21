extends RefCounted
## Recipes use the existing personal/shared artifact stores and SaveManager.
const ALLOWED := ["lemon","bread","tomato","herbs","cheese","sea_beans","star_salt","sardine","sea_bream"]
static func originals() -> Array:
	return [
		{"id":"house_toast","title":"柠檬奶酪烤面包","author":"石泳琪","ingredients":["bread","cheese","lemon"],"heat":0.58,"notes":"先掰开面包，放上奶酪。\n小火热透，最后添一点柠檬。","strokes":[]},
		{"id":"house_beans","title":"海盐豆与番茄","author":"石泳琪","ingredients":["tomato","herbs","sea_beans"],"heat":0.62,"notes":"番茄先下锅，香草随后。\n海盐豆已有咸味，不必急着加盐。","strokes":[]},
		{"id":"house_fish","title":"柠檬香草煎鱼","author":"石泳琪","ingredients":["sardine","herbs","lemon"],"heat":0.56,"notes":"鱼先擦干，再进温热的锅。\n香草和柠檬留在最后。","strokes":[]}]
static func entries(section: String) -> Array:
	if section=="house": return originals()
	var source: Array=GameState.artifacts.get("recipes",[]) if section=="mine" else GameState.shared_state.get("world_artifacts",{}).get("recipes",[])
	return source.filter(func(r):return r is Dictionary and r.has("ingredients")).duplicate(true)
static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary: return {}
	var title := str(raw.get("title","")).strip_edges().left(48)
	var author := str(raw.get("author","")).strip_edges().left(40)
	var ingredients: Variant=raw.get("ingredients",[])
	if title.is_empty() or author.is_empty() or not ingredients is Array or ingredients.size()!=3: return {}
	var seen: Array=[]
	for id in ingredients:
		if not id is String or not ALLOWED.has(id) or seen.has(id): return {}
		seen.append(id)
	var raw_heat: Variant=raw.get("heat",0.58)
	if not (raw_heat is int or raw_heat is float): return {}
	var heat := float(raw_heat)
	if not is_finite(heat) or heat<0.42 or heat>0.74: return {}
	var strokes: Variant=raw.get("strokes",[])
	if not strokes is Array or strokes.size()>100: return {}
	var count := 0
	for stroke in strokes:
		if not stroke is Array or stroke.size()>1200: return {}
		for point in stroke:
			count+=1
			if not point is Array or point.size()!=2 or count>16000: return {}
			for v in point:
				if not (v is float or v is int) or not is_finite(float(v)) or float(v)<0 or float(v)>1: return {}
	return {"id":str(raw.get("id","")).left(80),"kind":"recipe","format":"solmere.recipe.v1","title":title,"author":author,"ingredients":seen,"heat":heat,"notes":str(raw.get("notes","")).left(1600),"strokes":strokes.duplicate(true)}
static func save_recipe(raw: Dictionary, shared := false, clear_draft := false) -> Dictionary:
	var row := validate(raw)
	if row.is_empty(): return {"ok":false,"message":"请写下菜名、署名，选择三种不同食材，并使用稳定火候。"}
	if row.id.is_empty(): row.id="recipe_"+Crypto.new().generate_random_bytes(12).hex_encode()
	var before := GameState.to_save_data().duplicate(true)
	row["day"]=GameState.current_day; row["role"]=GameState.current_role
	var target: Dictionary=GameState.shared_state.get("world_artifacts",{}) if shared else GameState.artifacts
	var rows: Array=target.get("recipes",[])
	for i in range(rows.size()-1,-1,-1):
		if str(rows[i].get("id",""))==row.id: rows.remove_at(i)
	target["recipes"]=rows
	if shared: GameState.shared_state.world_artifacts=target
	GameState.add_artifact("recipes",row,shared)
	if clear_draft: GameState.artifacts.erase("recipe_draft")
	GameState.commit_active_role_state()
	if not SaveManager.save_or_report("菜谱保存失败"):
		GameState.load_save_data(before)
		return {"ok":false,"message":"菜谱没能存好，手里的草稿仍保留。"}
	return {"ok":true,"message":"菜谱已放进公共菜谱。" if shared else "菜谱已收进我的菜谱。","recipe":row}
static func save_draft(raw: Dictionary) -> bool:
	var before := GameState.to_save_data().duplicate(true)
	GameState.artifacts["recipe_draft"]=raw.duplicate(true)
	GameState.commit_active_role_state()
	if SaveManager.save_or_report("菜谱草稿保存失败"): return true
	GameState.load_save_data(before)
	return false
static func export_recipe(row: Dictionary, path: String) -> bool:
	var checked := validate(row)
	if checked.is_empty(): return false
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(checked,"  ")); file.flush()
	return file.get_error()==OK
static func import_recipe(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>1048576: return {"ok":false,"message":"无法读取菜谱，或文件超过 1 MB。"}
	var row := validate(JSON.parse_string(file.get_as_text()))
	if row.is_empty(): return {"ok":false,"message":"这不是可用的 Solmere 菜谱。"}
	# Namespaced by content: foreign IDs never overwrite an existing resident's work.
	row.id="import_"+JSON.stringify(row).sha256_text().left(24)
	return save_recipe(row,true)
