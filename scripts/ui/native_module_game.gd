extends Control

const SUPPORTED := ["cooking", "photography", "optical_illusion", "archives"]
const PAPER := Color("faf7ee")
const INK := Color("405653")
const MUTED := Color("6a7162")
const TERRACOTTA := Color("946748")
const SEA := Color("58736a")
const SAGE := Color("8caa87")
const GOLD := Color("eed577")
const BOARD := Rect2(42, 122, 920, 610)
const COOKING = preload("res://scripts/core/cooking_mechanics.gd")
const SUPPLIED_KITCHEN_ART = preload("res://scripts/ui/components/kitchen_art_catalog.gd")

var cooking_pan: Texture2D=preload("res://art/ui/enamel-cooking-pan.png")
var illustrated_pot: Button
var plated_dish: Control
var cooking_heat_guide: Control
var cooking_prep_detail_label: Label
var active_recipe: Dictionary = {}
var ingredient_art: Control
var prep_board: Button
var module_id := ""
var session_context: Dictionary = {}
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
var cooking_phase := "select"
var prepared_tokens: Array[String] = []
var cooking_preps: Array[Dictionary] = []
var added_tokens: Array[String] = []
var cooking_additions: Array[Dictionary] = []
var cooking_stirs: Array[Dictionary] = []
var cooking_score := 0
var pending_ingredient := ""
var seasoning_choice := ""
var seasoning_label := ""
var seasoning_layers: Array[String] = []
var simmer_button: Button
var plating_choice := ""
var plating_label := ""
var cooking_phase_label: Label
var cooking_history_label: Label
var cooking_reset_button: Button
var prep_option_buttons: Array[Button] = []
var stir_buttons: Dictionary = {}
var seasoning_buttons: Dictionary = {}
var plating_buttons: Dictionary = {}
var cooking_feedback: Control
var ingredient_pages: Array[Dictionary] = []
var ingredient_page := 0
var ingredient_page_label: Label
var ingredient_previous_button: Button
var ingredient_next_button: Button
var plating_preview_choice := "space"
var pending_prep_option := -1
var fire_player: AudioStreamPlayer
var fire_notice:=0.0
var cooking_tick := 0.0


func _ready() -> void:
	module_id = GameplayModuleSystem.pending_module_id()
	session_context=GameplayModuleSystem.session_context()
	if not SUPPORTED.has(module_id) or str(session_context.get("current_character",""))!=GameState.current_role:
		call_deferred("_fail")
		return
	prototype = GameplayModuleSystem.prototype_for(module_id)
	interaction = prototype.get("interaction", {})
	if module_id=="cooking":
		interaction["tokens"]=SUPPLIED_KITCHEN_ART.append_to(interaction.get("tokens",[]))
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
	var p = preload("res://scripts/ui/components/interface_palette.gd")
	theme=p.theme_for_tools()
	p.words(self,"潮汐饭店 · 手边的料理",Vector2(70,40),1010,34)
	_panel(self,Vector2(70,94),Vector2(1018,44),Color("fff3dc"),Color("fff3dc")).name="KitchenTopHint"
	instruction_label=p.words(self,"从下面取三样食材。",Vector2(88,102),984,18)
	instruction_label.mouse_filter=Control.MOUSE_FILTER_STOP
	var book_button := _button(self,"查看菜谱",Vector2(1125,48),Vector2(210,50),false)
	book_button.variant="quiet"; book_button.refresh(); book_button.pressed.connect(_open_recipe_book)
	cooking_reset_button=_button(self,"重新开始",Vector2(1350,48),Vector2(155,50),false)
	cooking_reset_button.variant="quiet"; cooking_reset_button.refresh(); cooking_reset_button.pressed.connect(_reset_cooking)
	cooking_phase_label=p.words(self,"",Vector2(72,146),1050,17,p.MUTED)
	prep_board=preload("res://scripts/ui/components/cooking_board.gd").new()
	prep_board.position=Vector2(66,247); prep_board.size=Vector2(388,266); add_child(prep_board)
	prep_board.prepared.connect(_finish_board_prep)
	prep_board.stroke.connect(func(id: String, done: int, needed: int):
		status_label.text=LocalizationSystem.text("%s · %s，第 %d / %d 下；案板上的形态正在改变。" % [_token_label(id),str(prep_board.action_verb),done,needed]))
	illustrated_pot=preload("res://scripts/ui/components/cooking_pot.gd").new()
	illustrated_pot.position=Vector2(480,170); illustrated_pot.size=Vector2(422,390); add_child(illustrated_pot)
	illustrated_pot.pressed.connect(_use_cooking_pot)
	if preload("res://scripts/ui/production_assets.gd").available("kitchen_salt"):
		preload("res://scripts/ui/production_assets.gd").picture(self,"kitchen_salt",Vector2(312,174),Vector2(56,76))
	_kitchen_picture(5,Vector2(75,158),Vector2(184,115))
	cooking_feedback=preload("res://scripts/ui/cooking_pan_feedback.gd").new()
	cooking_feedback.position=Vector2(480,170); cooking_feedback.size=Vector2(422,390); cooking_feedback.layered_pot=is_instance_valid(illustrated_pot); add_child(cooking_feedback)
	plated_dish=preload("res://scripts/ui/components/cooking_plate.gd").new()
	plated_dish.position=Vector2(480,170); plated_dish.size=Vector2(422,390); plated_dish.visible=false; add_child(plated_dish)
	_panel(self,Vector2(940,176),Vector2(592,426),Color("eedac4"),Color("eedac4")).name="KitchenToolTray"
	p.words(self,"手边操作",Vector2(974,204),520,22,p.MUTED)
	selection_label=p.words(self,"",Vector2(974,247),528,19)
	cooking_history_label=p.words(self,"",Vector2(974,304),528,17,p.MUTED)
	ingredient_art=Control.new(); ingredient_art.mouse_filter=MOUSE_FILTER_IGNORE; add_child(ingredient_art)
	var tokens: Array=interaction.get("tokens",[])
	_build_ingredient_pages(tokens)
	ingredient_previous_button=_button(self,"上一架",Vector2(1222,623),Vector2(118,34),false)
	ingredient_previous_button.variant="quiet"; ingredient_previous_button.refresh(); ingredient_previous_button.pressed.connect(_change_ingredient_page.bind(-1))
	ingredient_page_label=p.words(self,"",Vector2(930,629),278,17,p.MUTED)
	ingredient_page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	ingredient_next_button=_button(self,"下一架",Vector2(1350,623),Vector2(118,34),false)
	ingredient_next_button.variant="quiet"; ingredient_next_button.refresh(); ingredient_next_button.pressed.connect(_change_ingredient_page.bind(1))
	for i in tokens.size():
		var token: Dictionary=tokens[i]
		var b := preload("res://scripts/ui/components/handmade_item.gd").new()
		b.item_id=str(token.id); b.caption=str(token.label)
		b.position=Vector2(70+(i%8)*180,658); b.size=Vector2(142,139)
		b.name="Ingredient_"+str(token.id); b.pressed.connect(_toggle_token.bind(str(token.id)))
		token_buttons[str(token.id)]=b; add_child(b)
	for i in 2:
		var prep_button := _button(self,"备料方式",Vector2(974+i*264,482),Vector2(250,42),false)
		prep_button.variant="quiet"; prep_button.refresh(); prep_button.pressed.connect(_choose_prep_option.bind(i))
		prep_button.mouse_entered.connect(_preview_prep_option.bind(i))
		prep_button.focus_entered.connect(_preview_prep_option.bind(i))
		prep_option_buttons.append(prep_button)
	cooking_prep_detail_label=p.words(self,"",Vector2(989,535),488,16,p.MUTED)
	var stir_data := [["gentle","轻推锅底"],["fold","翻起拌匀"]]
	for i in stir_data.size():
		var stir_id := str(stir_data[i][0])
		var stir_button := _button(self,str(stir_data[i][1]),Vector2(974+i*264,482),Vector2(250,42),false)
		stir_button.variant="quiet"; stir_button.refresh(); stir_button.pressed.connect(_stir.bind(stir_id))
		stir_buttons[stir_id]=stir_button
	var seasoning_data := [["salt","撒盐","salt_shaker"],["pepper","磨椒","pepper_grinder"],["wasabi","挤芥末","wasabi"],["ketchup","挤番茄酱","ketchup"],["herbs","撒香草","herbs"]]
	for i in seasoning_data.size():
		var seasoning_id := str(seasoning_data[i][0])
		var seasoning_button := _button(self,str(seasoning_data[i][1]),Vector2(974+(i%3)*174,482+floori(i/3.0)*47),Vector2(164,42),false)
		var seasoning_art_id := str(seasoning_data[i][2])
		if not seasoning_art_id.is_empty():
			seasoning_button.icon=preload("res://scripts/ui/components/cooking_ingredients.gd").texture(seasoning_art_id)
			seasoning_button.expand_icon=true
			seasoning_button.add_theme_constant_override("icon_max_width",28)
		seasoning_button.variant="quiet"; seasoning_button.refresh(); seasoning_button.pressed.connect(_choose_seasoning.bind(seasoning_id))
		seasoning_buttons[seasoning_id]=seasoning_button
	var plating_data := [["space","留一点空白"],["generous","堆得丰盛"],["share","分成小碟"]]
	for i in plating_data.size():
		var plating_id := str(plating_data[i][0])
		var plating_button := _button(self,str(plating_data[i][1]),Vector2(974+i*174,482),Vector2(164,42),false)
		plating_button.variant="quiet"; plating_button.refresh(); plating_button.pressed.connect(_choose_plating.bind(plating_id))
		plating_button.mouse_entered.connect(_preview_plating.bind(plating_id))
		plating_button.focus_entered.connect(_preview_plating.bind(plating_id))
		plating_buttons[plating_id]=plating_button
	var x := 986
	for choice in prototype.get("choices",[]):
		var id := str(choice.id)
		var b := _button(self,"即兴出餐" if id=="improvise" else "按菜谱出餐",Vector2(x,538),Vector2(224,46),false)
		b.variant="quiet"; b.refresh(); b.pressed.connect(_confirm_choice.bind(id)); choice_buttons[id]=b; x+=270
	value_label=p.words(self,"",Vector2(82,564),480,18)
	value_slider=HSlider.new(); value_slider.position=Vector2(80,518); value_slider.size=Vector2(480,27)
	value_slider.min_value=0; value_slider.max_value=1; value_slider.step=.01; value_slider.value=.58
	value_slider.value_changed.connect(_on_value_changed); add_child(value_slider)
	cooking_heat_guide=preload("res://scripts/ui/components/cooking_heat_guide.gd").new()
	cooking_heat_guide.position=Vector2(81,545); cooking_heat_guide.size=Vector2(478,12); add_child(cooking_heat_guide)
	primary_button=_button(self,"开始备料",Vector2(600,567),Vector2(294,52),false)
	primary_button.variant="quiet"; primary_button.refresh(); primary_button.pressed.connect(_perform_primary_action)
	simmer_button=_button(self,"再煮一会儿 · 2 拍",Vector2(480,567),Vector2(204,52),false)
	simmer_button.variant="quiet"; simmer_button.refresh(); simmer_button.pressed.connect(_simmer_cooking)
	status_label=p.words(self,"先从下方拿取三样食材。",Vector2(74,809),1190,20)
	return_button=_button(self,"离开料理台",Vector2(1310,815),Vector2(215,50),false)
	return_button.variant="quiet"; return_button.refresh(); return_button.pressed.connect(_return_or_cancel)
	token_buttons.values()[0].grab_focus()

func _kitchen_picture(index: int, at: Vector2, extent: Vector2) -> void:
	var atlas := AtlasTexture.new(); atlas.atlas=preload("res://art/ui/pocket_doodles/kitchen_objects.png")
	atlas.region=Rect2((index%3)*512,floori(index/3.0)*512,512,512)
	var picture := TextureRect.new(); picture.texture=atlas; picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.position=at; picture.size=extent; picture.mouse_filter=MOUSE_FILTER_IGNORE; add_child(picture)


func _build_ingredient_pages(tokens: Array) -> void:
	ingredient_pages.clear()
	var shelf_order: Array[String]=[]
	var shelves: Dictionary={}
	for value in tokens:
		var token: Dictionary=value
		var shelf := str(token.get("shelf","常备食材"))
		if not shelves.has(shelf):
			shelf_order.append(shelf)
			shelves[shelf]=[]
		(shelves[shelf] as Array).append(str(token.get("id","")))
	for shelf in shelf_order:
		var ids: Array=shelves[shelf]
		var pages_in_shelf := ceili(ids.size()/8.0)
		for local_page in pages_in_shelf:
			var begin := local_page*8
			ingredient_pages.append({
				"label":shelf,
				"local_page":local_page+1,
				"local_total":pages_in_shelf,
				"ids":ids.slice(begin,mini(begin+8,ids.size())),
			})
	ingredient_page=clampi(ingredient_page,0,maxi(0,ingredient_pages.size()-1))


func _change_ingredient_page(direction: int) -> void:
	if cooking_phase!="select" or ingredient_pages.is_empty(): return
	ingredient_page=clampi(ingredient_page+direction,0,ingredient_pages.size()-1)
	_refresh_ingredient_shelf()
	for token_id in _visible_ingredient_ids():
		var button: Button=token_buttons.get(token_id)
		if is_instance_valid(button) and not button.disabled:
			button.grab_focus()
			break


func _visible_ingredient_ids() -> Array[String]:
	var result: Array[String]=[]
	if module_id!="cooking": return result
	if cooking_phase!="select":
		result.assign(selected_tokens)
	elif not ingredient_pages.is_empty():
		for id in ingredient_pages[ingredient_page].ids: result.append(str(id))
	return result


func _refresh_ingredient_shelf() -> void:
	if module_id!="cooking" or not is_instance_valid(ingredient_page_label): return
	for button in token_buttons.values(): button.visible=false
	var visible_ids := _visible_ingredient_ids()
	for i in visible_ids.size():
		var button: Button=token_buttons.get(visible_ids[i])
		if not is_instance_valid(button): continue
		button.position=Vector2(70+i*180,658)
		button.visible=true
	var browsing := cooking_phase=="select"
	ingredient_previous_button.visible=browsing
	ingredient_next_button.visible=browsing
	if browsing and not ingredient_pages.is_empty():
		var page: Dictionary=ingredient_pages[ingredient_page]
		var suffix := " · %d/%d" % [int(page.local_page),int(page.local_total)] if int(page.local_total)>1 else ""
		ingredient_page_label.text=LocalizationSystem.text("%s%s　整架 %d/%d" % [str(page.label),suffix,ingredient_page+1,ingredient_pages.size()])
		ingredient_previous_button.disabled=ingredient_page<=0
		ingredient_next_button.disabled=ingredient_page>=ingredient_pages.size()-1
	else:
		ingredient_page_label.text=LocalizationSystem.text("本锅三样 · 下锅顺序可改")

func _open_recipe_book() -> void:
	if not get_tree().get_nodes_in_group("recipe_book").is_empty(): return
	var book := preload("res://scripts/ui/recipe_book_panel.gd").new()
	book.ingredients=selected_tokens.duplicate(); book.heat=value_slider.value
	book.follow_recipe.connect(func(recipe: Dictionary):
		_reset_cooking(false)
		active_recipe=recipe.duplicate(true)
		selected_tokens.clear()
		for id in recipe.ingredients:
			if token_buttons.has(str(id)) and EconomySystem.ingredient_available(str(id)): selected_tokens.append(str(id))
		value_slider.value=float(recipe.heat); stage_ready=false; cooking_phase="select"
		_update_state()
		status_label.text=LocalizationSystem.text("正在照着「%s」做。%s" % [LocalizationSystem.text(recipe.title),LocalizationSystem.text("还缺食材，先去采购或钓鱼。" if selected_tokens.size()<3 else "食材齐了，先从备料开始。")])
	)
	add_child(book)


func _reset_cooking(refresh := true) -> void:
	if module_id!="cooking" or completed: return
	cooking_phase="select"
	prepared_tokens.clear(); cooking_preps.clear(); added_tokens.clear(); cooking_additions.clear(); cooking_stirs.clear()
	pending_prep_option=-1; cooking_tick=0.0
	if is_instance_valid(prep_board): prep_board.clear_target()
	cooking_score=0; pending_ingredient=""; seasoning_choice=""; seasoning_label=""; seasoning_layers.clear(); plating_choice=""; plating_label=""; stage_ready=false
	active_recipe.clear()
	plating_preview_choice="space"
	if is_instance_valid(value_slider): value_slider.value=.58
	status_label.text=LocalizationSystem.text("还没有消耗任何食材。可以重新挑三样，顺序会决定下锅顺序。")
	if refresh: _update_state()


func _process(delta: float) -> void:
	_update_fire_sound(delta)
	if module_id!="cooking" or completed or cooking_phase not in ["cook","stir"] or added_tokens.is_empty(): return
	cooking_tick+=delta
	if cooking_tick<0.16: return
	_advance_food_heat(cooking_tick)
	cooking_tick=0.0
	if is_instance_valid(illustrated_pot):
		illustrated_pot.update_recipe(added_tokens,_preparation_visuals(),float(value_slider.value),cooking_phase,cooking_additions,seasoning_layers)
	_refresh_cooking_history()


func _advance_food_heat(seconds: float) -> void:
	for i in cooking_additions.size():
		cooking_additions[i]=COOKING.advance_exposure(cooking_additions[i],float(value_slider.value),seconds)

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
	else:
		preload("res://scripts/ui/components/interface_palette.gd").words(parent,"保留来源；无法确认的地方，可以留下空格。",Vector2(22,454),280,17,MUTED)


func _toggle_token(token_id: String) -> void:
	if completed:
		return
	if module_id=="cooking" and cooking_phase=="cook":
		if selected_tokens.has(token_id) and not added_tokens.has(token_id):
			pending_ingredient=token_id
			status_label.text=LocalizationSystem.text("把「%s」移到锅边。看一眼火候，准备好再下锅。" % _token_label(token_id))
			_update_state()
		else:
			status_label.text=LocalizationSystem.text("这份材料不在本锅的待下锅清单里。")
		return
	if module_id=="cooking" and cooking_phase!="select":
		status_label.text=LocalizationSystem.text("这锅已经开始了。若要换材料，可以点右上角重新开始；食材尚未被消耗。")
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
	if token_buttons.has(token_id): preload("res://scripts/ui/solmere_motion.gd").ingredient_pickup(token_buttons[token_id],SettingsSystem.reduced_motion())


func _on_value_changed(_value: float) -> void:
	if completed:
		return
	if module_id!="cooking": stage_ready = false
	_update_state()


func _perform_primary_action() -> void:
	if completed:
		return
	var minimum := int(interaction.get("min_select", 0))
	if selected_tokens.size() < minimum:
		status_label.text = LocalizationSystem.text("还需要选择 %d 项，才能完成这次操作。" % (minimum - selected_tokens.size()))
		return
	match module_id:
		"cooking":
			_advance_cooking()
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
	if module_id!="cooking": WorldSound.play_detail(true)
	_update_state()


func _use_cooking_pot() -> void:
	if completed: return
	if cooking_phase=="cook" and not pending_ingredient.is_empty(): _perform_primary_action()
	elif cooking_phase=="stir": _stir("gentle")


func _advance_cooking() -> void:
	match cooking_phase:
		"select":
			cooking_phase="prep"
			status_label.text=LocalizationSystem.text("材料先留在案板上。一次处理一样，锅还没有开火。")
		"cook":
			if pending_ingredient.is_empty():
				status_label.text=LocalizationSystem.text("先从下方点一种尚未下锅的材料，把它移到锅边。")
				_update_state()
				return
			var token_id := pending_ingredient
			var token := _prepared_token(token_id)
			var heat_before := value_slider.value
			var assessment: Dictionary=COOKING.evaluate_addition(token,value_slider.value)
			added_tokens.append(token_id)
			cooking_score+=int(assessment.get("score",0))
			var heat_after := maxf(0.0,heat_before-float(token.get("heat_drop",0.05)))
			value_slider.value=heat_after
			cooking_additions.append({"id":token_id,"label":_token_label(token_id),"heat":heat_before,"heat_after":heat_after,"heat_window":token.get("heat_window",[]),"prep_option":token.get("prep_option",""),"state":str(assessment.get("state","")),"score":int(assessment.get("score",0)),"cook_progress":0.04,"browning":0.0})
			pending_ingredient=""
			status_label.text=LocalizationSystem.text(str(assessment.get("message","材料已经下锅。")))+LocalizationSystem.text(" 材料带走了一点锅温，现在是 %d%%。" % roundi(heat_after*100.0))
			if is_instance_valid(cooking_feedback): cooking_feedback.pulse()
			WorldSound.play_kind("metal",-20,.4)
			if added_tokens.size()==selected_tokens.size():
				cooking_phase="stir"
				status_label.text+=LocalizationSystem.text(" 三样都在锅里了。选一种手法回应锅里的状态；翻拌两次后，何时尝味由你决定。")
		"stir":
			if cooking_stirs.size()<2:
				status_label.text=LocalizationSystem.text("先至少翻拌两次，让锅里的味道真正碰到一起。")
			else:
				cooking_phase="taste"
				status_label.text=LocalizationSystem.text(COOKING.tasting_note(_selected_token_data())+" 熟度："+str(COOKING.dish_doneness(cooking_additions).summary)+"。")
		"taste":
			_finish_seasoning()
	_update_state()


func _simmer_cooking() -> void:
	if completed or cooking_phase!="taste": return
	_advance_food_heat(2.0)
	WorldSound.play_kind("water" if COOKING.pan_moisture(cooking_additions)>0.4 else "metal",-20,.5)
	status_label.text=LocalizationSystem.text("多照看了两拍。现在：%s。可以继续，也可以决定调味。" % str(COOKING.dish_doneness(cooking_additions).summary))
	_update_state()


func _choose_prep_option(option_index: int) -> void:
	if completed or cooking_phase!="prep" or prepared_tokens.size()>=selected_tokens.size(): return
	var token_id := selected_tokens[prepared_tokens.size()]
	var token := _token_data(token_id)
	var options: Array=token.get("prep_options",[])
	if option_index<0 or option_index>=options.size(): return
	var action: Dictionary=COOKING.preparation_action(str(options[option_index].get("id","")),token_id)
	pending_prep_option=option_index
	prep_board.begin(token_id,str(options[option_index].get("id","")),int(action.strokes),str(action.verb),str(action.sound))
	status_label.text=LocalizationSystem.text("%s · %s：在案板上%s %d 下。" % [_token_label(token_id),str(options[option_index].get("label","")),str(action.verb),int(action.strokes)])
	_update_state()


func _finish_board_prep(id: String) -> void:
	if cooking_phase!="prep" or pending_prep_option<0 or prepared_tokens.size()>=selected_tokens.size(): return
	if id!=selected_tokens[prepared_tokens.size()]: return
	var option_index := pending_prep_option
	pending_prep_option=-1
	_finish_prep_option(option_index)


func _finish_prep_option(option_index: int) -> void:
	var token_id := selected_tokens[prepared_tokens.size()]
	var token := _token_data(token_id)
	var options: Array=token.get("prep_options",[])
	var option: Dictionary=options[option_index]
	prepared_tokens.append(token_id); cooking_score+=1
	var action: Dictionary=COOKING.preparation_action(str(option.get("id","")),token_id)
	cooking_preps.append({"id":token_id,"label":_token_label(token_id),"option":str(option.get("id","")),"option_label":str(option.get("label","")),"detail":str(option.get("detail","")),"pan_cue":str(option.get("pan_cue",token.get("pan_cue",""))),"action":str(action.verb),"strokes":int(action.strokes)})
	status_label.text=LocalizationSystem.text("%s · %s：%s" % [_token_label(token_id),str(option.get("label","处理完成")),str(option.get("detail","已经放在锅边。"))])
	if prepared_tokens.size()==selected_tokens.size():
		cooking_phase="cook"
		status_label.text+=LocalizationSystem.text(" 备料齐了。现在下锅顺序不再受选材顺序限制，从下方点一种材料移到锅边。")
	_update_state()


func _preview_prep_option(option_index: int) -> void:
	if cooking_phase!="prep" or prepared_tokens.size()>=selected_tokens.size(): return
	var options: Array=_token_data(selected_tokens[prepared_tokens.size()]).get("prep_options",[])
	if option_index<0 or option_index>=options.size(): return
	var option: Dictionary=options[option_index]
	cooking_prep_detail_label.text=LocalizationSystem.text(str(option.get("detail","")))


func _stir(style: String) -> void:
	if completed or cooking_phase!="stir" or cooking_stirs.size()>=4: return
	var heat_state: Dictionary=COOKING.heat_reading(value_slider.value)
	var stable := value_slider.value>=.34 and value_slider.value<=.76
	var suits_heat := (style=="gentle" and value_slider.value>.60) or (style=="fold" and value_slider.value<=.60)
	var stir_score := (1 if stable else 0)+(1 if suits_heat else 0)
	var labels := {"gentle":"轻推锅底","fold":"翻起拌匀"}
	cooking_score+=stir_score
	cooking_stirs.append({"heat":value_slider.value,"state":str(heat_state.get("id","")),"style":style,"style_label":str(labels.get(style,style)),"score":stir_score})
	_advance_food_heat(1.5)
	if is_instance_valid(cooking_feedback): cooking_feedback.pulse()
	var response := "手法顺着火候，香气被稳稳托起来" if suits_heat else ("味道还在合拢，下一下可以换种手法" if stable else "火候偏了，下一下仍能收回来")
	status_label.text=LocalizationSystem.text("第 %d 下 · %s：%s，%s。" % [cooking_stirs.size(),str(labels.get(style,style)),str(heat_state.get("label","看住火")),response])
	if cooking_stirs.size()>=4:
		status_label.text+=LocalizationSystem.text(" 已经拌得很充分了，趁现在尝一口。")
	if is_instance_valid(illustrated_pot): illustrated_pot.stir(style)
	else: WorldSound.play_world("pot")
	_update_state()


func _choose_seasoning(choice: String) -> void:
	if completed or cooking_phase!="taste" or seasoning_layers.size()>=3: return
	if choice=="rest":
		_finish_seasoning()
		return
	if choice=="brighten": choice="wasabi"
	seasoning_layers.append(choice)
	var labels := {"salt":"海盐","pepper":"黑胡椒","wasabi":"芥末","ketchup":"番茄酱","herbs":"香草"}
	status_label.text=LocalizationSystem.text("第 %d 次调味：%s。%s" % [seasoning_layers.size(),str(labels.get(choice,choice)),"还可以再撒一点，或确认装盘。" if seasoning_layers.size()<3 else "尝味后确认装盘。"])
	WorldSound.play_kind("water" if choice in ["wasabi","ketchup"] else "paper",-20,.4)
	_update_state()


func _finish_seasoning() -> void:
	if completed or cooking_phase!="taste": return
	var labels := {"salt":"海盐","pepper":"黑胡椒","wasabi":"芥末","ketchup":"番茄酱","herbs":"香草"}
	seasoning_choice=seasoning_layers[0] if not seasoning_layers.is_empty() else "rest"
	var names: Array[String]=[]
	for layer in seasoning_layers: names.append(str(labels.get(layer,layer)))
	seasoning_label="、".join(names) if not names.is_empty() else "保留本味"
	var result: Dictionary=COOKING.evaluate_seasoning_layers(_selected_token_data(),seasoning_layers)
	cooking_score+=int(result.get("score",0))
	cooking_phase="plating"
	status_label.text=LocalizationSystem.text(str(result.get("message","调味完成。")))+LocalizationSystem.text(" 锅里的味道定下来了，再决定它怎样来到桌上。")
	WorldSound.play_ui("check")
	_update_state()


func _choose_plating(choice: String) -> void:
	if completed or cooking_phase!="plating": return
	var labels := {"space":"留一点空白","generous":"堆得丰盛","share":"分成小碟"}
	var messages := {
		"space":"盘边留出呼吸，颜色和食材的轮廓都能看清。",
		"generous":"热气和分量都被留在中央，看起来像一顿认真招待。",
		"share":"把同一锅分成几份，每个人都能先尝到自己的那一口。",
	}
	plating_choice=choice; plating_label=str(labels.get(choice,choice)); plating_preview_choice=choice
	cooking_phase="serve"; stage_ready=true
	status_label.text=LocalizationSystem.text(str(messages.get(choice,"料理已经装盘。")))+LocalizationSystem.text(" %s，可以决定怎样出餐。" % str(COOKING.cooking_grade(cooking_score,cooking_additions).get("label","完成成菜")))
	WorldSound.play_ui("check")
	_update_state()
	if is_instance_valid(plated_dish): plated_dish.appear()


func _preview_plating(choice: String) -> void:
	if completed or cooking_phase!="plating": return
	plating_preview_choice=choice
	if is_instance_valid(plated_dish):
		var preparation := _preparation_visuals()
		plated_dish.update_dish(added_tokens,preparation,choice,float(value_slider.value),cooking_additions,seasoning_layers)


func _preparation_visuals() -> Dictionary:
	var preparation := {}
	for prep_value in cooking_preps:
		var prep: Dictionary=prep_value
		preparation[str(prep.get("id",""))]=str(prep.get("option",""))
	return preparation


func _token_data(token_id: String) -> Dictionary:
	for token_value in interaction.get("tokens",[]):
		var token: Dictionary=token_value
		if str(token.get("id",""))==token_id: return token
	return {}


func _prepared_token(token_id: String) -> Dictionary:
	var token := _token_data(token_id)
	for prep in cooking_preps:
		if str(prep.get("id",""))==token_id:
			return COOKING.prepared_token(token,str(prep.get("option","")))
	return token


func _selected_token_data() -> Array:
	var result: Array=[]
	for token_id in selected_tokens: result.append(_token_data(token_id))
	return result


func _update_state() -> void:
	_refresh_ingredient_shelf()
	if is_instance_valid(prep_board):
		prep_board.items.assign(selected_tokens)
		for token_id in added_tokens: prep_board.items.erase(token_id)
		prep_board.cuts=_preparation_visuals()
		prep_board.disabled=completed or cooking_phase!="prep" or pending_prep_option<0
		prep_board.queue_redraw()
	if is_instance_valid(ingredient_art):
		for old in ingredient_art.get_children(): ingredient_art.remove_child(old); old.queue_free()
		for index in (added_tokens.size() if not is_instance_valid(illustrated_pot) else 0):
			var sketch := TextureRect.new()
			var token_id := added_tokens[index]
			sketch.texture=preload("res://scripts/ui/components/cooking_ingredients.gd").texture(token_id,prepared_tokens.has(token_id))
			sketch.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; sketch.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; sketch.mouse_filter=MOUSE_FILTER_IGNORE
			var angle := -PI*.8+index*PI*.6
			sketch.position=Vector2(585,319)+Vector2(cos(angle),sin(angle))*47; sketch.size=Vector2(100,88); ingredient_art.add_child(sketch)
	var minimum := int(interaction.get("min_select", 0))
	var labels: Array[String] = []
	for token_id in selected_tokens:
		labels.append(_token_label(token_id))
	var joiner := " → " if str(interaction.get("mode", "toggle")) == "ordered" else "、"
	selection_label.text = LocalizationSystem.text("顺序：%s" % joiner.join(labels) if not labels.is_empty() else "尚未选择 · 至少 %d 项" % minimum)
	if module_id=="cooking" and cooking_phase in ["cook","stir","taste","plating","serve"]:
		var cooked_labels: Array[String]=[]
		for token_id in added_tokens: cooked_labels.append(_token_label(token_id))
		selection_label.text=LocalizationSystem.text("实际下锅：%s" % (" → ".join(cooked_labels) if not cooked_labels.is_empty() else "等待你决定"))
	for token_id in token_buttons:
		_style_button(token_buttons[token_id], selected_tokens.has(str(token_id)))
		if module_id=="cooking":
			var order: Array[String]=selected_tokens if cooking_phase in ["select","prep"] else added_tokens
			token_buttons[token_id].order_badge=order.find(str(token_id))+1
		token_buttons[token_id].disabled = completed
		if module_id == "cooking":
			if cooking_phase=="select":
				token_buttons[token_id].disabled=completed or not EconomySystem.ingredient_available(str(token_id))
			elif cooking_phase=="cook":
				token_buttons[token_id].disabled=completed or not selected_tokens.has(str(token_id)) or added_tokens.has(str(token_id))
			else:
				token_buttons[token_id].disabled=true
			token_buttons[token_id].modulate=Color("fff2b5") if str(token_id)==pending_ingredient else Color.WHITE
	_update_module_value()
	primary_button.disabled = completed or selected_tokens.size() < minimum
	if module_id=="cooking": _update_cooking_state(minimum)
	var record := _interaction_record()
	for choice_id in choice_buttons:
		var check := GameplayModuleSystem.choice_interaction_check(module_id, str(choice_id), record)
		choice_buttons[choice_id].disabled = completed or not stage_ready or not bool(check.get("ok", false))
		if module_id=="cooking": choice_buttons[choice_id].visible=cooking_phase=="serve" or completed
		if not bool(check.get("ok", false)):
			choice_buttons[choice_id].tooltip_text = LocalizationSystem.text(str(check.get("message", "当前素材不符合这个结果。")))
	queue_redraw()


func _update_cooking_state(minimum: int) -> void:
	var phase_names := {"select":"选材","prep":"备料","cook":"下锅","stir":"翻拌","taste":"尝味","plating":"装盘","serve":"出餐"}
	var phase_order := ["select","prep","cook","stir","taste","plating","serve"]
	var progress: Array[String]=[]
	for phase_id in phase_order:
		progress.append("【%s】" % phase_names[phase_id] if phase_id==cooking_phase else str(phase_names[phase_id]))
	cooking_phase_label.text=LocalizationSystem.text("  →  ".join(progress))
	_refresh_cooking_history()
	instruction_label.text=LocalizationSystem.text(_cooking_hint())
	instruction_label.tooltip_text=LocalizationSystem.text(_cooking_instruction())
	cooking_prep_detail_label.visible=cooking_phase=="prep"
	if cooking_phase=="prep" and prepared_tokens.size()<selected_tokens.size():
		var options: Array=_token_data(selected_tokens[prepared_tokens.size()]).get("prep_options",[])
		if pending_prep_option>=0 and pending_prep_option<options.size():
			cooking_prep_detail_label.text=LocalizationSystem.text("%s · %s %d / %d" % [str(options[pending_prep_option].get("detail","")),str(prep_board.action_verb),int(prep_board.strokes),int(prep_board.strokes_needed)])
		else: cooking_prep_detail_label.text=LocalizationSystem.text(str(options[0].get("detail",""))) if not options.is_empty() else ""
	value_slider.editable=cooking_phase in ["cook","stir","taste"]
	cooking_heat_guide.visible=cooking_phase in ["cook","stir","taste"]
	if cooking_heat_guide.visible:
		var low := 0.34
		var high := 0.76
		if cooking_phase=="cook" and not pending_ingredient.is_empty():
			var window: Array=_prepared_token(pending_ingredient).get("heat_window",[0.40,0.70])
			if window.size()>=2:
				low=float(window[0]); high=float(window[1])
		cooking_heat_guide.update_guide(value_slider.value,low,high)
	match cooking_phase:
		"select":
			primary_button.text=LocalizationSystem.text("开始备料")
			primary_button.disabled=completed or selected_tokens.size()<minimum
		"prep":
			primary_button.text=LocalizationSystem.text("从两种处理里选一种")
			primary_button.disabled=true
		"cook":
			primary_button.text=LocalizationSystem.text("下锅 · %s" % (_token_label(pending_ingredient) if not pending_ingredient.is_empty() else "先点一种材料"))
			primary_button.disabled=pending_ingredient.is_empty()
		"stir":
			primary_button.text=LocalizationSystem.text("尝一口，决定是否停手" if cooking_stirs.size()>=2 else "先让味道碰到一起")
			primary_button.disabled=cooking_stirs.size()<2
		"taste":
			primary_button.text=LocalizationSystem.text("确认调味，开始装盘")
			primary_button.disabled=false
		_:
			primary_button.text=LocalizationSystem.text("尝过再决定" if cooking_phase=="plating" else "料理已经完成")
			primary_button.disabled=true
	primary_button.position.x=690 if cooking_phase=="taste" else 600
	primary_button.size.x=204 if cooking_phase=="taste" else 294
	var prep_options: Array=[]
	if cooking_phase=="prep" and prepared_tokens.size()<selected_tokens.size():
		prep_options=_token_data(selected_tokens[prepared_tokens.size()]).get("prep_options",[])
	for i in prep_option_buttons.size():
		var prep_button: Button=prep_option_buttons[i]
		prep_button.visible=cooking_phase=="prep"
		prep_button.disabled=completed or i>=prep_options.size()
		if i<prep_options.size():
			var prep_option: Dictionary=prep_options[i]
			prep_button.text=LocalizationSystem.text(str(prep_option.get("label","处理方式")))
			prep_button.tooltip_text=LocalizationSystem.text(str(prep_option.get("detail","")))
	for style in stir_buttons:
		stir_buttons[style].visible=cooking_phase=="stir"
		stir_buttons[style].disabled=completed or cooking_stirs.size()>=4
	for choice in seasoning_buttons:
		seasoning_buttons[choice].visible=cooking_phase=="taste"
		seasoning_buttons[choice].disabled=completed or cooking_phase!="taste" or seasoning_layers.size()>=3
	if is_instance_valid(simmer_button):
		simmer_button.visible=cooking_phase=="taste"
		simmer_button.disabled=completed
	for choice in plating_buttons:
		plating_buttons[choice].visible=cooking_phase=="plating"
		plating_buttons[choice].disabled=completed or cooking_phase!="plating"
	cooking_reset_button.disabled=completed or (cooking_phase=="select" and selected_tokens.is_empty())
	if is_instance_valid(illustrated_pot):
		var preparation := _preparation_visuals()
		illustrated_pot.update_recipe(added_tokens,preparation,float(value_slider.value),cooking_phase,cooking_additions,seasoning_layers)
		illustrated_pot.disabled=completed or not ((cooking_phase=="cook" and not pending_ingredient.is_empty()) or (cooking_phase=="stir" and cooking_stirs.size()<4))
		illustrated_pot.accessibility_name=LocalizationSystem.text("轻推锅底" if cooking_phase=="stir" else primary_button.text)
		illustrated_pot.tooltip_text="" if illustrated_pot.disabled else illustrated_pot.accessibility_name
		illustrated_pot.visible=cooking_phase not in ["plating","serve"]
	if is_instance_valid(plated_dish):
		var plate_preparation := _preparation_visuals()
		plated_dish.visible=cooking_phase in ["plating","serve"]
		plated_dish.update_dish(added_tokens,plate_preparation,plating_choice if not plating_choice.is_empty() else plating_preview_choice,float(value_slider.value),cooking_additions,seasoning_layers)
	if is_instance_valid(cooking_feedback):
		cooking_feedback.heat=value_slider.value
		cooking_feedback.ingredient_count=added_tokens.size()
		cooking_feedback.active=cooking_phase in ["cook","stir","taste"]
		cooking_feedback.wetness=COOKING.pan_moisture(cooking_additions)


func _refresh_cooking_history() -> void:
	if not is_instance_valid(cooking_history_label): return
	var food_status := ""
	if not cooking_additions.is_empty():
		var counts: Dictionary=COOKING.dish_doneness(cooking_additions).counts
		var parts: Array[String]=[]
		for key in ["underdone","ready","browned","overdone"]:
			if int(counts[key])>0: parts.append("%d%s" % [int(counts[key]),str({"underdone":"尚生","ready":"刚熟","browned":"焦香","overdone":"过火"}[key])])
		food_status="锅里　%s" % " · ".join(parts)
	cooking_history_label.text=LocalizationSystem.text("备料　%d / 3\n下锅　%d / 3\n翻拌　%d 次%s%s" % [prepared_tokens.size(),added_tokens.size(),cooking_stirs.size(),"\n"+food_status if not food_status.is_empty() else "","\n"+str(COOKING.cooking_grade(cooking_score,cooking_additions).get("label","")) if stage_ready else ""])


func _cooking_hint() -> String:
	var hint: String={
		"select":"从下面挑三样材料；需要旧菜谱时，点右上角「查看菜谱」。",
		"prep":"先选处理方式，再在案板上切、撕、挤或整理。",
		"cook":"选一份待下锅材料，看锅声和适合的温度，再下锅。",
		"stir":"轻推或翻起；至少翻拌两下，再决定何时尝味。",
		"taste":"看熟度，可再煮两拍、分次调味，再确认装盘。",
		"plating":"预览留白、丰盛或分食；每一碟都来自同一锅。",
		"serve":"选择即兴出餐或按菜单出餐；实际做法会留下记录。",
	}.get(cooking_phase,"留意锅里的变化。")
	if not active_recipe.is_empty():
		var recipe_title := str(active_recipe.get("title","参考菜谱"))
		if recipe_title.length()>10: recipe_title=recipe_title.left(10)+"…"
		hint="参考《%s》 · %s" % [recipe_title,hint]
	return hint


func _cooking_instruction() -> String:
	match cooking_phase:
		"select": return "从下面取三样食材。再次点击可放回；备好以后，下锅顺序仍可以临场改变。"
		"prep":
			var token := _token_data(selected_tokens[prepared_tokens.size()])
			if pending_prep_option>=0: return "轮到「%s」。在案板上%s %d 下；切配可拖动菜刀，也可点击案板。" % [str(token.get("label","食材")),str(prep_board.action_verb),int(prep_board.strokes_needed)]
			return "轮到「%s」。先选处理方式，再在案板上动手。" % str(token.get("label","食材"))
		"cook":
			if pending_ingredient.is_empty(): return "从下方点一种尚未下锅的材料。先后顺序由你决定，冷材料还会暂时带走锅温。"
			var token_id := pending_ingredient
			var cue := str(_token_data(token_id).get("pan_cue","听锅里的声音"))
			for prep in cooking_preps:
				if str(prep.get("id",""))==token_id: cue=str(prep.get("pan_cue",cue))
			return "「%s」已经移到锅边。备料留下的提示：%s。先调火，再下锅。" % [_token_label(token_id),cue]
		"stir": return "看火候选择「轻推锅底」或「翻起拌匀」。至少两下以后可以尝味，也可以再多照看一会儿。"
		"taste": return COOKING.tasting_note(_selected_token_data())+" 熟度："+str(COOKING.dish_doneness(cooking_additions).summary)+"。可分次撒至多三种调料，或继续加热；确认后装盘。"
		"plating": return "同一锅菜，留白、丰盛或分食会给人不同感受。选一种今天想要的端法。"
		"serve": return "%s 装盘：%s。决定把它作为临时新菜，还是按饭店菜单稳定出餐。" % [str(COOKING.cooking_grade(cooking_score,cooking_additions).get("note","这锅已经完成。")),plating_label]
	return "完成这道料理。"


func _update_module_value() -> void:
	if value_label == null:
		return
	match module_id:
		"cooking":
			var heat := value_slider.value
			var reading: Dictionary=COOKING.heat_reading(heat)
			var guidance := "看锅边的声音和热气"
			if cooking_phase=="cook" and not pending_ingredient.is_empty():
				var window: Array=_prepared_token(pending_ingredient).get("heat_window",[0.40,0.70])
				if window.size()>=2:
					guidance="再等火上来" if heat<float(window[0]) else ("先收一点火" if heat>float(window[1]) else "适合这份材料下锅")
			elif cooking_phase=="stir":
				guidance="翻拌时火声偏轻" if heat<0.34 else ("先把火收回来" if heat>0.76 else "可以顺着火候翻拌")
			value_label.text = LocalizationSystem.text("火候 %d%% · %s · %s" % [roundi(heat * 100),str(reading.get("label","")),guidance])
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
		var cooking_description := "将使用选中的真实食材，并留下完整的备料、下锅、翻拌、调味和装盘记录。\n\n本次：%s；%s" % [str(COOKING.cooking_grade(cooking_score,cooking_additions).get("label","完成成菜")),str(COOKING.dish_doneness(cooking_additions).summary)]
		sheet.description="这段操作需要 %d 分钟。\n\n%s" % [int(cost.get("minutes",0)),cooking_description if module_id=="cooking" else str(choice.get("detail","完成后将留下对应的经历与材料。"))]
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
	if module_id == "cooking":
		status_label.text=LocalizationSystem.text(str(result.get("message","")).get_slice("\n",0))+LocalizationSystem.text("\n材料、工资和店主回应已记在今天的工作记录里。")
	completed = true
	if not SaveManager.save_or_report("玩法结果保存失败"):
		GameState.load_save_data(rollback_snapshot)
		completed = false
		status_label.text = LocalizationSystem.text("存档写入失败，本次提交尚未生效；可以重试。")
		return
	return_button.text = LocalizationSystem.text("带着结果返回")
	_update_state()
	if module_id=="cooking":
		instruction_label.text=LocalizationSystem.text("出餐已记录。店主回应和实际做法可在工作记录、公共菜谱中查看。")


func _interaction_record() -> Dictionary:
	var grade_data: Dictionary=COOKING.cooking_grade(cooking_score,cooking_additions) if module_id=="cooking" else {}
	return {
		"context":session_context.duplicate(true),
		"mode": str(interaction.get("mode", "toggle")),
		"selected_tokens": selected_tokens.duplicate(),
		"selected_labels": selected_tokens.map(func(token_id: String) -> String: return _token_label(token_id)),
		"mechanic": {
			"heat": value_slider.value if module_id == "cooking" else null,
			"cut_ingredients": prepared_tokens.filter(func(id: String): return preload("res://scripts/ui/components/cooking_ingredients.gd").can_cut(id)) if module_id=="cooking" else [],
			"phase": cooking_phase if module_id == "cooking" else null,
			"prepared_tokens": prepared_tokens.duplicate() if module_id == "cooking" else null,
			"preparations": cooking_preps.duplicate(true) if module_id == "cooking" else null,
			"additions": cooking_additions.duplicate(true) if module_id == "cooking" else null,
			"stirs": cooking_stirs.duplicate(true) if module_id == "cooking" else null,
			"stir_count": cooking_stirs.size() if module_id == "cooking" else null,
			"seasoning": seasoning_choice if module_id == "cooking" else null,
			"seasoning_label": seasoning_label if module_id == "cooking" else null,
			"seasoning_layers": seasoning_layers.duplicate() if module_id == "cooking" else null,
			"plating": plating_choice if module_id == "cooking" else null,
			"plating_label": plating_label if module_id == "cooking" else null,
			"craft_score": cooking_score if module_id == "cooking" else null,
			"grade": grade_data if module_id == "cooking" else null,
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
	if GlobalRecorder.focused() or event.is_action_pressed("open_recorder"): return
	if not get_tree().get_nodes_in_group("recipe_book").is_empty(): return
	if not get_tree().get_nodes_in_group("native_confirmation").is_empty(): return
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.keycode >= KEY_1 and event.keycode <= KEY_8:
		var index := int(event.keycode - KEY_1)
		if module_id=="cooking":
			var visible_ids := _visible_ingredient_ids()
			if index<visible_ids.size(): _toggle_token(visible_ids[index])
		else:
			var tokens: Array = interaction.get("tokens", [])
			if index < tokens.size(): _toggle_token(str(tokens[index].get("id", "")))
	elif event.is_action_pressed("restart_module"):
		_perform_primary_action()
	elif event.is_action_pressed("ui_cancel"):
		_return_or_cancel()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("f4f1e6"))
	if module_id=="cooking":
		draw_rect(Rect2(Vector2.ZERO,size),Color("e7c7b4"))
		draw_rect(Rect2(0,620,size.x,280),Color("f1dfc1"))
		draw_line(Vector2(0,620),Vector2(size.x,620),Color("886952"),2)
		return
	var art=preload("res://scripts/ui/components/handmade_assets.gd")
	match module_id:
		"photography":
			if background_texture: draw_texture_rect(background_texture,Rect2(177,269,634,361),false)
			draw_texture_rect(art.texture("photo_mat"),Rect2(67,154,865,575),false)
			_draw_photography()
		"optical_illusion":
			draw_texture_rect(art.texture("window_frame"),Rect2(84,155,826,576),false)
			_draw_perspective()
		"archives": _draw_archives()

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
			note.text=LocalizationSystem.text("先从右侧取一份记录")
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


func _update_fire_sound(delta:float) -> void:
	var burning:=module_id=="cooking" and not completed and cooking_phase in ["cook","stir"] and not added_tokens.is_empty() and is_instance_valid(value_slider) and value_slider.value>.02
	if not burning:
		if is_instance_valid(fire_player): fire_player.stop()
		return
	if not is_instance_valid(fire_player):
		fire_player=AudioStreamPlayer.new(); fire_player.bus="TownWorldSoundEffects"; add_child(fire_player)
		fire_player.stream=preload("res://scripts/town_sound/data/SoundAtlas.gd").stream("fire")
	fire_player.volume_db=lerpf(-32,-20,value_slider.value)
	if not fire_player.playing and AudioServer.get_driver_name()!="Dummy": fire_player.play()
	fire_notice-=delta
	if fire_notice<=0 and fire_player.playing: fire_notice=1.2; WorldSound.note_sound("fire")
