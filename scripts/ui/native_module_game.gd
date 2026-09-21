extends Control

const SUPPORTED := ["cooking", "sound_sampling", "photography", "optical_illusion", "archives"]
const PAPER := Color("faf7ee")
const INK := Color("31658b")
const MUTED := Color("698594")
const TERRACOTTA := Color("31658b")
const SEA := Color("31658b")
const SAGE := Color("8caa87")
const GOLD := Color("eed577")
const BOARD := Rect2(42, 122, 920, 610)

var cooking_pan: Texture2D=preload("res://art/ui/enamel-cooking-pan.png")
var ingredient_art: Control
var module_id := ""
var prototype: Dictionary = {}
var interaction: Dictionary = {}
var selected_tokens: Array[String] = []
var token_buttons: Dictionary = {}
var choice_buttons: Dictionary = {}
var background_texture: Texture2D
var instruction_label: Label
var selection_label: Label
var status_label: Label
var primary_button: Button
var return_button: Button
var value_slider: HSlider
var value_label: Label
var stage_ready := false
var completed := false
var playback_active := false
var playback_cursor := 0.0


func _ready() -> void:
	module_id = GameplayModuleSystem.pending_module_id()
	if not SUPPORTED.has(module_id):
		call_deferred("_fail")
		return
	prototype = GameplayModuleSystem.prototype_for(module_id)
	interaction = prototype.get("interaction", {})
	var background_path := str(prototype.get("background_path", ""))
	if not background_path.is_empty() and ResourceLoader.exists(background_path):
		var loaded = load(background_path)
		if loaded is Texture2D:
			background_texture = loaded
	var atlas_pages := {"cooking":16,"sound_sampling":85,"photography":91,"optical_illusion":91,"archives":97}
	if atlas_pages.has(module_id):
		var first := int(atlas_pages[module_id])
		background_texture = preload("res://scripts/ui/scene_atlas.gd").plate({"pages":[first,first+1,first+2]})
	_build_theme()
	_build_ui()
	_update_state()
	WorldSound.set_active(true)
	WorldSound.set_location(GameState.current_location)
	set_process(module_id == "sound_sampling")
	queue_redraw()


func _build_theme() -> void:
	theme=preload("res://scripts/ui/components/interface_palette.gd").theme_for_tools()


func _build_ui() -> void:
	if module_id=="cooking":
		_build_cooking_ui()
		return
	var p=preload("res://scripts/ui/components/interface_palette.gd")
	p.words(self,str(prototype.get("title",module_id)),Vector2(70,40),1150,32)
	p.words(self,_eyebrow(),Vector2(72,91),1080,16,p.MUTED)
	var leave := _button(self,"暂时离开",Vector2(1290,45),Vector2(235,48),false)
	leave.pressed.connect(_return_or_cancel)
	var side := Control.new(); side.position=Vector2(975,155); side.size=Vector2(550,610); add_child(side)
	instruction_label=p.words(side,str(interaction.get("prompt","完成这段操作。")),Vector2(22,0),516,20)
	selection_label=p.words(side,"",Vector2(22,100),516,17)
	var tokens: Array=interaction.get("tokens",[])
	for index in tokens.size():
		var token: Dictionary=tokens[index]
		var id := str(token.id)
		var button := _button(side,_token_button_text(token),Vector2(22,175+index*45),Vector2(516,41),false)
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text=str(token.get("detail",""))
		button.pressed.connect(_toggle_token.bind(id))
		token_buttons[id]=button
	_build_module_control(side)
	primary_button.position=Vector2(325,416); primary_button.size.x=210
	var y := 520
	for choice in prototype.get("choices",[]):
		var id := str(choice.id)
		var button := _button(side,"%s · %d分钟" % [str(choice.get("label",id)),int(choice.get("cost",{}).get("minutes",0))],Vector2(22,y),Vector2(516,42),false)
		button.tooltip_text=str(choice.get("detail","")); button.pressed.connect(_confirm_choice.bind(id)); choice_buttons[id]=button
		y+=50
	status_label=p.words(self,_initial_status(),Vector2(72,804),1130,20)
	return_button=_button(self,"返回原空间",Vector2(1280,815),Vector2(245,48),false)
	return_button.pressed.connect(_return_or_cancel)
	if module_id=="archives":
		for i in 3:
			var note := p.words(self,"先从右侧取一份记录",Vector2(139+i*272,318+(i%2)*32),187,21)
			note.name="SourceNote"+str(i)

func _build_cooking_ui() -> void:
	var art = preload("res://scripts/ui/components/handmade_assets.gd")
	var p = preload("res://scripts/ui/components/interface_palette.gd")
	theme=p.theme_for_tools()
	p.words(self,"潮汐饭店 · 手边的料理",Vector2(70,40),1010,34)
	p.words(self,"取食材，调火候，把今天的味道留成一页。",Vector2(72,96),1100,20,p.MUTED)
	var book_button := _button(self,"翻开菜谱",Vector2(1175,48),Vector2(300,50),false)
	book_button.variant="quiet"; book_button.refresh(); book_button.pressed.connect(_open_recipe_book)
	art.picture(self,"worktop",Vector2(65,183),Vector2(820,455),true)
	art.picture(self,"recipe_book",Vector2(940,176),Vector2(592,426),true)
	instruction_label=p.words(self,"从下面取三样食材。\n\n先后顺序，也是一道菜的记忆。",Vector2(994,219),209,21)
	selection_label=p.words(self,"",Vector2(1256,218),230,19)
	ingredient_art=Control.new(); ingredient_art.mouse_filter=MOUSE_FILTER_IGNORE; add_child(ingredient_art)
	var tokens: Array=interaction.get("tokens",[])
	for i in tokens.size():
		var token: Dictionary=tokens[i]
		var b := preload("res://scripts/ui/components/handmade_item.gd").new()
		b.item_id=str(token.id); b.caption=str(token.label)
		b.position=Vector2(70+i*160,646); b.size=Vector2(142,141)
		b.name="Ingredient_"+str(token.id); b.pressed.connect(_toggle_token.bind(str(token.id)))
		token_buttons[str(token.id)]=b; add_child(b)
	var x := 986
	for choice in prototype.get("choices",[]):
		var id := str(choice.id)
		var b := _button(self,"即兴出餐" if id=="improvise" else "按菜谱出餐",Vector2(x,416),Vector2(224,46),false)
		b.variant="quiet"; b.refresh(); b.pressed.connect(_confirm_choice.bind(id)); choice_buttons[id]=b; x+=270
	value_label=p.words(self,"",Vector2(82,594),455,20)
	value_slider=HSlider.new(); value_slider.position=Vector2(80,555); value_slider.size=Vector2(480,27)
	value_slider.min_value=0; value_slider.max_value=1; value_slider.step=.01; value_slider.value=.58
	value_slider.value_changed.connect(_on_value_changed); add_child(value_slider)
	primary_button=_button(self,"拌匀 · 确认火候",Vector2(600,567),Vector2(294,52),false)
	primary_button.variant="quiet"; primary_button.refresh(); primary_button.pressed.connect(_perform_primary_action)
	status_label=p.words(self,"先从下方拿取三样食材。",Vector2(74,809),1190,20)
	return_button=_button(self,"离开料理台",Vector2(1310,815),Vector2(215,50),false)
	return_button.variant="quiet"; return_button.refresh(); return_button.pressed.connect(_return_or_cancel)
	token_buttons.values()[0].grab_focus()

func _open_recipe_book() -> void:
	if not get_tree().get_nodes_in_group("recipe_book").is_empty(): return
	var book := preload("res://scripts/ui/recipe_book_panel.gd").new()
	book.ingredients=selected_tokens.duplicate(); book.heat=value_slider.value
	book.follow_recipe.connect(func(recipe: Dictionary):
		selected_tokens.clear()
		for id in recipe.ingredients:
			if token_buttons.has(str(id)) and EconomySystem.ingredient_available(str(id)): selected_tokens.append(str(id))
		value_slider.value=float(recipe.heat); stage_ready=false
		instruction_label.text=str(recipe.title)+"\n\n"+str(recipe.notes).left(60)
		_update_state()
		status_label.text="正在照着「%s」做。%s" % [recipe.title,"还缺食材，先去采购或钓鱼。" if selected_tokens.size()<3 else "食材就位，可以调火候。"]
	)
	add_child(book)

func _build_module_control(parent: Control) -> void:
	value_label = _label(parent, "", Vector2(22, 414), Vector2(285, 28), 18, MUTED)
	primary_button = _button(parent, _primary_text(), Vector2(366, 416), Vector2(202, 48), true)
	primary_button.pressed.connect(_perform_primary_action)
	if module_id in ["cooking", "photography", "optical_illusion"]:
		value_slider = HSlider.new()
		value_slider.position = Vector2(22, 451)
		value_slider.size = Vector2(324, 34)
		value_slider.min_value = 0.0
		value_slider.max_value = 1.0
		value_slider.step = 0.01
		value_slider.value = 0.58 if module_id == "cooking" else (0.5 if module_id == "photography" else 0.0)
		value_slider.value_changed.connect(_on_value_changed)
		parent.add_child(value_slider)
	elif module_id == "sound_sampling":
		preload("res://scripts/ui/components/interface_palette.gd").words(parent,"片段按选择顺序播放，来源标记始终保留。",Vector2(22,454),280,17,MUTED)
	else:
		preload("res://scripts/ui/components/interface_palette.gd").words(parent,"保留来源；无法确认的地方，可以留下空格。",Vector2(22,454),280,17,MUTED)


func _toggle_token(token_id: String) -> void:
	if completed or playback_active:
		return
	if module_id == "cooking" and not EconomySystem.ingredient_available(token_id):
		status_label.text = LocalizationSystem.text("这份材料还没带到厨房，先去采购。")
		return
	if selected_tokens.has(token_id):
		selected_tokens.erase(token_id)
	else:
		var maximum := int(interaction.get("max_select", 1))
		if selected_tokens.size() >= maximum:
			status_label.text = LocalizationSystem.text("最多保留 %d 项。先取消一项，作品不会替你丢掉边界。" % maximum)
			return
		selected_tokens.append(token_id)
	stage_ready = false
	_update_state()


func _on_value_changed(_value: float) -> void:
	if completed:
		return
	stage_ready = false
	_update_state()


func _perform_primary_action() -> void:
	if completed or playback_active:
		return
	var minimum := int(interaction.get("min_select", 0))
	if selected_tokens.size() < minimum:
		status_label.text = LocalizationSystem.text("还需要选择 %d 项，才能完成这次操作。" % (minimum - selected_tokens.size()))
		return
	match module_id:
		"cooking":
			var heat := value_slider.value
			if heat < 0.42 or heat > 0.74:
				status_label.text = LocalizationSystem.text("火候还没有进入稳定区。让指针停在蓝色刻度之间。")
				return
			stage_ready = true
			status_label.text = LocalizationSystem.text("火候稳定，三样材料已经完成同一轮处理。现在决定怎样出餐。")
		"sound_sampling":
			playback_active = true
			playback_cursor = 0.0
			primary_button.disabled = true
			status_label.text = LocalizationSystem.text("正在试听这条短轨。来源标记与声音片段一起经过播放头……")
		"photography":
			var exposure := value_slider.value
			if exposure < 0.28 or exposure > 0.76:
				status_label.text = LocalizationSystem.text("高光或暗部已经失去细节。先把曝光调回可辨认范围。")
				return
			stage_ready = true
			WorldSound.play_detail(true)
			status_label.text = LocalizationSystem.text("快门落下。取景框内与框外的东西都还在，只是进入了不同记录。")
		"optical_illusion":
			if selected_tokens.size() != 2:
				status_label.text = LocalizationSystem.text("必须同时保留两份记录，才能寻找它们共同成立的角度。")
				return
			var target := _perspective_target()
			if absf(value_slider.value - target) > 0.055:
				status_label.text = LocalizationSystem.text("连接仍然断开。继续改变视角，让门框、楼梯和光线在同一投影中重合。")
				return
			stage_ready = true
			status_label.text = LocalizationSystem.text("两份矛盾记录在这个角度同时成立。空间没有被纠正，但连接已经出现。")
		"archives":
			stage_ready = true
			var has_time_link := selected_tokens.has("tide_log") and selected_tokens.has("station_ticket")
			var has_sound_link := selected_tokens.has("voice_catalog") and (selected_tokens.has("bus_manifest") or selected_tokens.has("station_ticket"))
			status_label.text = LocalizationSystem.text("来源和地点形成了可复查连接，可以建立交叉索引。" if has_time_link or has_sound_link else "三份记录仍缺少可靠连接。可以明确标出缺口，不必猜测补齐。")
	WorldSound.play_detail(true)
	_update_state()


func _process(delta: float) -> void:
	if not playback_active:
		return
	playback_cursor += delta / 2.4
	if playback_cursor >= 1.0:
		playback_cursor = 1.0
		playback_active = false
		stage_ready = true
		status_label.text = LocalizationSystem.text("试听完成。现在可以交付有授权的版本，或把边界不明的片段留作私人采样。")
	_update_state()
	queue_redraw()


func _update_state() -> void:
	if is_instance_valid(ingredient_art):
		for old in ingredient_art.get_children(): ingredient_art.remove_child(old); old.queue_free()
		for index in selected_tokens.size():
			var sketch := preload("res://scripts/ui/goods_sketch.gd").new(); sketch.item_id=selected_tokens[index]
			var angle := -PI*.8+index*PI*.6
			sketch.position=Vector2(348,330)+Vector2(cos(angle),sin(angle))*59; sketch.size=Vector2(115,106); ingredient_art.add_child(sketch)
	var minimum := int(interaction.get("min_select", 0))
	var labels: Array[String] = []
	for token_id in selected_tokens:
		labels.append(_token_label(token_id))
	var joiner := " → " if str(interaction.get("mode", "toggle")) == "ordered" else "、"
	selection_label.text = LocalizationSystem.text("当前：%s" % joiner.join(labels) if not labels.is_empty() else "尚未选择 · 至少 %d 项" % minimum)
	for token_id in token_buttons:
		_style_button(token_buttons[token_id], selected_tokens.has(str(token_id)))
		token_buttons[token_id].disabled = completed or playback_active
		if module_id == "cooking":
			token_buttons[token_id].disabled = completed or not EconomySystem.ingredient_available(str(token_id))
	_update_module_value()
	primary_button.disabled = completed or playback_active or selected_tokens.size() < minimum
	var record := _interaction_record()
	for choice_id in choice_buttons:
		var check := GameplayModuleSystem.choice_interaction_check(module_id, str(choice_id), record)
		choice_buttons[choice_id].disabled = completed or not stage_ready or not bool(check.get("ok", false))
		if not bool(check.get("ok", false)):
			choice_buttons[choice_id].tooltip_text = LocalizationSystem.text(str(check.get("message", "当前素材不符合这个结果。")))
	queue_redraw()


func _update_module_value() -> void:
	if value_label == null:
		return
	match module_id:
		"cooking":
			var heat := value_slider.value
			value_label.text = LocalizationSystem.text("火候 %d%% · %s" % [roundi(heat * 100), "稳定" if heat >= 0.42 and heat <= 0.74 else "需要调整"])
		"sound_sampling":
			value_label.text = LocalizationSystem.text("试听进度 %d%%" % roundi(playback_cursor * 100))
		"photography":
			value_label.text = LocalizationSystem.text("曝光 %+d · %s" % [roundi((value_slider.value - 0.5) * 200), "细节可辨" if value_slider.value >= 0.28 and value_slider.value <= 0.76 else "细节丢失"])
		"optical_illusion":
			value_label.text = LocalizationSystem.text("观察角度 %d° · %s" % [roundi(value_slider.value * 90), "连接成立" if stage_ready else "目标投影尚未标注"])
		"archives":
			value_label.text = LocalizationSystem.text("已展开 %d / 3 份来源记录" % selected_tokens.size())


func _confirm_choice(choice_id: String) -> void:
	if completed or not stage_ready: return
	for choice in prototype.get("choices",[]):
		if str(choice.get("id",""))!=choice_id: continue
		var cost: Dictionary=EconomySystem.cooking_cost(choice.get("cost",{})) if module_id=="cooking" else choice.get("cost",{})
		var sheet := preload("res://scripts/ui/components/confirm_sheet.gd").new()
		sheet.heading=str(choice.get("label","完成这段经历"))
		sheet.description="这段操作需要 %d 分钟。\n\n%s" % [int(cost.get("minutes",0)),"将使用选中的真实食材，并留下今天的出餐记录。" if module_id=="cooking" else str(choice.get("detail","完成后将留下对应的经历与材料。"))]
		sheet.confirm_text="确认"; add_child(sheet)
		sheet.accepted.connect(func() -> void: _complete_choice(choice_id); sheet.queue_free())
		return

func _complete_choice(choice_id: String) -> void:
	if completed or not stage_ready:
		return
	var rollback_snapshot := GameState.to_save_data().duplicate(true)
	var result := GameplayModuleSystem.complete_choice(choice_id, _interaction_record())
	status_label.text = LocalizationSystem.text(str(result.get("message", "")))
	if not bool(result.get("ok", false)):
		return
	if module_id == "cooking": status_label.text += LocalizationSystem.text("\n材料已实际用掉，出餐和工资记在今天的工作记录里。")
	completed = true
	if not SaveManager.save_or_report("玩法结果保存失败"):
		GameState.load_save_data(rollback_snapshot)
		completed = false
		status_label.text = LocalizationSystem.text("存档写入失败，本次提交尚未生效；可以重试。")
		return
	return_button.text = LocalizationSystem.text("带着结果返回")
	_update_state()


func _interaction_record() -> Dictionary:
	return {
		"mode": str(interaction.get("mode", "toggle")),
		"selected_tokens": selected_tokens.duplicate(),
		"selected_labels": selected_tokens.map(func(token_id: String) -> String: return _token_label(token_id)),
		"mechanic": {
			"heat": value_slider.value if module_id == "cooking" else null,
			"exposure": value_slider.value if module_id == "photography" else null,
			"view_angle": value_slider.value if module_id == "optical_illusion" else null,
			"auditioned": stage_ready if module_id == "sound_sampling" else null,
			"archive_reviewed": stage_ready if module_id == "archives" else null,
		},
	}


func _return_or_cancel() -> void:
	if not GameplayModuleSystem.pending_module_id().is_empty():
		GameplayModuleSystem.cancel_session()
	if not SaveManager.save_or_report("退出玩法后保存失败"):
		status_label.text = LocalizationSystem.text("状态已撤销，但存档写入失败。")
		return
	SceneRouter.return_from_gameplay()


func _fail() -> void:
	push_error("Native gameplay scene received unsupported module: %s" % module_id)
	GameplayModuleSystem.cancel_session()
	SceneRouter.return_from_gameplay()


func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().get_nodes_in_group("recipe_book").is_empty(): return
	if not get_tree().get_nodes_in_group("native_confirmation").is_empty(): return
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.keycode >= KEY_1 and event.keycode <= KEY_5:
		var index := int(event.keycode - KEY_1)
		var tokens: Array = interaction.get("tokens", [])
		if index < tokens.size():
			_toggle_token(str(tokens[index].get("id", "")))
	elif event.is_action_pressed("restart_module"):
		_perform_primary_action()
	elif event.is_action_pressed("ui_cancel"):
		_return_or_cancel()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("f4f1e6"))
	if module_id=="cooking": return
	var art=preload("res://scripts/ui/components/handmade_assets.gd")
	match module_id:
		"sound_sampling":
			draw_texture_rect(art.texture("tape_workstation"),Rect2(64,170,854,565),false)
			_draw_sound()
		"photography":
			if background_texture: draw_texture_rect(background_texture,Rect2(177,269,634,361),false)
			draw_texture_rect(art.texture("photo_mat"),Rect2(67,154,865,575),false)
			_draw_photography()
		"optical_illusion":
			draw_texture_rect(art.texture("window_frame"),Rect2(84,155,826,576),false)
			_draw_perspective()
		"archives": _draw_archives()

func _draw_sound() -> void:
	# Waveforms are an abstract visualization; cursor follows actual audition time.
	for track in 3:
		var y := 338.0+track*74
		draw_line(Vector2(178,y),Vector2(806,y),Color(SEA,.16),1)
		if track<selected_tokens.size():
			var unsafe := selected_tokens[track] in ["cafe_cups","old_hinge"]
			for wave in 40:
				var x := 185+wave*15.5
				var height := 5.0+absf(sin(float(wave*3+track)))*19.0
				draw_line(Vector2(x,y-height),Vector2(x,y+height),Color(GOLD if unsafe else SEA,.8),2)
	if playback_active or playback_cursor>0:
		var x := lerpf(177,807,playback_cursor)
		draw_line(Vector2(x,310),Vector2(x,520),GOLD,3)

func _draw_photography() -> void:
	var frame := Rect2(187,275,610,345)
	for third in [1,2]:
		draw_line(frame.position+Vector2(frame.size.x*third/3,0),frame.position+Vector2(frame.size.x*third/3,frame.size.y),Color(PAPER,.35),1)
	var anchors := {"reflection":Vector2(274,375),"people":Vector2(460,507),"sea_edge":Vector2(678,320),"empty_chair":Vector2(695,552)}
	for token_id in selected_tokens:
		if anchors.has(token_id):
			var point: Vector2=anchors[token_id]
			draw_arc(point,24,0,TAU,28,GOLD,3,true)
	var exposure := value_slider.value if value_slider!=null else .5
	draw_rect(frame,Color(1,.94,.78,absf(exposure-.5)*.72))

func _draw_perspective() -> void:
	var angle := value_slider.value if value_slider != null else 0.0
	var shift := lerpf(-150, 150, angle)
	var origin := Vector2(500, 420)
	var corners := [Vector2(170, 205), Vector2(830, 205), Vector2(830, 640), Vector2(170, 640)]
	for corner in corners:
		draw_line(origin, corner, Color(PAPER, 0.55), 3)
	draw_polyline(PackedVector2Array([Vector2(270 + shift, 300), Vector2(455 + shift, 300), Vector2(455 + shift, 520), Vector2(270 + shift, 520), Vector2(270 + shift, 300)]), SEA, 7)
	draw_polyline(PackedVector2Array([Vector2(545 - shift, 520), Vector2(730 - shift, 520), Vector2(730 - shift, 300), Vector2(545 - shift, 300), Vector2(545 - shift, 520)]), TERRACOTTA, 7)
	for step in 6:
		var start := Vector2(375 + shift * 0.35 + step * 45, 575 - step * 38)
		draw_line(start, start + Vector2(120, 0), Color(GOLD, 0.9), 7)
	var target := _perspective_target()
	if selected_tokens.size() == 2 and absf(angle - target) <= 0.055:
		draw_circle(origin, 34, Color(GOLD, 0.65))
		draw_circle(origin, 12, PAPER)


func _draw_archives() -> void:
	var art=preload("res://scripts/ui/components/handmade_assets.gd")
	for i in 3:
		var card := Rect2(98+i*272,213+(i%2)*32,255,432)
		draw_texture_rect(art.texture("archive_sheet"),card,false)
		var note := get_node_or_null("SourceNote"+str(i)) as Label
		if note:
			note.text="先从右侧取一份记录"
			if i<selected_tokens.size():
				var id := selected_tokens[i]
				note.text=_token_label(id)+"\n\n"
				for token in interaction.get("tokens",[]):
					if str(token.id)==id: note.text+=str(token.get("detail",""))
		if i<selected_tokens.size():
			draw_line(card.position+Vector2(44,card.size.y-35),card.position+Vector2(card.size.x-38,card.size.y-35),GOLD,3,true)

func _perspective_target() -> float:
	if selected_tokens.has("photo_door") and selected_tokens.has("map_door"):
		return 0.35
	if selected_tokens.has("note_stairs") and selected_tokens.has("model_stairs"):
		return 0.72
	return 0.54


func _token_label(token_id: String) -> String:
	for token in interaction.get("tokens", []):
		if str(token.get("id", "")) == token_id:
			return str(token.get("label", token_id))
	return token_id


func _token_button_text(token: Dictionary) -> String:
	var label := str(token.get("label", "素材"))
	if module_id == "cooking":
		var count := int(GameState.inventory.get(str(token.get("id", "")), 0))
		if count > 0:
			return "%s\n随身 %d" % [label, count]
	if module_id == "sound_sampling":
		return ("△  " if str(token.get("id", "")) in ["cafe_cups", "old_hinge"] else "✓  ") + label
	return label


func _eyebrow() -> String:
	return {
		"cooking": "RESTAURANT / PREP & HEAT",
		"sound_sampling": "RECORDS / SOURCE & TIMELINE",
		"photography": "PHOTO / FRAME & EXPOSURE",
		"optical_illusion": "STATION / PERSPECTIVE",
		"archives": "LIBRARY / CROSS INDEX",
	}.get(module_id, "SOLMERE / WORKBENCH")


func _primary_text() -> String:
	return {
		"cooking": "确认火候",
		"sound_sampling": "试听短轨",
		"photography": "按下快门",
		"optical_illusion": "锁定视角",
		"archives": "核对三份来源",
	}.get(module_id, "完成操作")


func _initial_status() -> String:
	return {
		"cooking": "先挑三样材料，再调整火候。菜名不是第一步，先让今天的剩料能够一起工作。",
		"sound_sampling": "绿色标记可用于交付；三角标记含未授权人声或来源不明，只能进入私人版本。",
		"photography": "选择画面中的两到三处关系，再调整曝光。取景框之外仍然属于这个地方。",
		"optical_illusion": "选择两份矛盾记录，拖动观察角度。正确答案不是删掉其中一份。",
		"archives": "展开三份来源不同的记录。可靠连接可以进入公共索引，证据不足也可以明确保留空格。",
	}.get(module_id, "完成这段操作。")


func _board_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e6eff0")
	style.border_color = Color(INK, 0.35)
	style.set_border_width_all(0)
	style.set_corner_radius_all(14)
	return style


func _panel(parent: Node, at: Vector2, panel_size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(0)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(INK, 0.18)
	style.shadow_size = 0
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _label(parent: Node, text_value: String, at: Vector2, label_size: Vector2, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = LocalizationSystem.text(text_value)
	label.position = at
	label.size = label_size
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text_value: String, at: Vector2, button_size: Vector2, primary: bool) -> Button:
	var button := preload("res://scripts/ui/components/solmere_button.gd").new()
	button.variant="quiet"
	button.text = LocalizationSystem.text(text_value)
	button.position = at
	button.size = button_size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	_style_button(button, primary)
	return button


func _style_button(button: Button, selected_or_primary: bool) -> void:
	button.selected=selected_or_primary
