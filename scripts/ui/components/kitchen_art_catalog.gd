extends RefCounted
## Artist-supplied kitchen cutouts and the cooking behavior attached to them.
## Keeping this in one registry prevents the shelf, chopping board, pan and
## recipe book from quietly falling back to different placeholder artwork.

const ROOT := "res://art/ui/kitchen_supplied/"

const ENTRIES := [
	{"id":"cooking_oil","label":"一瓶食用油","asset":"cooking_oil.png","shelf":"调料架","profile":"oil","cuttable":false},
	{"id":"salt_shaker","label":"盐罐","asset":"salt_shaker.png","shelf":"调料架","profile":"salt","cuttable":false},
	{"id":"ketchup","label":"番茄酱","asset":"ketchup.png","shelf":"调料架","profile":"sauce","cuttable":false},
	{"id":"wasabi","label":"芥末","asset":"wasabi.png","shelf":"调料架","profile":"sauce","cuttable":false,
		"detail":"辛味来得很快，适合尝过以后再决定。","flavors":["bright"],
		"prep_options":[
			{"id":"loosen","label":"先调开一点","detail":"辛味分散得更均匀，不会只聚在一口里。","pan_cue":"关火后用余温调开"},
			{"id":"finish","label":"留作最后点味","detail":"保留直接的辛香，让入口有一个清楚的转折。","pan_cue":"装盘前在边缘点入","heat_shift":-0.06}
		]},
	{"id":"pepper_grinder","label":"黑胡椒粒","asset":"pepper_grinder.png","shelf":"调料架","profile":"pepper","cuttable":false},
	{"id":"mushrooms","label":"一把混合蘑菇","asset":"mushrooms.png","shelf":"菜筐","profile":"vegetable"},
	{"id":"potato","label":"土豆","asset":"potato.png","shelf":"菜筐","profile":"root"},
	{"id":"carrot","label":"胡萝卜","asset":"carrot.png","shelf":"菜筐","profile":"root"},
	{"id":"beet","label":"甜菜根","asset":"beet.png","shelf":"菜筐","profile":"root","flavors":["earthy","bright"]},
	{"id":"eggplant","label":"茄子","asset":"eggplant.png","shelf":"菜筐","profile":"vegetable","heat_drop":0.09},
	{"id":"zucchini","label":"西葫芦","asset":"zucchini.png","shelf":"菜筐","profile":"vegetable","heat_drop":0.08},
	{"id":"bell_pepper_yellow","label":"黄彩椒","asset":"bell_pepper_yellow.png","shelf":"彩椒篮","profile":"pepper_vegetable"},
	{"id":"bell_pepper_purple","label":"紫彩椒","asset":"bell_pepper_purple.png","shelf":"彩椒篮","profile":"pepper_vegetable"},
	{"id":"bell_pepper_orange","label":"橙彩椒","asset":"bell_pepper_orange.png","shelf":"彩椒篮","profile":"pepper_vegetable"},
	{"id":"bell_pepper_dark","label":"深紫彩椒","asset":"bell_pepper_dark.png","shelf":"彩椒篮","profile":"pepper_vegetable"},
	{"id":"bell_pepper_bronze","label":"褐彩椒","asset":"bell_pepper_bronze.png","shelf":"彩椒篮","profile":"pepper_vegetable"},
	{"id":"bell_pepper_white","label":"白彩椒","asset":"bell_pepper_white.png","shelf":"彩椒篮","profile":"pepper_vegetable"},
	{"id":"bell_pepper_red","label":"红彩椒","asset":"bell_pepper_red.png","shelf":"彩椒篮","profile":"pepper_vegetable"},
	{"id":"bell_pepper_green","label":"青彩椒","asset":"bell_pepper_green.png","shelf":"彩椒篮","profile":"pepper_vegetable"},
	{"id":"sock","label":"一只干净袜子","asset":"sock.png","shelf":"奇怪食材","profile":"strange","prep_options":[
		{"id":"wring","label":"洗净后拧干","detail":"先把水分收住，布料不会一下带走太多锅温。","pan_cue":"锅底稳定温热时沿边放入"},
		{"id":"ribbons","label":"剪成柔软布条","detail":"边缘变多，会更快吸住锅里的味道。","pan_cue":"汤汁刚开始冒泡时散开放入","heat_drop_delta":0.03}
	]},
	{"id":"confetti","label":"一把庆祝彩带","asset":"confetti.png","shelf":"奇怪食材","profile":"strange","cuttable":false,"prep_options":[
		{"id":"sort","label":"挑出长彩带","detail":"保留颜色和卷曲，最后还能看见它原来的样子。","pan_cue":"收火前轻轻铺在表面","heat_shift":-0.04},
		{"id":"bundle","label":"拢成小彩团","detail":"不让碎片到处跑，翻拌时更容易照看。","pan_cue":"火声放轻后放在锅中央"}
	]},
	{"id":"toilet_roll","label":"一卷纸巾","asset":"toilet_roll.png","shelf":"奇怪食材","profile":"strange","prep_options":[
		{"id":"sheets","label":"撕成薄片","detail":"薄片会很快吸汁，需要留意锅里的水分。","pan_cue":"汤汁足够时分次放入","heat_drop_delta":0.04},
		{"id":"spiral","label":"卷成纸团","detail":"中心保持干燥，外层先接住味道。","pan_cue":"稳定中火时放在锅边"}
	]},
	{"id":"ice_block","label":"一块冰","asset":"tissue_box_closed.png","prepared_asset":"tissue_box_open.png","shelf":"奇怪食材","profile":"strange","cuttable":false,"flavors":["fresh"],"heat_drop":0.18,"prep_options":[
		{"id":"frosted","label":"保留结实冰面","detail":"让它完整带走一截锅温，边角会最先变得透明。","pan_cue":"锅离火以后再放到边缘"},
		{"id":"soften","label":"先让四角化开","detail":"表面水珠先擦掉，冰块会慢一点冲淡锅里的味道。","pan_cue":"火声收轻后贴着锅边滑入","heat_drop_delta":-0.08}
	]},
	{"id":"toothpaste","label":"一管牙膏","asset":"toothpaste.png","shelf":"奇怪食材","profile":"strange","cuttable":false,"flavors":["bright"],"prep_options":[
		{"id":"dot","label":"只挤一小点","detail":"凉味很强，一点就足以改变整锅方向。","pan_cue":"尝味以后再点入","heat_drop_delta":-0.03},
		{"id":"ribbon","label":"挤成细长一线","detail":"让凉味分散开，但不要反复翻动。","pan_cue":"关火装盘前拉出细线"}
	]},
	{"id":"dentures","label":"一副假牙","asset":"dentures.png","shelf":"奇怪食材","profile":"strange","cuttable":false,"prep_options":[
		{"id":"close","label":"把牙齿合好","detail":"上下排扣在一起，锅里翻动时不容易散开。","pan_cue":"锅底安静下来时完整放入","heat_shift":-0.04},
		{"id":"separate","label":"拆成上下两排","detail":"接触面更多，摆盘时也更有表情。","pan_cue":"中火稳定后分开放入"}
	]},
	{"id":"eraser","label":"蓝白橡皮","asset":"eraser.png","shelf":"奇怪食材","profile":"strange","prep_options":[
		{"id":"dice","label":"切成小方丁","detail":"每一面都能碰到锅底，形状仍然整齐。","pan_cue":"油面轻轻展开时下锅"},
		{"id":"crumbs","label":"擦成碎屑","detail":"会很快融进其他味道，几乎看不出原形。","pan_cue":"翻拌结束前均匀撒入","heat_shift":-0.05}
	]},
	{"id":"yarn_ball","label":"毛线团","asset":"yarn_ball.png","shelf":"奇怪食材","profile":"strange","prep_options":[
		{"id":"small_ball","label":"重新绕成小团","detail":"线头收好，锅里不会马上缠住别的材料。","pan_cue":"汤汁稳定后放在中央"},
		{"id":"long_thread","label":"拉出一段长线","detail":"让它沿着食材穿过去，翻拌时动作要轻。","pan_cue":"收小火后沿锅边绕入","heat_shift":-0.05}
	]},
	{"id":"sponge","label":"清洁海绵","asset":"sponge.png","shelf":"奇怪食材","profile":"strange","prep_options":[
		{"id":"squeeze","label":"挤干水分","detail":"先腾出孔隙，才接得住锅里的味道。","pan_cue":"汤汁调好以后再放入","heat_drop_delta":-0.04},
		{"id":"tear","label":"撕成蓬松小块","detail":"吸收得更快，也更需要及时翻面。","pan_cue":"稳定细响时分开放入"}
	]},
	{"id":"tennis_ball","label":"网球","asset":"tennis_ball.png","shelf":"奇怪食材","profile":"strange","prep_options":[
		{"id":"score","label":"沿白线浅划","detail":"保留完整弹性，只给热气留一条入口。","pan_cue":"锅底热透前放入"},
		{"id":"press","label":"轻轻压扁","detail":"不再到处滚，接触锅底的面积也更大。","pan_cue":"油面刚开始波动时压住","heat_shift":-0.04}
	]},
	{"id":"resignation_letter","label":"一封辞职信","asset":"resignation_letter.png","shelf":"奇怪食材","profile":"strange","prep_options":[
		{"id":"fold","label":"折成小方块","detail":"字还留在里面，边角会先碰到锅底。","pan_cue":"火声不急时放在锅边"},
		{"id":"strips","label":"撕成短纸条","detail":"每一句话分开以后，会更快混进这道菜里。","pan_cue":"关火前一条条撒入","heat_shift":-0.07}
	]},
	{"id":"alarm_clock","label":"一只闹钟","asset":"alarm_clock.png","shelf":"奇怪食材","profile":"strange","cuttable":false,"prep_options":[
		{"id":"bells","label":"拆下两只铃铛","detail":"主体不再晃动，金属声也变得更轻。","pan_cue":"锅底温热时分开放入"},
		{"id":"ticking","label":"保留滴答声","detail":"让节奏继续，照着滴答决定翻拌时机。","pan_cue":"第一声稳定滋响出现时放入","heat_shift":0.06}
	]},
]

static var _texture_cache: Dictionary = {}


static func _profile(id: String) -> Dictionary:
	match id:
		"oil":
			return {"detail":"负责传热和托住香气，多少与时机会改变锅底。","prep_action":"确认分量，先看锅底温度","pan_cue":"锅底温热、还没有冒烟时","heat_window":[0.30,0.58],"heat_drop":0.01,"flavors":["rich"],"prep_options":[
				{"id":"coat","label":"先润匀锅底","detail":"薄薄一层更容易看清火候变化。","pan_cue":"锅底温热时转动铺开"},
				{"id":"edge","label":"沿锅边慢慢淋入","detail":"油会带着香气往中央聚，不会一下压住材料。","pan_cue":"第一样材料下锅前沿边加入","heat_shift":0.03}
			]}
		"salt":
			return {"detail":"咸味直接，适合尝过以后少量补足。","prep_action":"先倒在指尖确认分量","pan_cue":"火声最轻的时候","heat_window":[0.20,0.44],"heat_drop":0.01,"flavors":["salty"],"prep_options":[
				{"id":"pinch","label":"留一小撮","detail":"容易控制，也能均匀散开。","pan_cue":"尝味以后用指尖撒入"},
				{"id":"finish","label":"留作装盘点盐","detail":"入口时才碰到咸味，层次会更清楚。","pan_cue":"关火装盘前再放","heat_shift":-0.06}
			]}
		"sauce":
			return {"detail":"酸甜浓稠，既能上色也会让锅温稍降。","prep_action":"擦净瓶口，先挤出空气","pan_cue":"锅底稳定细响以后","heat_window":[0.34,0.58],"heat_drop":0.04,"flavors":["bright","sweet"],"prep_options":[
				{"id":"line","label":"挤成细线","detail":"容易均匀裹住材料，酸甜不会聚成一团。","pan_cue":"翻拌前沿锅边挤入"},
				{"id":"spoon","label":"挤成一大勺","detail":"味道更集中，需要用余温慢慢调开。","pan_cue":"收小火后放在锅中央","heat_shift":-0.05,"heat_drop_delta":0.02}
			]}
		"pepper":
			return {"detail":"香气需要现磨，久煮会只剩辛苦味。","prep_action":"转动研磨盖，闻到香气就停","pan_cue":"关火前的短暂余温里","heat_window":[0.22,0.48],"heat_drop":0.01,"flavors":["bright"],"prep_options":[
				{"id":"fine","label":"磨成细粉","detail":"香气分布均匀，适合整锅收尾。","pan_cue":"关火前均匀磨入"},
				{"id":"coarse","label":"保留粗粒","detail":"入口偶尔碰到辛香，轮廓更明显。","pan_cue":"装盘以后再磨几下","heat_shift":-0.05}
			]}
		"root":
			return {"detail":"扎实耐火，需要给中心留出变软的时间。","prep_action":"刷净表面，切成受热均匀的块","pan_cue":"锅底热透、油面刚刚展开时","heat_window":[0.52,0.74],"heat_drop":0.10,"flavors":["starch","earthy"],"prep_options":[
				{"id":"thick","label":"切成厚块","detail":"中心保持扎实，适合慢慢煨透。","pan_cue":"锅底热透时先让切面贴锅"},
				{"id":"small","label":"切成小丁","detail":"熟得更快，边角也更容易带上焦香。","pan_cue":"油面展开后均匀撒入","heat_shift":-0.06}
			]}
		"pepper_vegetable":
			return {"detail":"颜色明亮、口感清脆，久煮会失去轮廓。","prep_action":"去掉蒂和籽，顺着弧面切开","pan_cue":"锅里已有稳定热气时","heat_window":[0.43,0.67],"heat_drop":0.06,"flavors":["fresh","sweet"],"prep_options":[
				{"id":"strips","label":"顺纹切成长条","detail":"还会保留一点清脆，颜色也更完整。","pan_cue":"中火稳定时沿锅边放入"},
				{"id":"dice","label":"切成彩色小丁","detail":"更快融进其他材料，每一勺都能带到。","pan_cue":"翻拌前均匀撒入","heat_shift":-0.04}
			]}
		"strange":
			return {"detail":"外表完全不像食材，但值得被认真处理一次。","prep_action":"先确认材质和声音，再决定怎样下锅","pan_cue":"锅底稳定、动作不急的时候","heat_window":[0.36,0.62],"heat_drop":0.07,"flavors":["strange"],"prep_options":[
				{"id":"whole","label":"保留完整形状","detail":"先认识它原来的样子，再让锅里的变化发生。","pan_cue":"稳定中火时轻轻放入"},
				{"id":"pieces","label":"分成容易照看的小份","detail":"每一份都能碰到其他材料，变化会更明显。","pan_cue":"锅底出现细响时分开放入","heat_shift":-0.04}
			]}
		_:
			return {"detail":"含水柔软，火太急会先失去香气。","prep_action":"擦净后切成大小接近的块","pan_cue":"油面开始轻轻波动时","heat_window":[0.42,0.68],"heat_drop":0.07,"flavors":["fresh","savory"],"prep_options":[
				{"id":"slices","label":"切成厚片","detail":"能保留里面的水分，咬下去还有完整口感。","pan_cue":"油面轻轻波动时铺开放入"},
				{"id":"small","label":"切成小块","detail":"受热更快，也更容易吸住锅里的味道。","pan_cue":"锅底稳定细响时撒入","heat_shift":-0.05}
			]}


static func raw_entry(id: String) -> Dictionary:
	for value in ENTRIES:
		var entry: Dictionary = value
		if str(entry.get("id","")) == id:
			return entry
	return {}


static func token_data(id: String) -> Dictionary:
	var raw := raw_entry(id)
	if raw.is_empty(): return {}
	var result := _profile(str(raw.get("profile","vegetable")))
	result.merge(raw.duplicate(true),true)
	return result


static func tokens() -> Array:
	var result: Array = []
	for value in ENTRIES:
		result.append(token_data(str((value as Dictionary).get("id",""))))
	return result


static func append_to(existing: Array) -> Array:
	var result := existing.duplicate(true)
	var ids: Array[String] = []
	for value in result: ids.append(str((value as Dictionary).get("id","")))
	for value in tokens():
		var token: Dictionary = value
		if not ids.has(str(token.id)): result.append(token)
	return result


static func is_supplied_ingredient(id: String) -> bool:
	return not raw_entry(id).is_empty()


static func ingredient_name(id: String) -> String:
	return str(raw_entry(id).get("label",id))


static func shelf_name(id: String) -> String:
	return str(raw_entry(id).get("shelf","手边食材"))


static func can_cut(id: String) -> bool:
	return bool(raw_entry(id).get("cuttable",true))


static func texture(id: String, prepared := false) -> Texture2D:
	var entry := raw_entry(id)
	if entry.is_empty(): return null
	var filename := str(entry.get("prepared_asset",entry.asset)) if prepared else str(entry.asset)
	var path := ROOT+filename
	if not _texture_cache.has(path): _texture_cache[path]=load(path)
	return _texture_cache[path]


static func asset_paths() -> Array[String]:
	var result: Array[String] = []
	for value in ENTRIES:
		var entry: Dictionary=value
		for key in ["asset","prepared_asset"]:
			if entry.has(key):
				var path := ROOT+str(entry[key])
				if not result.has(path): result.append(path)
	return result
