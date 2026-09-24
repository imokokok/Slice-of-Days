extends RefCounted
## Pure cooking rules shared by the workbench and tests. The minigame never
## destroys a dish: imperfect timing changes the record and feedback instead.


static func heat_reading(value: float) -> Dictionary:
	var heat := clampf(value, 0.0, 1.0)
	if heat < 0.22:
		return {"id":"cold","label":"锅底安静","detail":"还没有听见油脂活动的声音。"}
	if heat < 0.40:
		return {"id":"warm","label":"温热","detail":"锅边有很轻的细响，适合柔软或易焦的材料。"}
	if heat <= 0.72:
		return {"id":"steady","label":"稳定滋响","detail":"热气均匀，锅里的味道正在慢慢合拢。"}
	if heat <= 0.86:
		return {"id":"hot","label":"火声变急","detail":"香气出来得很快，再久一点就会发苦。"}
	return {"id":"smoke","label":"锅边起烟","detail":"先把火收回来；这锅还有补救的余地。"}


static func prepared_token(token: Dictionary, option_id: String) -> Dictionary:
	var result := token.duplicate(true)
	for value in token.get("prep_options",[]):
		var option: Dictionary=value
		if str(option.get("id",""))!=option_id: continue
		var window: Array=token.get("heat_window",[0.40,0.70])
		if window.size()>=2:
			var low := float(window[0])
			var high := float(window[1])
			var shift := clampf(float(option.get("heat_shift",0.0)),-low,1.0-high)
			result["heat_window"]=[low+shift,high+shift]
		result["heat_drop"]=clampf(float(token.get("heat_drop",0.05))+float(option.get("heat_drop_delta",0.0)),0.0,0.25)
		result["pan_cue"]=str(option.get("pan_cue",token.get("pan_cue","")))
		result["prep_option"]=option_id
		break
	return result


static func preparation_action(option_id: String, token_id := "") -> Dictionary:
	if token_id=="bread" and option_id=="small":
		return {"verb":"撕开", "sound":"paper", "strokes":2}
	if option_id in ["squeeze","coat","edge","line","spoon","dot","ribbon"]:
		return {"verb":"挤压" if option_id=="squeeze" else "倒入", "sound":"water", "strokes":2}
	if option_id in ["large","tear","wring","sheets","strips","pieces","separate","bells","small_ball","long_thread"]:
		return {"verb":"撕开" if option_id in ["large","tear","sheets","strips","pieces"] else "拆开", "sound":"paper", "strokes":2}
	if option_id in ["drain","keep_brine","keep_juice","frosted","soften","gentle","ticking","sort","bundle","finish","pinch","flakes"]:
		return {"verb":"整理", "sound":"water" if option_id in ["drain","keep_brine","keep_juice","soften"] else "paper", "strokes":2}
	return {"verb":"切配", "sound":"cut", "strokes":3}


static func doneness(addition: Dictionary) -> Dictionary:
	var id := str(addition.get("id",""))
	var option := str(addition.get("prep_option",""))
	var progress := float(addition.get("cook_progress",0.0))
	var brown := float(addition.get("browning",0.0))
	var ready := 0.34
	if id in ["potato","carrot","beet"]: ready=0.48
	elif id in ["cheese","lemon","herbs","star_salt","cooking_oil","salt_shaker","wasabi","ketchup"]: ready=0.20
	elif id in ["sardine","sea_bream"]: ready=0.42
	if option in ["small","dice","chop","slices","crumbs","strips"]: ready-=0.05
	if option in ["thick","large","chunks","whole"]: ready+=0.06
	if brown>0.62 or progress>0.89: return {"id":"overdone","label":"过火","score":-3}
	if progress<ready: return {"id":"underdone","label":"尚生","score":-2}
	if brown>0.35: return {"id":"browned","label":"焦香","score":1}
	return {"id":"ready","label":"刚熟","score":2}


static func dish_doneness(additions: Array) -> Dictionary:
	var counts := {"underdone":0,"ready":0,"browned":0,"overdone":0}
	var score := 0
	var parts: Array[String]=[]
	for value in additions:
		var state: Dictionary=doneness(value)
		counts[state.id]+=1
		score+=int(state.score)
		parts.append("%s%s" % [str((value as Dictionary).get("label","食材")),str(state.label)])
	var summary := "、".join(parts)
	return {"counts":counts,"score":score,"summary":summary}


static func pan_moisture(additions: Array) -> float:
	var moisture := 0.0
	for value in additions:
		var addition: Dictionary=value
		var id := str(addition.get("id",""))
		if id in ["tomato","zucchini","eggplant","mushrooms","lemon","sea_beans","ice_block"]: moisture+=0.30
		elif id in ["bread","potato","star_salt","salt_shaker"]: moisture-=0.12
	return clampf(0.35+moisture,0.08,1.0)


static func cooking_grade(score: int, additions: Array) -> Dictionary:
	var doneness_data: Dictionary=dish_doneness(additions)
	var result := grade(score+mini(0,int(doneness_data.score)))
	var counts: Dictionary=doneness_data.counts
	if int(counts.underdone)>0 or int(counts.overdone)>0:
		if result.id=="attentive": result=grade(7)
		result["note"]="%s；这道菜仍然可以出餐，火候会写进菜谱。" % str(doneness_data.summary)
	return result


static func evaluate_addition(token: Dictionary, heat: float) -> Dictionary:
	var window: Array = token.get("heat_window", [0.40, 0.70])
	var low := float(window[0]) if window.size() >= 2 else 0.40
	var high := float(window[1]) if window.size() >= 2 else 0.70
	var label := str(token.get("label", "这份材料"))
	if heat >= low and heat <= high:
		return {
			"score":2,
			"state":"just_right",
			"message":"%s落进锅里，声音干净，香气没有被火赶跑。" % label,
		}
	if heat >= low - 0.14 and heat <= high + 0.14:
		return {
			"score":1,
			"state":"recoverable",
			"message":"%s下锅稍微早了些。下一步看住火，仍能把味道接回来。" % label if heat < low else "%s下锅时火声偏急。先收火，翻拌时还能补回来。" % label,
		}
	return {
		"score":0,
		"state":"rough",
		"message":"%s没有赶上最舒服的火候。别倒掉这锅，先调火再继续。" % label,
	}


static func advance_exposure(addition: Dictionary, heat: float, seconds: float) -> Dictionary:
	var result := addition.duplicate()
	var h := clampf(heat,0.0,1.0)
	var progress := float(result.get("cook_progress",0.0))
	var browning := float(result.get("browning",0.0))
	progress=clampf(progress+maxf(0.0,seconds)*maxf(0.0,h-0.16)*0.28,0.0,1.0)
	if progress>0.30 and h>0.62:
		browning=clampf(browning+maxf(0.0,seconds)*(h-0.62)*0.22,0.0,1.0)
	result["cook_progress"]=progress
	result["browning"]=browning
	return result


static func food_tint(id: String, state: String, progress: float, browning: float, heat: float) -> Color:
	var base := Color.WHITE
	var cooked := Color("c58e58")
	if id in ["tomato","beet","bell_pepper_red","bell_pepper_orange"]: cooked=Color("aa6348")
	elif id in ["herbs","zucchini","bell_pepper_green","sea_beans"]: cooked=Color("91a762")
	elif id in ["sardine","sea_bream","mushrooms","bread"]: cooked=Color("a8764e")
	elif id in ["cheese","lemon","bell_pepper_yellow"]: cooked=Color("dda95c")
	var warmed := clampf(progress*1.35+maxf(0.0,heat-0.55)*0.06,0.0,0.78)
	base=base.lerp(cooked,warmed)
	base=base.lerp(Color("70442d"),clampf(browning*0.70,0.0,0.58))
	if state=="recoverable": base=base.lerp(Color("cfaa82"),0.10)
	elif state=="rough": base=base.lerp(Color("aa775d"),0.22)
	return base


static func seasoning_target(tokens: Array) -> String:
	var salty := 0
	var rich := 0
	var bright := 0
	for token_value in tokens:
		var token: Dictionary = token_value
		var flavors: Array = token.get("flavors", [])
		if flavors.has("salty"): salty += 1
		if flavors.has("rich") or flavors.has("savory"): rich += 1
		if flavors.has("bright") or flavors.has("fresh"): bright += 1
	if salty > 0:
		return "rest"
	if rich >= 2 and bright == 0:
		return "brighten"
	return "salt"


static func tasting_note(tokens: Array) -> String:
	match seasoning_target(tokens):
		"rest": return "尝味：舌尖已经留下咸鲜，继续加会盖住材料本身。"
		"brighten": return "尝味：香气很厚，收口稍沉，一点亮味会让层次打开。"
		_: return "尝味：香气已经聚起来，但尾味还空着一点。"


static func evaluate_seasoning(tokens: Array, choice: String) -> Dictionary:
	var expected := seasoning_target(tokens)
	var labels := {"brighten":"提一点亮味","salt":"补一小撮盐","rest":"先停手，保留本味"}
	if choice == expected:
		return {"score":2,"state":"balanced","message":"尝过以后再决定，%s刚好把味道收住。" % str(labels.get(choice, choice))}
	return {"score":0,"state":"personal","message":"这不是最稳妥的调味，但它会作为你今天的做法被记下来。"}


static func evaluate_seasoning_layers(tokens: Array, layers: Array) -> Dictionary:
	if layers.is_empty(): return evaluate_seasoning(tokens,"rest")
	var target := seasoning_target(tokens)
	var salty := layers.count("salt")
	var bright := layers.count("wasabi")+layers.count("ketchup")+layers.count("herbs")
	var pepper := layers.count("pepper")
	var balanced := (target=="salt" and salty==1) or (target=="brighten" and bright>=1 and salty==0) or (target=="rest" and salty==0)
	if salty>1 or bright>2: return {"score":-1,"state":"strong","message":"调料叠得太重，盖住了一部分食材；这一次的分量会留在菜谱里。"}
	if balanced: return {"score":2 if layers.size()<=2 else 1,"state":"balanced","message":"尝过后分次调味，%s把这一锅的尾味接住了。" % ("辛香" if pepper>0 else "层次")}
	return {"score":0,"state":"personal","message":"这组调味留下了很个人的方向，客人会尝到你的选择。"}


static func grade(score: int) -> Dictionary:
	if score >= 10:
		return {"id":"attentive","label":"从容出锅","note":"每一步都回应了锅里的变化。"}
	if score >= 7:
		return {"id":"steady","label":"稳当成菜","note":"有一点临场调整，但味道已经接住。"}
	return {"id":"improvised","label":"带着临场痕迹","note":"它不完美，却完整留下了这次动手的过程。"}


static func service_response(interaction: Dictionary) -> String:
	var mechanic: Dictionary=interaction.get("mechanic",{})
	var additions: Array=mechanic.get("additions",[])
	var detail := ""
	var doneness_data: Dictionary=dish_doneness(additions)
	var counts: Dictionary=doneness_data.counts
	if int(counts.underdone)>0: detail="%s。还有材料略生，下次可以让它多受一会儿热。" % str(doneness_data.summary)
	elif int(counts.overdone)>0: detail="%s。边缘已经过火，下次可以早一点收火。" % str(doneness_data.summary)
	for addition_value in additions:
		if not detail.is_empty(): break
		var addition: Dictionary=addition_value
		if str(addition.get("state","")) not in ["rough","recoverable"]: continue
		var window: Array=addition.get("heat_window",[])
		if window.size()<2: continue
		var direction := "还没上来" if float(addition.get("heat",0.0))<float(window[0]) else "有些急"
		detail="「%s」下锅时锅温%s，你后来还是把这锅接住了。" % [str(addition.get("label","食材")),direction]
		break
	if detail.is_empty():
		var preparations: Array=mechanic.get("preparations",[])
		if not preparations.is_empty():
			var prep: Dictionary=preparations[0]
			detail="「%s」用了「%s」的做法，这一口我记住了。" % [str(prep.get("label","食材")),str(prep.get("option_label","认真处理"))]
	if detail.is_empty(): detail="这道菜有你自己的做法，我记住了。"
	var ending: String = {
		"space":"盘边留了空白，客人能先看清这一口。",
		"generous":"这一盘端上桌，像是认真招待忙完一天的人。",
		"share":"你分成小碟，每个等菜的人都有了自己的那一口。",
	}.get(str(mechanic.get("plating","")),"出餐的样子也值得留在菜谱里。")
	var seasoning_layers: Array=mechanic.get("seasoning_layers",[])
	var seasoning_echo := "调料分次撒入，味道有了几层。" if seasoning_layers.size()>1 else ""
	return "石泳琪端起盘子：「%s%s%s」" % [detail,seasoning_echo,ending]


static func recipe_notes(interaction: Dictionary) -> String:
	var mechanic: Dictionary = interaction.get("mechanic", {})
	var grade_data: Dictionary = mechanic.get("grade", {})
	var seasoning := str(mechanic.get("seasoning_label", "按尝味决定调味"))
	var plating := str(mechanic.get("plating_label", "趁热装盘"))
	var additions: Array=mechanic.get("additions",[])
	var addition_labels: Array[String]=[]
	for addition_value in additions:
		var addition: Dictionary=addition_value
		addition_labels.append(str(addition.get("label",addition.get("id","食材"))))
	if addition_labels.is_empty():
		for label in interaction.get("selected_labels",[]): addition_labels.append(str(label))
	var prep_lines: Array[String]=[]
	for prep_value in mechanic.get("preparations",[]):
		var prep: Dictionary=prep_value
		prep_lines.append("%s·%s" % [str(prep.get("label","食材")),str(prep.get("option_label","处理"))])
	var stir_labels: Array[String]=[]
	for stir_value in mechanic.get("stirs",[]):
		var stir: Dictionary=stir_value
		stir_labels.append(str(stir.get("style_label","翻拌")))
	return "备料：%s。\n下锅顺序：%s。\n熟度：%s。\n翻拌：%s；尝味后%s。\n装盘：%s。\n%s：%s\n%s" % [
		"、".join(prep_lines) if not prep_lines.is_empty() else "按食材分别处理",
		" → ".join(addition_labels),
		str(dish_doneness(additions).summary),
		"、".join(stir_labels) if not stir_labels.is_empty() else "%d 次" % int(mechanic.get("stir_count",0)),
		seasoning,
		plating,
		str(grade_data.get("label", "完成出餐")),
		str(grade_data.get("note", "这道菜留下了今天的火候。")),
		service_response(interaction),
	]
