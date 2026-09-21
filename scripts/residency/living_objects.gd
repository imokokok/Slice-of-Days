extends "res://scripts/residency/paper_overlay.gd"
## The same physical folio holds every carried object, with separate private pages.
const CANVAS = preload("res://scripts/residency/living_canvas.gd")
const BLUE := Color("31658b")
const LEMON := Color("eed577")
const TAB = preload("res://scripts/residency/paper_tab.gd")
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
	var style: StyleBoxFlat = result.get_theme_stylebox("panel").duplicate()
	style.shadow_size=0; style.border_color=BLUE.lightened(.5)
	result.add_theme_stylebox_override("panel",style)
	return result

func build() -> void:
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
	for i in 4:
		var chosen: bool=mode==targets[i] or (i==0 and mode in ["home","map","today","knowledge","fieldbook","bag"])
		var b := button(body,names[i],Vector2(212+i*222,-42),Vector2(214,39),_switch_object.bind(targets[i]))
		b.name="ObjectTab_"+targets[i]; b.selected=chosen
		b.add_theme_font_size_override("font_size",17)
		if not chosen: b.add_theme_color_override("font_color",Color("faf8ef",.82))
	var back := button(body,"×",Vector2(1290,-42),Vector2(42,38),close)
	back.tooltip_text=SettingsSystem.binding_text("ui_cancel")+" 收起"
	back.add_theme_color_override("font_color",Color.WHITE)
	match mode:
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
		var titles := ["申请要求","个人信息","生活记录","居民认可","七天作品集","最终文件"]
		var translations := ["REQUIREMENTS","PERSONAL","LIFE LOG","RECOGNITION","SEVEN DAYS","FINAL PAPER"]
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
	var titles := ["申请要求","个人信息","生活记录","居民认可","七天作品集","最终文件"]
	var translations := ["Requirements","Personal","Life Log","Recognition","Seven Days Portfolio","Final Paper"]
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
			for i in 7:
				var d := i+1
				var b := button(body,"%02d" % d,Vector2(35,166+i*70),Vector2(66,62),func() -> void: day=d; build())
				b.name="PortfolioDay_%02d" % d
				b.selected=day==d
			_hand("Day %02d" % day,Vector2(139,114),Vector2(510,64),42)
			_free_page("day_%d" % day)
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
	canvas.read_only=not ResidencySystem.state().submitted.is_empty() and key!="notebook"
	body.add_child(canvas)
	canvas.changed.connect(func() -> void:
		if key=="day_%d" % GameState.current_day: ResidencySystem._record_organize()
		ResidencySystem.persist())
	canvas.selection_changed.connect(_selection_toolbar)
	if not canvas.read_only:
		var tools := [["add","素材","Add"],["text","文字","Text"],["photo","照片","Photo"],["draw","画笔","Draw"]]
		for i in tools.size():
			var action: Callable=[_material_tray,_write_piece,_photo_material_tray,_toggle_drawing][i]
			var tool_button := button(body,"",Vector2(1220,172+i*111),Vector2(82,101),action)
			tool_button.variant="outlined"; tool_button.refresh()
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
	if is_instance_valid(detail): detail.queue_free()
	detail=panel(body,Vector2(825,150),Vector2(470,485),Color("faf7ee"))
	button(detail,"收起素材 ×",Vector2(275,8),Vector2(180,35),func() -> void: detail.queue_free())
	label(detail,"拖一张到纸上",Vector2(18,13),Vector2(245,32),19,BLUE)
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
		var kind := str(item.get("kind","note"))
		piece.size=Vector2([170,184,160,176][index%4],155 if kind=="photo" else 172 if kind=="receipt" else 112+(index%3)*12)
		piece.position=Vector2(24+(index%2)*207+sin(index*2.0)*8,18+floori(index/2.0)*178+(index%2)*14)
		piece.pivot_offset=piece.size*.5; piece.rotation=[-.065,.045,-.035,.075][index%4]
		spread.add_child(piece)
		piece.activated.connect(func() -> void:
			canvas._drop_data(Vector2(420,210),{"residency_material":id}); detail.queue_free())
		bottom=maxf(bottom,piece.position.y+piece.size.y+22)
		index+=1
	spread.custom_minimum_size=Vector2(430,maxf(410,bottom))
	if index==0: label(spread,"生活留下的纸片，
会慢慢聚在这里。",Vector2(45,90),Vector2(350,100),22,BLUE)

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
	if not s.has("final_answers"): s.final_answers={}
	var questions := ["最初是什么让你来到 Solmere？","真正生活在这里之后，什么最吸引你？","什么经历改变了你对 Solmere 最初的理解？","如果只能留下这七天中的一个瞬间，你会选择什么？为什么？","如果 Solmere 成为你的家，你希望自己成为这里怎样的一部分？"]
	for i in 5:
		var key := str(i)
		_official(questions[i],Vector2(110,148+i*91),Vector2(965,30),21)
		var reference := button(body,"引用经历",Vector2(1110,143+i*91),Vector2(140,34),_reference_picker.bind(key))
		reference.name="Reference_"+key; reference.disabled=not s.submitted.is_empty(); reference.add_theme_font_size_override("font_size",16)
		var answer := edit(body,str(s.final_answers.get(key,"")),Vector2(110,181+i*91),Vector2(1140,50),func(value: String) -> void: s.final_answers[key]=value,"")
		answer.editable=s.submitted.is_empty()
	label(body,"签名",Vector2(110,624),Vector2(80,35),20,BLUE)
	var signature := edit(body,str(s.final_answers.get("signature","")),Vector2(195,620),Vector2(250,40),func(value: String) -> void: s.final_answers.signature=value,"")
	signature.editable=s.submitted.is_empty()
	label(body,"日期  Day %02d" % GameState.current_day,Vector2(490,624),Vector2(300,35),20,BLUE)
	button(body,"提交申请",Vector2(970,622),Vector2(260,40),func() -> void:
		var confirm := preload("res://scripts/ui/components/confirm_sheet.gd").new()
		confirm.heading="提交居住申请？"; confirm.description="提交后，这七天的作品与最终文件将被收存。\n\n准备好把它交给 Solmere 了吗？"; confirm.confirm_text="提交申请"
		confirm.accepted.connect(func() -> void:
			var result := ResidencySystem.submit_free_application()
			confirm.queue_free(); build(); feedback.text=str(result.message))
		add_child(confirm))

func _counter() -> void:
	_official("Solmere · 居住申请",Vector2(110,145),Vector2(1100,60),35)
	label(body,"把这七天的生活留在纸上。准备好后，来交给我们。",Vector2(110,227),Vector2(1100,65),24,BLUE)
	var collect := button(body,"展开档案" if ResidencySystem.state().packet else "领取申请档案",Vector2(110,330),Vector2(1090,55),func() -> void:
		var message := ResidencySystem.collect_packet()
		if ResidencySystem.state().packet: mode="dossier"; archive_tab="requirements"; build()
		feedback.text=message)
	collect.name="CollectStarterPacket"
	button(body,"填写与提交最终文件",Vector2(110,425),Vector2(1090,55),func() -> void: mode="dossier"; archive_tab="final"; build())
	button(body,"领取作品与贡献证明",Vector2(110,520),Vector2(1090,55),func() -> void: mode="proofs"; build()).name="CommunityProofCounter"

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
	label(body,"今天带在身边的东西",Vector2(110,90),Vector2(900,45),28,BLUE)
	button(body,"纸片与纪念物 →",Vector2(970,92),Vector2(310,42),_switch_object.bind("fieldbook"))
	var rows := scroll_area(body,Vector2(110,160),Vector2(1170,490))
	var grid := GridContainer.new(); grid.columns=4; grid.add_theme_constant_override("h_separation",14); grid.add_theme_constant_override("v_separation",15); rows.add_child(grid)
	var catalog: Dictionary = {}
	for shop in JSON.parse_string(FileAccess.get_file_as_string("res://data/economy/shops.json")).shops:
		for item in shop.get("items",[]): catalog[str(item.id)]=item
	for id in GameState.inventory:
		var count := int(GameState.inventory[id])
		if count<=0: continue
		var item: Dictionary = catalog.get(id,{"name":id,"description":"一路带来的小物件。"})
		var card := Control.new(); card.custom_minimum_size=Vector2(272,211); grid.add_child(card)
		var sketch := preload("res://scripts/ui/goods_sketch.gd").new(); sketch.item_id=str(id); sketch.position=Vector2(77,0); sketch.size=Vector2(118,100); card.add_child(sketch)
		label(card,str(item.name)+"  ×"+str(count),Vector2(8,105),Vector2(260,35),22,BLUE).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		button(card,"拿近看看",Vector2(35,150),Vector2(205,36),func() -> void:
			if is_instance_valid(detail): detail.queue_free()
			detail=panel(body,Vector2(390,220),Vector2(600,300))
			label(detail,str(item.name),Vector2(30,30),Vector2(530,45),28,BLUE)
			label(detail,str(item.get("description","")),Vector2(30,98),Vector2(530,110),23,BLUE)
			button(detail,"放回包里",Vector2(190,236),Vector2(220,40),func() -> void: detail.queue_free()))
	if grid.get_child_count()==0: label(body,"包里还空着。",Vector2(110,245),Vector2(1040,60),25,BLUE)
	button(body,"← 回到随身本",Vector2(110,671),Vector2(300,40),_switch_object.bind("notebook"))

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
	var marks := preload("res://scripts/residency/requirements_ink.gd").new()
	marks.position.x=24; marks.size=DOSSIER_SIZE; body.add_child(marks)
	_official("S O L M E R E\n永 居 申 请 计 划",Vector2(110,153),Vector2(650,46),15)
	_official("为有梦的人而生",Vector2(110,206),Vector2(680,61),46)
	_official("感谢你对 Solmere 的关注。\n这是一个为期七天的社区驻留计划，\n面向希望在这里体验、创造、交流，\n并与小镇共同成长的人。",Vector2(110,285),Vector2(645,117),23)
	var postcard := TextureRect.new()
	postcard.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; postcard.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	postcard.texture=load("res://art/ui/living-postcard.png")
	postcard.position=Vector2(740,145); postcard.size=Vector2(270,267)
	postcard.mouse_filter=MOUSE_FILTER_IGNORE; body.add_child(postcard)
	var logo := label(body,"Solmere",Vector2(1030,175),Vector2(260,70),48,BLUE)
	var script_font := SystemFont.new(); script_font.font_names=PackedStringArray(["Segoe Script","KaiTi"])
	logo.add_theme_font_override("font",script_font)
	label(body,"人与人，\n地方，故事，\n让明天更好。",Vector2(1060,285),Vector2(190,105),23,BLUE)
	_official("申 请 要 求",Vector2(110,403),Vector2(170,34),22)
	var titles := ["展示自己","生活与记录","获得认可","完成七天作品集","最终记录"]
	var descriptions := ["用你喜欢的方式\n让我们认识你。","在 Solmere 生活七天，\n记录你遇见的人、\n地方与事情。","获得 12 位居民认可。","七天每天完成一页\n属于自己的作品。","第七天结束后\n完成最终文件\n并提交申请。"]
	for i in 5:
		var x := 110+i*234
		_official("%02d" % (i+1),Vector2(x,445),Vector2(80,37),27)
		var title := _official(titles[i],Vector2(x,533),Vector2(212,35),23); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var words := _official(descriptions[i],Vector2(x,576),Vector2(212,73),20); words.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label(body,"这里没有唯一的答案，\n但我们始终欢迎认真生活的人。",Vector2(110,673),Vector2(680,55),22,BLUE)
	_official("S O L M E R E\n一 座 更 温 柔 的 明 天",Vector2(1030,681),Vector2(260,45),15)

func _browser(kind: String) -> void:
	var browser := preload("res://scripts/ui/components/media_browser.gd").new()
	browser.kind=kind; browser.owner_ui=self; browser.position=Vector2(65,50); body.add_child(browser)

func _notebook_page() -> void:
	var categories := [["today","今天","TODAY"],["heard","听说了","HEARD"],["people","人物","PEOPLE"],["places","地点","PLACES"],["personal","私人","PERSONAL"],["materials","收藏","MATERIALS"]]
	for i in categories.size():
		var key: String=categories[i][0]
		var b := button(body,str(categories[i][1])+"\n"+str(categories[i][2]),Vector2(40,102+i*78),Vector2(162,70),func() -> void: notebook_section=key; build())
		b.selected=notebook_section==key; b.add_theme_font_size_override("font_size",16); b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	_hand("Day %02d" % GameState.current_day,Vector2(242,90),Vector2(370,54),34)
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
			var follow := preload("res://scripts/ui/components/solmere_button.gd").new(); follow.text="取消追踪" if str(GuidanceSystem.state().tracked_lead)==str(lead.id) else "追踪"; follow.disabled=not bool(lead.available); actions.add_child(follow)
			follow.pressed.connect(func() -> void: GuidanceSystem.track("" if str(GuidanceSystem.state().tracked_lead)==str(lead.id) else str(lead.id)); build())
			var map := preload("res://scripts/ui/components/solmere_button.gd").new(); map.text="看地图"; actions.add_child(map); map.pressed.connect(func() -> void: _guidance_action({"action":"map","location":str(lead.location)}))
	else:
		var s := ResidencySystem.state()
		var note := edit(body,str(s.get("private_note","")),Vector2(242,176),Vector2(370,178),func(value: String) -> void: s.private_note=value; ResidencySystem.persist(),"留给自己的话……")
		note.name="PrivateNotebookText"; note.add_theme_font_override("font",PaperLanguage.handwriting); note.add_theme_font_size_override("font_size",25)
		var plan := LineEdit.new(); plan.name="PersonalPlanText"; plan.position=Vector2(242,369); plan.size=Vector2(258,43); plan.placeholder_text="想做的一件小事"; body.add_child(plan)
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

func _refresh_checks() -> void:
	var rows := GuidanceSystem.must_objectives()
	for i in mini(rows.size(),task_checks.size()):
		if is_instance_valid(task_checks[i]): task_checks[i].set_pressed_no_signal(bool(rows[i].done))


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
	feedback.text="画笔已拿起 · 再按画笔收起" if canvas.drawing else ""
func _photo_material_tray() -> void:
	_material_tray()
	var spread := detail.find_child("LooseMaterials",true,false)
	for piece in spread.get_children():
		if piece.get("item") is Dictionary and str(piece.item.get("kind",""))!="photo": piece.hide()

func _map() -> void:
	var viewport := panel(body,Vector2(28,26),Vector2(1284,646),Color("f1ead8"))
	viewport.name="MapViewport"; viewport.clip_contents=true
	map_board=load("res://scripts/residency/map_paper.gd").new()
	map_board.position=Vector2(130,0); map_board.scale=Vector2.ONE*.90
	map_board.selected.connect(_map_select); viewport.add_child(map_board)
	var filters: Array=[]
	for i in 4:
		var b := button(viewport,["全部地点","去过的地方","听说的地方","当前线索"][i],Vector2(10,158+i*56),Vector2(115,46),func() -> void:
			map_board.filter_locations(i)
			for index in filters.size(): filters[index].selected=index==i)
		b.name="MapFilter_"+str(i); b.add_theme_font_size_override("font_size",15); b.clip_text=true; b.selected=i==0; filters.append(b)
	var lead := GuidanceSystem.tracked_lead()
	if not lead.is_empty():
		label(body,"听说："+str(lead.get("text","")),Vector2(74,681),Vector2(1120,31),17,Color("fff9e9"))
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
			words.text="\n".join(facts.map(func(fact: Dictionary) -> String: return str(fact.get("text","")))) if not facts.is_empty() else "在小镇遇见过。下一次，听听对方的故事。"
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
	var old := body.get_node_or_null("MapDetails")
	if old != null: body.remove_child(old); old.queue_free()
	if location==GameState.current_location: return
	var side := panel(body,Vector2(814,104),Vector2(455,510),Color("f1f5f4",.98))
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
	cancel.name="TravelCancel"; cancel.tooltip_text="收起地点"

func _travel_selected(method: String) -> void:
	if travel_pending or SceneRouter.transitioning: return
	var route := TravelSystem.route(GameState.current_location,map_selected,method,GameState.current_role,GameState.current_minute)
	if not bool(route.get("available",false)): feedback.text=str(route.get("reason","无法出发")); return
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
