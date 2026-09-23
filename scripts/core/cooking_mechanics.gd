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


static func grade(score: int) -> Dictionary:
	if score >= 10:
		return {"id":"attentive","label":"从容出锅","note":"每一步都回应了锅里的变化。"}
	if score >= 7:
		return {"id":"steady","label":"稳当成菜","note":"有一点临场调整，但味道已经接住。"}
	return {"id":"improvised","label":"带着临场痕迹","note":"它不完美，却完整留下了这次动手的过程。"}


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
	return "备料：%s。\n下锅顺序：%s。\n翻拌：%s；尝味后%s。\n装盘：%s。\n%s：%s" % [
		"、".join(prep_lines) if not prep_lines.is_empty() else "按食材分别处理",
		" → ".join(addition_labels),
		"、".join(stir_labels) if not stir_labels.is_empty() else "%d 次" % int(mechanic.get("stir_count",0)),
		seasoning,
		plating,
		str(grade_data.get("label", "完成出餐")),
		str(grade_data.get("note", "这道菜留下了今天的火候。")),
	]
