extends "res://scripts/residency/paper_overlay.gd"
## The same physical folio holds every carried object, with separate private pages.
const CANVAS = preload("res://scripts/residency/living_canvas.gd")
const BLUE := Color("31658b")
const LEMON := Color("eed577")
const TAB = preload("res://scripts/residency/paper_tab.gd")
const PALETTE = preload("res://scripts/ui/components/interface_palette.gd")
var canvas: Control
var selection_tools: Control
var archive_tab := "overview"
var pause_owned := false
var task_checks: Array = []
var notebook_section := "today"

func _ready() -> void:
	process_mode=PROCESS_MODE_ALWAYS
	super._ready()
	GameState.state_changed.connect(_refresh_checks)
	GuidanceSystem.updated.connect(_refresh_checks)
	resized.connect(_layout_frame)
	_layout_frame()

func _layout_frame() -> void:
	if not is_instance_valid(body): return
	body.pivot_offset=DOSSIER_SIZE*.5
	body.scale=Vector2.ONE*minf(1.0,minf(size.x*.90/DOSSIER_SIZE.x,size.y*.84/DOSSIER_SIZE.y))

func _input(event: InputEvent) -> void:
	if not get_tree().get_nodes_in_group("native_confirmation").is_empty(): return
	if event.is_action_pressed("ui_cancel"):
		if mode=="settings": mode="pause"; build()
		elif is_instance_valid(detail): detail.queue_free(); detail=null
		else: close()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if pause_owned: get_tree().paused=false

func panel(parent: Node, at: Vector2, dimensions: Vector2, color := Color("faf7ee")) -> Panel:
	var result := super.panel(parent,at,dimensions,color)
	return result

func build() -> void:
	theme=PALETTE.theme_for_tools()
	if mode=="organize": mode="dossier"; archive_tab="days"; day=GameState.current_day
	for child in get_children(): remove_child(child); child.queue_free()
	detail=null; canvas=null; selection_tools=null; task_checks.clear()
	if mode in ["pause","settings"]: pause_owned=true
	elif pause_owned: get_tree().paused=false; pause_owned=false
	var dim := ColorRect.new()
	dim.color=Color("172f45",.34)
	if mode in ["pause","settings"]:
		var shader := Shader.new()
		shader.code="shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap; void fragment(){ vec3 scene=textureLod(screen_texture,SCREEN_UV,2.2).rgb; COLOR=vec4(scene*vec3(.46,.53,.61),1.); }"
		var blur := ShaderMaterial.new(); blur.shader=shader; dim.material=blur
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	body=panel(self,Vector2.ZERO,DOSSIER_SIZE,Color("faf7ee"))
	body.name="CarriedObjectFrame"
	body.set_anchors_preset(PRESET_CENTER)
	body.offset_left=-DOSSIER_SIZE.x*.5
	body.offset_top=-DOSSIER_SIZE.y*.5
	body.offset_right=DOSSIER_SIZE.x*.5
	body.offset_bottom=DOSSIER_SIZE.y*.5
	var frame := StyleBoxFlat.new()
	frame.bg_color=Color.TRANSPARENT
	body.add_theme_stylebox_override("panel",frame)
	_layout_frame()
	var paper_mode := mode in ["notebook","today","dossier","knowledge","fieldbook"]
	if paper_mode:
		var paper := preload("res://scripts/ui/components/book_surface.gd").new()
		paper.spread=mode in ["notebook","today"] or (mode=="dossier" and archive_tab=="days")
		paper.ruled=mode in ["notebook","today"]
		paper.size=DOSSIER_SIZE; body.add_child(paper)
		if not paper.spread:
			var spine := preload("res://scripts/ui/components/interface_art.gd").new(); spine.kind="folio"; spine.position=Vector2(26,22); spine.size=Vector2(16,700); body.add_child(spine)
	elif mode not in ["pause","settings","map","sound_library"]:
		var clean := StyleBoxFlat.new(); clean.bg_color=Color("eff3f3"); clean.set_corner_radius_all(12)
		body.add_theme_stylebox_override("panel",clean)
	feedback=label(body,"",Vector2(80,702),Vector2(1170,30),16,BLUE)
	if mode in ["pause","settings"]:
		var menu := preload("res://scripts/ui/components/runtime_menu.gd").new()
		menu.owner_ui=self; menu.settings=mode=="settings"; body.add_child(menu)
		return
	var names := ["随身本  Notebook","档案  Archive","相机  Camera","录音机  Recorder"]
	var targets := ["notebook","dossier","gallery","sound_library"]
	for i in (0 if mode=="map" else 4):
		var chosen: bool=mode==targets[i] or (i==0 and mode in ["home","map","today","knowledge","fieldbook","bag","day_schedule"])
		var b := button(body,names[i],Vector2(212+i*222,-42),Vector2(214,39),_switch_object.bind(targets[i]))
		b.name="ObjectTab_"+targets[i]; b.variant="tab"; b.selected=chosen; b.refresh()
		b.add_theme_font_size_override("font_size",17)
	var back := button(body,"×",Vector2(1290,0 if mode=="map" else -42),Vector2(42,38),close)
	back.tooltip_text=SettingsSystem.binding_text("ui_cancel")+" "+LocalizationSystem.text("收起")
	back.add_theme_color_override("font_color",Color.WHITE)
	match mode:
		"day_schedule":
			var planner := preload("res://scripts/ui/components/day_five_planner.gd").new()
			planner.position=Vector2(75,50); planner.size=Vector2(1200,620); body.add_child(planner)
		"bag": _inventory()
		"counter": _counter()
		"proofs": _proofs()
		"controls": _home()
		"dossier": _archive()
		"gallery":
			button(body,"＋ 拍一张照片",Vector2(1015,34),Vector2(260,48),_home_action.bind("camera"))
			_browser("photo")
		"sound_library":
			_browser("sound")
		"map": _map()
		"today": _notebook_page()
		"knowledge": _knowledge()
		"fieldbook": _materials()
		_:
			mode="notebook"
			_notebook_page()

func edit(parent: Node, value: String, at: Vector2, dimensions: Vector2, action: Callable, placeholder := "") -> TextEdit:
	var field := super.edit(parent,value,at,dimensions,action,placeholder)
	field.add_theme_color_override("background_color",Color.TRANSPARENT)
	for state in ["normal","read_only","focus"]:
		var line := StyleBoxFlat.new()
		line.bg_color=Color.TRANSPARENT; line.border_width_bottom=1
		line.border_color=LEMON if state=="focus" else Color("31658b",.24)
		field.add_theme_stylebox_override(state,line)
	return field

func button(parent: Node, text: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var b := preload("res://scripts/ui/components/solmere_button.gd").new()
	b.text=LocalizationSystem.text(text); b.position=at; b.size=dimensions; parent.add_child(b); b.pressed.connect(action)
	return b

func _switch_object(target: String) -> void:
	ResidencySystem.persist()
	WorldSound.play_ui("paper")
	mode=target; build()

func _archive() -> void:
	if archive_tab=="overview":
		_hand("Solmere",Vector2(95,52),Vector2(540,98),70)
		_hand("For dreams,
and the life after.",Vector2(980,66),Vector2(280,70),23)
		var titles := ["旅居说明","关于自己","生活记录","居民留字","自由拼贴","写给小镇"]
		var translations := ["WELCOME","PERSONAL","LIFE LOG","RECOGNITION","COLLAGE","LETTER"]
		var keys := ["requirements","personal","life","recognition","days","final"]
		var icons := ["requirements","personal","life","star","book","mail"]
		for i in 6:
			var target: String=keys[i]
			var card := button(body,"",Vector2(92+(i%3)*390,194+(i/3)*233),Vector2(360,212),func() -> void: archive_tab=target; build())
			card.variant="archive"; card.refresh(); card.name="ArchiveSection_"+target
			_icon(card,icons[i],Vector2(142,27),Vector2(76,76))
			var title := label(card,titles[i],Vector2(12,117),Vector2(336,36),25,BLUE); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			var subtitle := label(card,translations[i],Vector2(12,158),Vector2(336,27),14,BLUE); subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		return
	var keys := ["requirements","personal","life","recognition","days","final"]
	var titles := ["旅居说明","关于自己","生活记录","居民留字","自由拼贴","写给小镇"]
	var translations := ["Welcome","Personal","Life Log","Recognition","Collage","Letter"]
	for i in keys.size():
		var target: String = keys[i]
		var chosen := target==archive_tab
		var b := _tab(titles[i],translations[i],Vector2(70+i*201,42),Vector2(198,58),i,chosen,func() -> void: archive_tab=target; WorldSound.play_ui("paper"); build())
		b.name="ArchiveTab_"+target
	match archive_tab:
		"requirements":
			_requirements_sheet()
		"final": _final_paper()
		"days":
			_hand("自由拼贴",Vector2(139,114),Vector2(510,64),42)
			_free_page("collage")
		_: _free_page(archive_tab)

func _pages() -> Dictionary:
	var s := ResidencySystem.state()
	if not s.has("free_pages"): s.free_pages={}
	return s.free_pages

func _free_page(key: String) -> void:
	var pages := _pages()
	if not pages.has(key): pages[key]=[]
	if key=="recognition":
		for resident in GameState.confirmed_residents:
			var id := "recognition_"+str(resident)
			if not pages[key].any(func(p: Dictionary) -> bool: return p.get("material","")==id):
				var i: int = pages[key].size()
				pages[key].append({"material":id,"kind":"recognition","text":str(ScheduleSystem.residents.get(resident,{}).get("display_name",resident)),"x":150+(i%4)*270,"y":75+(i/4)*130,"w":240,"h":100,"scale":1.0,"rotation":float(i%3-1)*.07})
	canvas=CANVAS.new(); canvas.name="FreePaper"
	canvas.position=Vector2(116,198); canvas.size=Vector2(1200,460); canvas.scale=Vector2(.905,1.0)
	canvas.pieces=pages[key]
	canvas.page_id=key
	canvas.read_only=false
	body.add_child(canvas)
	canvas.changed.connect(func() -> void:
		if key=="day_%d" % GameState.current_day: ResidencySystem._record_organize()
		ResidencySystem.persist())
	canvas.selection_changed.connect(_selection_toolbar)
	if not canvas.read_only:
		var add := button(body,"＋ 添加素材",Vector2(906,122),Vector2(281,54),_material_tray)
		add.name="AddCollageMaterial"; add.tooltip_text="打开照片、小票、信件和生活纸片；点击或拖入页面"
		var tools := [["text","文字","Text"],["photo","照片","Photo"],["draw","画笔","Draw"]]
		for i in tools.size():
			var action: Callable=[_write_piece,_photo_material_tray,_toggle_drawing][i]
			var tool_button := button(body,"",Vector2(1220,172+i*111),Vector2(82,101),action)
			tool_button.variant="outlined"; tool_button.refresh()
			tool_button.name="CollageTool_"+str(tools[i][0])
			_icon(tool_button,str(tools[i][0]),Vector2(25,12),Vector2(32,32))
			var words := label(tool_button,str(tools[i][1])+"\n"+str(tools[i][2]),Vector2(2,48),Vector2(78,44),14,BLUE); words.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func _selection_toolbar() -> void:
	if is_instance_valid(selection_tools): selection_tools.queue_free()
	if not is_instance_valid(canvas) or canvas.selected<0: return
	selection_tools=Control.new(); selection_tools.position=Vector2(198,659); body.add_child(selection_tools)
	var actions := ["rotate_left","rotate_right","smaller","larger","back","front","remove"]
	var labels := ["↶","↷","缩小","放大","下层","上层","移除"]
	for i in actions.size(): button(selection_tools,labels[i],Vector2(i*112,0),Vector2(105,40),canvas.transform_selected.bind(actions[i]))

func _material_tray() -> void:
	ResidencySystem._sync_sources()
	if is_instance_valid(detail): detail.queue_free()
	detail=panel(body,Vector2(825,150),Vector2(470,485),Color("faf7ee"))
	detail.name="CollageMaterialTray"
	button(detail,"收起素材 ×",Vector2(275,8),Vector2(180,35),func() -> void: detail.queue_free())
	label(detail,"点击放入 · 也可拖到纸上",Vector2(18,13),Vector2(255,32),17,BLUE)
	var scroll := ScrollContainer.new()
	scroll.position=Vector2(8,52); scroll.size=Vector2(454,418)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; detail.add_child(scroll)
	var spread := Control.new(); spread.name="LooseMaterials"; scroll.add_child(spread)
	var index := 0
	var bottom := 0.0
	for id in ResidencySystem.state().materials:
		var item: Dictionary = ResidencySystem.state().materials[id]
		if item.get("kind","")=="official": continue
		var piece := preload("res://scripts/residency/material_cutout.gd").new()
		piece.material_id=str(id); piece.item=item
		piece.name="Material_"+str(id).validate_node_name()
		var kind := str(item.get("kind","note"))
		piece.size=Vector2([170,184,160,176][index%4],155 if kind=="photo" else 172 if kind=="receipt" else 112+(index%3)*12)
		piece.position=Vector2(24+(index%2)*207+sin(index*2.0)*8,18+floori(index/2.0)*178+(index%2)*14)
		piece.pivot_offset=piece.size*.5; piece.rotation=[-.065,.045,-.035,.075][index%4]
		spread.add_child(piece)
		piece.activated.connect(func() -> void:
			canvas._drop_data(Vector2(330+(canvas.pieces.size()%3)*85,180+(canvas.pieces.size()%2)*75),{"residency_material":id}); detail.queue_free())
		bottom=maxf(bottom,piece.position.y+piece.size.y+22)
		index+=1
	spread.custom_minimum_size=Vector2(430,maxf(410,bottom))
	if index==0:
		label(spread,"还没有收集到素材。\n照片、小票和回信会出现在这里；也可以先写一张纸条。",Vector2(35,62),Vector2(350,140),22,BLUE)
		button(spread,"写一张纸条",Vector2(58,242),Vector2(285,48),_write_piece)

func _write_piece() -> void:
	if is_instance_valid(detail): detail.queue_free()
	detail=panel(body,Vector2(400,240),Vector2(530,270))
	var words := edit(detail,"",Vector2(20,20),Vector2(490,170),func(_s: String) -> void: pass,"")
	button(detail,"放到纸上",Vector2(20,210),Vector2(230,40),func() -> void:
		if not words.text.strip_edges().is_empty(): canvas.add_piece({"kind":"text","text":words.text,"w":300,"h":160},Vector2(440,210))
		detail.queue_free())
	button(detail,"取消",Vector2(280,210),Vector2(230,40),func() -> void: detail.queue_free())

func _media_library(kind: String) -> void:
	var rows := scroll_area(body,Vector2(45,155),Vector2(1250,530))
	for id in ResidencySystem.state().materials:
		var item: Dictionary = ResidencySystem.state().materials[id]
		if item.get("kind","")!=kind: continue
		var row := Control.new(); row.custom_minimum_size=Vector2(1180,175); rows.add_child(row)
		if kind=="photo": _photo(row,str(id),Vector2(0,5),Vector2(220,155))
		button(row,str(item.get("title","")),Vector2(245,25),Vector2(820,70),_show_detail.bind(str(id)))

func _final_paper() -> void:
	var s := ResidencySystem.state()
	_hand("写给 Solmere",Vector2(120,135),Vector2(950,60),38)
	label(body,"想留下什么，就写在这里。",Vector2(120,210),Vector2(1050,42),23,BLUE)
	edit(body,str(s.get("town_letter","")),Vector2(120,278),Vector2(1080,310),func(value: String) -> void: s["town_letter"]=value)
	button(body,"保存这封信",Vector2(930,620),Vector2(270,48),ResidencySystem.persist)

func _counter() -> void:
	_hand("社区资料柜台",Vector2(110,140),Vector2(1100,65),38)
	label(body,"照片、信件和日常留下的纸片，都可以留在自己的档案里。",Vector2(110,250),Vector2(1100,80),24,BLUE)
	button(body,"翻开生活记录",Vector2(110,400),Vector2(1090,60),func() -> void: mode="dossier"; archive_tab="life"; build())

func _today() -> void:
	label(body,"Day %02d · 留给今天的几笔" % GameState.current_day,Vector2(110,100),Vector2(1090,48),29,BLUE)
	var s := ResidencySystem.state()
	if not s.has("private_plans"): s.private_plans={}
	var key := str(GameState.current_day)
	edit(body,str(s.private_plans.get(key,"")),Vector2(110,180),Vector2(1090,280),func(value: String) -> void: s.private_plans[key]=value,"")
	var commitment := GameState.next_commitment()
	if not commitment.is_empty():
		var minute := int(commitment.get("return_by",commitment.get("start",0)))
		label(body,"记得，%02d:%02d 去 %s。" % [minute/60,minute%60,TravelSystem.location_name(str(commitment.get("location","dorm")))],Vector2(110,510),Vector2(1090,65),23,BLUE)
	button(body,"← 回到随身本",Vector2(110,627),Vector2(350,45),_switch_object.bind("notebook"))

func _inventory() -> void:
	preload("res://scripts/ui/components/handmade_assets.gd").picture(body,"tote",Vector2(5,0),DOSSIER_SIZE,true)
	label(body,"随身包  /  POCKET",Vector2(140,31),Vector2(700,29),15,PALETTE.SEA)
	label(body,"今天带在身边的东西",Vector2(140,67),Vector2(800,45),31,PALETTE.SEA)
	var materials := button(body,"纸片与纪念物 →",Vector2(979,72),Vector2(290,40),_switch_object.bind("fieldbook")); materials.variant="tab"; materials.refresh()
	var rows := scroll_area(body,Vector2(158,170),Vector2(1030,468))
	var grid := GridContainer.new(); grid.columns=3; grid.add_theme_constant_override("h_separation",49); grid.add_theme_constant_override("v_separation",15); rows.add_child(grid)
	var catalog: Dictionary = {}
	for shop in JSON.parse_string(FileAccess.get_file_as_string("res://data/economy/shops.json")).shops:
		for item in shop.get("items",[]): catalog[str(item.id)]=item
	for fish in preload("res://scripts/core/coastal_fishing.gd").SPECIES: catalog[str(fish.id)]={"name":fish.name,"description":"海边钓来的鲜鱼，可以在料理台用它做菜。"}
	for id in GameState.inventory:
		var count := int(GameState.inventory[id])
		if count<=0: continue
		var item: Dictionary = catalog.get(id,{"name":id,"description":"一路带来的小物件。"})
		var card := preload("res://scripts/ui/components/goods_card.gd").new(); card.item=item.merged({"id":str(id)}); card.quantity="带着 %d 件  ·  拿近看看"%count; card.name="PocketItem_"+str(id); grid.add_child(card)
		card.pressed.connect(func() -> void:
			if is_instance_valid(detail): detail.queue_free()
			detail=panel(body,Vector2(390,220),Vector2(600,300))
			label(detail,str(item.name),Vector2(30,30),Vector2(530,45),28,BLUE)
			label(detail,str(item.get("description","")),Vector2(30,98),Vector2(530,110),23,BLUE)
			button(detail,"放回包里",Vector2(190,236),Vector2(220,40),func() -> void: detail.queue_free()))
	if grid.get_child_count()==0: label(body,"包里还空着。",Vector2(110,245),Vector2(1040,60),25,BLUE)
	button(body,"← 回到随身本",Vector2(110,671),Vector2(300,40),_switch_object.bind("notebook"))
	button(body,"整理素材 · 制作拼贴 →",Vector2(862,670),Vector2(370,44),_open_collage).name="OpenCollage"

func _show_detail(id: String) -> void:
	if is_instance_valid(detail): detail.queue_free()
	var item: Dictionary = ResidencySystem.state().materials.get(id,{})
	if item.is_empty(): return
	detail_id=""
	detail=panel(body,Vector2(35,130),Vector2(1270,550))
	label(detail,str(item.get("title","")),Vector2(30,15),Vector2(1060,42),25,BLUE)
	button(detail,"← 返回",Vector2(1100,15),Vector2(140,40),func() -> void: detail.queue_free())
	if item.get("kind","")=="photo":
		_photo(detail,id,Vector2(50,75),Vector2(1170,440))
	elif item.get("kind","")=="sound":
		var store := SampleStore.new()
		for sample in store.list_samples():
			if str(sample.id)!=id or bool(sample.get("missing",false)): continue
			audio_player=AudioStreamPlayer.new(); audio_player.bus="Music"
			audio_player.stream=AudioStreamWAV.load_from_file(str(sample.file_path)); detail.add_child(audio_player)
			var waveform = load("res://scripts/residency/sound_paper.gd").new()
			waveform.wav=audio_player.stream; waveform.position=Vector2(100,135); waveform.size=Vector2(1070,170); detail.add_child(waveform)
			button(detail,"播放 / 停止",Vector2(455,370),Vector2(360,50),func() -> void:
				if audio_player.playing: audio_player.stop()
				else: audio_player.play())
	else: label(detail,str(item.get("text",item.get("title",""))),Vector2(50,90),Vector2(1160,430),24,BLUE)

func _tab(cn: String, en: String, at: Vector2, dimensions: Vector2, _palette: int, chosen: bool, action: Callable) -> Button:
	var tab_button := button(body,cn+"\n"+en,at,dimensions,action)
	tab_button.selected=chosen
	tab_button.add_theme_font_size_override("font_size",15)
	return tab_button

func _official(text: String, at: Vector2, dimensions: Vector2, point: int) -> Label:
	var words := label(body,text,at,dimensions,point,BLUE)
	var print_font := SystemFont.new(); print_font.font_names=PackedStringArray(["SimSun","Noto Serif CJK SC","Georgia"])
	words.add_theme_font_override("font",print_font)
	return words

func _requirements_sheet() -> void:
	_hand("Solmere · 为有梦的人而生",Vector2(110,155),Vector2(1130,75),42)
	_official("在海边走走，认识居民，做一点喜欢的事。\n留下的声音、料理、信和对局，会成为小镇生活的一部分。",Vector2(110,280),Vector2(1070,115),27)
	_official("记录由你决定。照片、纸片和随笔可以慢慢收集，\n不需要填满页面，也不需要集齐居民的认可。",Vector2(110,445),Vector2(1070,115),25)
	button(body,"查看今天想做的事",Vector2(110,600),Vector2(470,56),_switch_object.bind("today"))

func _browser(kind: String) -> void:
	var browser := preload("res://scripts/ui/components/media_browser.gd").new()
	browser.kind=kind; browser.owner_ui=self; browser.position=Vector2(65,50); body.add_child(browser)

func _notebook_page() -> void:
	var categories := [["today","今天","TODAY"],["heard","听说了","LEADS"],["connections","回音","CONNECTIONS"],["people","人物","PEOPLE"],["places","地点","PLACES"],["personal","私人","PERSONAL"],["materials","收藏","MATERIALS"]]
	for i in categories.size():
		var key: String=categories[i][0]
		var b := button(body,str(categories[i][1])+"\n"+str(categories[i][2]),Vector2(40,102+i*72),Vector2(162,64),func() -> void: notebook_section=key; build())
		b.selected=notebook_section==key; b.add_theme_font_size_override("font_size",16); b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	_hand("Day %02d" % GameState.current_day,Vector2(242,90),Vector2(370,54),34)
	if notebook_section=="connections": _connections_page(); return
	if notebook_section in ["people","places","materials"]:
		_notebook_collection(notebook_section)
		return
	if notebook_section=="today":
		var tasks := GuidanceSystem.must_objectives()
		for i in tasks.size():
			var row: Dictionary=tasks[i]
			var check := CheckBox.new(); check.text=str(row.text); check.button_pressed=bool(row.done)
			check.position=Vector2(232,163+i*83); check.size=Vector2(378,68); check.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			check.add_theme_font_override("font",PaperLanguage.handwriting); check.add_theme_font_size_override("font_size",23)
			for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]: check.add_theme_color_override(state,BLUE)
			for state in ["normal","hover","pressed","focus","disabled","hover_pressed"]: check.add_theme_stylebox_override(state,StyleBoxEmpty.new())
			check.add_theme_stylebox_override("focus",get_theme_stylebox("focus","Button"))
			check.name="TaskCheck_"+str(i); body.add_child(check); task_checks.append(check)
			check.pressed.connect(func() -> void: _refresh_checks(); _guidance_action(row))
		_hand("听说了",Vector2(242,435),Vector2(370,44),25)
		var heard := GuidanceSystem.leads()
		for i in mini(2,heard.size()):
			var lead: Dictionary=heard[i]
			var text := "◇ "+str(lead.text)+"\n   — "+GuidanceSystem.source_name(str(lead.source))
			var b := button(body,"",Vector2(232,483+i*81),Vector2(380,76),func() -> void: GuidanceSystem.track(str(lead.id)); notebook_section="heard"; build())
			b.name="HeardPreview_"+str(i); b.tooltip_text=text; b.clip_contents=true
			var preview := label(b,text,Vector2(10,5),Vector2(360,66),17,BLUE)
			preview.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; preview.max_lines_visible=3; preview.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		if heard.is_empty(): _hand("沿街走走，听听人们的故事。",Vector2(242,502),Vector2(348,95),23)
	elif notebook_section=="heard":
		var rows := scroll_area(body,Vector2(232,169),Vector2(393,475))
		var leads := GuidanceSystem.leads()
		if leads.is_empty(): _hand("还没听到新的线索。\n沿街和遇见的人说说话吧。",Vector2(242,215),Vector2(370,140),27)
		for lead in leads:
			var row := VBoxContainer.new(); rows.add_child(row)
			var words := Label.new(); words.text=str(lead.text)+"\n— "+GuidanceSystem.source_name(str(lead.source)); words.custom_minimum_size=Vector2(361,130); words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; row.add_child(words)
			var actions := HBoxContainer.new(); row.add_child(actions)
			var follow := preload("res://scripts/ui/components/solmere_button.gd").new(); follow.text=LocalizationSystem.text("取消追踪" if str(GuidanceSystem.state().tracked_lead)==str(lead.id) else "追踪"); follow.disabled=not bool(lead.available); actions.add_child(follow)
			follow.pressed.connect(func() -> void: GuidanceSystem.track("" if str(GuidanceSystem.state().tracked_lead)==str(lead.id) else str(lead.id)); build())
			var map := preload("res://scripts/ui/components/solmere_button.gd").new(); map.text=LocalizationSystem.text("看地图"); actions.add_child(map); map.pressed.connect(func() -> void: _guidance_action({"action":"map","location":str(lead.location)}))
	else:
		var s := ResidencySystem.state()
		var note := edit(body,str(s.get("private_note","")),Vector2(242,176),Vector2(370,178),func(value: String) -> void: s.private_note=value; ResidencySystem.persist(),"留给自己的话……")
		note.name="PrivateNotebookText"; note.add_theme_font_override("font",PaperLanguage.handwriting); note.add_theme_font_size_override("font_size",25)
		var plan := LineEdit.new(); plan.name="PersonalPlanText"; plan.position=Vector2(242,369); plan.size=Vector2(258,43); plan.placeholder_text=LocalizationSystem.text("想做的一件小事"); body.add_child(plan)
		button(body,"记下",Vector2(510,369),Vector2(100,43),func() -> void: CoreLoopSystem.pin_personal(plan.text); build()).name="PinPersonalPlan"
		var plans := scroll_area(body,Vector2(242,427),Vector2(375,210))
		for entry in CoreLoopSystem.state().personal:
			var check := CheckBox.new(); check.text=str(entry.text); check.button_pressed=bool(entry.done); check.custom_minimum_size=Vector2(345,54); check.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; plans.add_child(check)
			check.toggled.connect(func(done: bool) -> void: entry.done=done; ResidencySystem.persist(); GuidanceSystem.updated.emit())
	# Only the player's actual photograph can appear on the private page.
	var library := PhotoLibrary.new()
	var photos := library.list_photos().filter(func(photo: Dictionary) -> bool: return str(photo.get("role",GameState.current_role))==GameState.current_role)
	if not photos.is_empty():
		var photo: Dictionary=photos.back()
		var data := library.load_photo(str(photo.photo_id))
		if data!=null:
			var card := button(body,"",Vector2(753,160),Vector2(425,352),_switch_object.bind("gallery")); card.rotation=-.045
			var white := StyleBoxFlat.new(); white.bg_color=Color("fffcf2"); white.set_content_margin_all(8); card.add_theme_stylebox_override("normal",white)
			for state in ["hover","pressed"]: card.add_theme_stylebox_override(state,white)
			var image := TextureRect.new(); image.position=Vector2(15,15); image.size=Vector2(395,284); image.texture=ImageTexture.create_from_image(data); image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; image.mouse_filter=MOUSE_FILTER_IGNORE; card.add_child(image)
			_hand(TravelSystem.location_name(str(photo.get("location",""))),Vector2(805,541),Vector2(390,45),27)
	else:
		_hand("这页，留给路上的片刻。",Vector2(755,288),Vector2(452,64),28)
		button(body,"拿起相机 →",Vector2(835,385),Vector2(245,44),_home_action.bind("camera"))
	for i in 3:
		var targets := ["map","knowledge","bag"]
		var b := button(body,["地图","人和地方","随身包"][i],Vector2(737+i*169,638),Vector2(157,40),_switch_object.bind(targets[i])); b.add_theme_font_size_override("font_size",17)
	button(body,"制作拼贴 · 添加生活素材 →",Vector2(765,577),Vector2(444,45),_open_collage).name="OpenCollage"

func _open_collage() -> void:
	mode="dossier"; archive_tab="days"; build()
	body.get_node("AddCollageMaterial").grab_focus()

func _refresh_checks() -> void:
	var rows := GuidanceSystem.must_objectives()
	for i in mini(rows.size(),task_checks.size()):
		if is_instance_valid(task_checks[i]): task_checks[i].set_pressed_no_signal(bool(rows[i].done))

func _connections_page() -> void:
	_hand("小事，也会有回音。",Vector2(758,98),Vector2(452,60),31)
	var steps := CoreLoopSystem.connection_steps()
	var rows := scroll_area(body,Vector2(236,176),Vector2(395,456))
	if steps.is_empty():
		_hand("暂时没有需要带去的话。\n与人一起做的事情，\n之后可以再去问问。",Vector2(248,227),Vector2(350,170),25)
	for step in steps:
		var card := preload("res://scripts/ui/components/solmere_button.gd").new(); card.variant="archive"; card.custom_minimum_size=Vector2(365,158); card.name="Connection_"+str(step.id); rows.add_child(card)
		PALETTE.words(card,GuidanceSystem.source_name(str(step.source))+"  →  "+GuidanceSystem.source_name(str(step.npc)),Vector2(18,15),327,17,PALETTE.MUTED)
		var title := PALETTE.words(card,str(step.text),Vector2(18,48),327,20)
		var foot_y := 59.0+maxf(52,title.get_line_count()*29)
		if not bool(step.available):
			var availability := PALETTE.words(card,str(step.context),Vector2(18,foot_y),327,16,PALETTE.MUTED)
			foot_y+=availability.get_line_count()*25+9
		PALETTE.words(card,TravelSystem.location_name(str(step.location))+" · 查看地点 ›",Vector2(18,foot_y),327,15,PALETTE.SEA)
		card.custom_minimum_size.y=foot_y+39; card.tooltip_text=str(step.context)
		card.pressed.connect(func() -> void: _guidance_action(step))
	var replies: Array=ResidencySystem.state().materials.values().filter(func(item: Dictionary) -> bool: return str(item.get("source",""))=="resident_reply")
	if not replies.is_empty():
		var reply: Dictionary=replies.back()
		label(body,str(reply.title),Vector2(765,218),Vector2(429,56),26,BLUE)
		var note := label(body,str(reply.text),Vector2(765,300),Vector2(429,223),23,BLUE); note.add_theme_font_override("font",PaperLanguage.handwriting)
		label(body,"Day %02d · %s"%[int(reply.day),TravelSystem.location_name(str(reply.location))],Vector2(765,546),Vector2(425,32),16,PALETTE.MUTED)
		button(body,"拿近看看这张纸 →",Vector2(765,603),Vector2(355,44),_show_detail.bind(str(reply.id)))
	else:
		_hand("有人记住你留下的东西，\n有人替你留下一句话。",Vector2(768,277),Vector2(430,136),29)
		var coast := preload("res://scripts/ui/components/interface_art.gd").new(); coast.position=Vector2(887,481); coast.size=Vector2(168,97); body.add_child(coast)


func _guidance_action(action: Dictionary) -> void:
	var kind := str(action.get("action","today"))
	if kind=="heard": mode="notebook"; notebook_section="heard"; build(); return
	if kind=="personal": mode="notebook"; notebook_section="personal"; build(); return
	if kind in ["portfolio","final"]:
		mode="dossier"; archive_tab="days" if kind=="portfolio" else "final"; day=GameState.current_day; build(); return
	if kind=="evening":
		if GameState.current_location==CoreLoopSystem.home(): close(); CoreLoopSystem.open_evening.call_deferred()
		else: map_selected=CoreLoopSystem.home(); mode="map"; build()
		return
	if kind in ["exploration","requirements","recognition","receipts","personal"]:
		mode="dossier"; archive_tab={"exploration":"life","requirements":"requirements","recognition":"recognition","receipts":"life","personal":"personal"}[kind]; build(); return
	super._guidance_action(action)

func _reference_picker(question: String) -> void:
	if is_instance_valid(detail): detail.queue_free()
	detail=panel(body,Vector2(540,150),Vector2(725,475))
	label(detail,"从真正留下的经历里选一件",Vector2(22,18),Vector2(625,44),23,BLUE)
	button(detail,"×",Vector2(663,16),Vector2(42,38),func() -> void: detail.queue_free())
	var rows := scroll_area(detail,Vector2(22,76),Vector2(680,370))
	var entries := CoreLoopSystem.reference_entries()
	for entry in entries:
		var choose := preload("res://scripts/ui/components/solmere_button.gd").new(); choose.text=str(entry.text); choose.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; choose.custom_minimum_size=Vector2(646,64); rows.add_child(choose)
		choose.pressed.connect(func() -> void:
			var s := ResidencySystem.state(); var references: Dictionary=s.get_or_add("final_references",{})
			var ids: Array=references.get_or_add(question,[])
			if not ids.has(entry.id):
				ids.append(entry.id); s.final_answers[question]=str(s.final_answers.get(question,""))+"\n"+str(entry.text)
			ResidencySystem.persist(); build())
	if entries.is_empty(): label(detail,"还没有可引用的生活材料。",Vector2(45,140),Vector2(620,90),24,BLUE)

func _hand(value: String, at: Vector2, dimensions: Vector2, point: int) -> Label:
	var words := label(body,value,at,dimensions,point,BLUE)
	var font := SystemFont.new(); font.font_names=PackedStringArray(["Segoe Script","KaiTi","Microsoft YaHei"])
	words.add_theme_font_override("font",font)
	return words
func _icon(parent: Node, kind: String, at: Vector2, dimensions: Vector2) -> Control:
	var icon := preload("res://scripts/ui/components/ink_icon.gd").new(); icon.kind=kind; icon.position=at; icon.size=dimensions; parent.add_child(icon); return icon
func _toggle_drawing() -> void:
	canvas.drawing=not canvas.drawing
	feedback.text=LocalizationSystem.text("画笔已拿起 · 再按画笔收起") if canvas.drawing else ""
func _photo_material_tray() -> void:
	_material_tray()
	var spread := detail.find_child("LooseMaterials",true,false)
	for piece in spread.get_children():
		if piece.get("item") is Dictionary and str(piece.item.get("kind",""))!="photo": piece.hide()

func _map() -> void:
	var viewport := Control.new(); viewport.position=Vector2(82,0); viewport.size=Vector2(1200,722)
	viewport.name="MapViewport"; viewport.mouse_filter=MOUSE_FILTER_IGNORE; body.add_child(viewport)
	map_board=load("res://scripts/residency/map_paper.gd").new()
	map_board.position=Vector2(45,-6); map_board.scale=Vector2.ONE*.83
	map_board.selected.connect(_map_select); viewport.add_child(map_board)
	var filters: Array=[]
	for i in 4:
		var b := button(viewport,["全部地点","去过的地方","听说的地方","当前线索"][i],Vector2(110+i*203,710),Vector2(191,36),func() -> void:
			map_board.filter_locations(i)
			for index in filters.size(): filters[index].selected=index==i)
		b.name="MapFilter_"+str(i); b.add_theme_font_size_override("font_size",15); b.clip_text=true; b.selected=i==0; filters.append(b)
	feedback.position=Vector2(195,676); feedback.size=Vector2(990,30)
	_map_select(GameState.current_location if map_selected.is_empty() else map_selected)

func _notebook_collection(section: String) -> void:
	var rows := scroll_area(body,Vector2(235,173),Vector2(1025,474))
	if section=="people":
		var seen := {}
		for fact in KnowledgeSystem.facts():
			var id := str(fact.get("source_npc_id",fact.get("subject_id","")))
			if not id.is_empty() and ScheduleSystem.residents.has(id): seen[id]=true
		for id in GameState.shared_state.get("linear_talk_counts_"+GameState.current_role,{}): seen[id]=true
		for id in seen:
			var entry := VBoxContainer.new(); rows.add_child(entry)
			var title := Label.new(); title.text=GuidanceSystem.source_name(str(id)); title.add_theme_font_size_override("font_size",26); entry.add_child(title)
			var words := Label.new(); words.custom_minimum_size=Vector2(935,52); words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			var facts: Array=KnowledgeSystem.facts().filter(func(fact: Dictionary) -> bool: return str(fact.get("source_npc_id",""))==str(id) or str(fact.get("subject_id",""))==str(id))
			words.text=LocalizationSystem.text("\n".join(facts.map(func(fact: Dictionary) -> String: return str(fact.get("text","")))) if not facts.is_empty() else "在小镇遇见过。下一次，听听对方的故事。")
			entry.add_child(words)
	elif section=="places":
		for id in ResidencySystem.state().visits:
			var b := preload("res://scripts/ui/components/solmere_button.gd").new(); b.text=TravelSystem.location_name(str(id))+"   →"; b.alignment=HORIZONTAL_ALIGNMENT_LEFT; b.custom_minimum_size=Vector2(965,62); rows.add_child(b)
			b.pressed.connect(func() -> void: map_selected=str(id); mode="map"; build())
	else:
		for id in ResidencySystem.state().materials:
			var item: Dictionary=ResidencySystem.state().materials[id]
			if str(item.get("kind",""))=="official": continue
			var b := preload("res://scripts/ui/components/solmere_button.gd").new(); b.text=str(item.get("title",id)); b.alignment=HORIZONTAL_ALIGNMENT_LEFT; b.custom_minimum_size=Vector2(965,60); rows.add_child(b); b.pressed.connect(_show_detail.bind(str(id)))
	if rows.get_child_count()==0: _hand("这一页还空着。\n新的相遇会慢慢留在这里。",Vector2(275,235),Vector2(700,125),28)

func _map_select(location: String) -> void:
	map_selected=location
	var status := GuidanceSystem.location_status(location)
	feedback.text=str(status.reason)
	var old := body.get_node_or_null("MapDetails")
	if old != null: body.remove_child(old); old.queue_free()
	if location==GameState.current_location: return
	var side := panel(body,Vector2(814,104),Vector2(455,510),Color("f5ecd8"))
	side.name="MapDetails"
	label(side,TravelSystem.location_name(location),Vector2(27,21),Vector2(363,45),28,BLUE)
	label(side,"从 "+TravelSystem.location_name(GameState.current_location)+" 出发",Vector2(27,76),Vector2(393,35),18,Color("6a8598"))
	var methods := [["walk","步行","沿路慢慢看"],["bus","公交","在站点间来往"],["friend","找人借车","省下走路的时间"],["taxi","出租车","尽快抵达"]]
	for i in methods.size():
		var method := str(methods[i][0])
		var route := TravelSystem.route(GameState.current_location,location,method,GameState.current_role,GameState.current_minute)
		var available := bool(route.get("available",false))
		var reason := str(route.get("reason",""))
		if available and int(route.cost)>GameState.money: available=false; reason="钱包余额不足"
		var b := button(side,"",Vector2(22,129+i*78),Vector2(411,69),_travel_selected.bind(method))
		b.variant="outlined"; b.refresh(); b.disabled=not available
		b.name="Travel"+method.capitalize(); b.tooltip_text=reason
		label(b,str(methods[i][1]),Vector2(15,7),Vector2(160,31),21,BLUE if available else Color("83919a"))
		var secondary := "%d 分钟 · %d 元" % [int(route.minutes),int(route.cost)] if bool(route.get("available",false)) else "暂不可用"
		var amount := label(b,secondary,Vector2(166,9),Vector2(225,27),18,BLUE if available else Color("83919a")); amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var why := label(b,str(methods[i][2]) if available else reason,Vector2(15,41),Vector2(380,23),14,Color("72889a")); why.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	label(side,"钱包  %d 元" % GameState.money,Vector2(29,463),Vector2(280,29),18,BLUE)
	var cancel := button(side,"×",Vector2(403,20),Vector2(32,32),func() -> void: _map_select(GameState.current_location))
	cancel.name="TravelCancel"; cancel.tooltip_text=LocalizationSystem.text("收起地点")

func _travel_selected(method: String) -> void:
	if travel_pending or SceneRouter.transitioning: return
	var route := TravelSystem.route(GameState.current_location,map_selected,method,GameState.current_role,GameState.current_minute)
	if not bool(route.get("available",false)): feedback.text=LocalizationSystem.text(str(route.get("reason","无法出发"))); return
	var confirmation := preload("res://scripts/ui/components/confirm_sheet.gd").new()
	confirmation.heading=str(route.label)+"前往"+TravelSystem.location_name(map_selected)
	confirmation.description="所需时间    %d 分钟\n花费            %s\n抵达时间    %s" % [int(route.minutes),"免费" if int(route.cost)==0 else "%d 元" % int(route.cost),GuidanceSystem.time_text(int(route.arrival))]
	if not route.get("conflicts",[]).is_empty(): confirmation.description+="\n可能错过："+"、".join(route.conflicts)
	confirmation.confirm_text="出发"; add_child(confirmation)
	confirmation.accepted.connect(func() -> void:
		travel_pending=true
		var result := SceneRouter.travel_to(map_selected,method)
		if bool(result.get("ok",false)): close()
		else: travel_pending=false; confirmation.queue_free(); feedback.text=str(result.message))
