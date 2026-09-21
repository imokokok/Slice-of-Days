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
	body.scale=Vector2.ONE*minf(1.0,minf(size.x*.78/DOSSIER_SIZE.x,size.y*.82/DOSSIER_SIZE.y))

func _input(event: InputEvent) -> void:
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
	dim.color=Color("233f50",.22)
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
		var paper := preload("res://scripts/ui/components/paper_page.gd").new()
		paper.position=Vector2(0,32); paper.size=Vector2(1340,718); paper.mouse_filter=MOUSE_FILTER_IGNORE; body.add_child(paper)
	else:
		var clean := StyleBoxFlat.new(); clean.bg_color=Color("edf2f3"); clean.set_corner_radius_all(10)
		body.add_theme_stylebox_override("panel",clean)
	feedback=label(body,"",Vector2(32,712),Vector2(1250,30),17,BLUE)
	if mode in ["pause","settings"]:
		if mode=="pause": body.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		var menu := preload("res://scripts/ui/components/runtime_menu.gd").new()
		menu.owner_ui=self; menu.settings=mode=="settings"; body.add_child(menu)
		return
	var names := ["随身本","档案","相机","录音机"]
	var english := ["Notebook","Archive","Camera","Recorder"]
	var targets := ["notebook","dossier","gallery","sound_library"]
	for i in 4:
		var chosen: bool = mode==targets[i] or (i==0 and mode in ["home","map","today","knowledge","fieldbook","bag"])
		var b := _tab(names[i],english[i],Vector2(90+i*270,-38 if chosen else -30),Vector2(263,78 if chosen else 70),i,chosen,_switch_object.bind(targets[i]))
		b.name="ObjectTab_"+targets[i]
	button(body,"收起 · "+SettingsSystem.binding_text("ui_cancel"),Vector2(1190,-20),Vector2(138,40),close)
	match mode:
		"bag": _inventory()
		"counter": _counter()
		"proofs": _proofs()
		"controls": _home()
		"dossier": _archive()
		"gallery":
			button(body,"拿起相机",Vector2(40,84),Vector2(220,42),_home_action.bind("camera"))
			_browser("photo")
		"sound_library":
			button(body,"拿起录音机",Vector2(40,84),Vector2(220,42),_home_action.bind("recorder"))
			_browser("sound")
		"map": _map()
		"today": _notebook_page()
		"knowledge": _knowledge()
		"fieldbook": _materials()
		_:
			mode="notebook"
			for i in 4:
				var targets2 := ["map","today","knowledge","bag"]
				button(body,["随身地图","计划与时间","认识的人与地方","打开随身包"][i],Vector2(105+i*282,82),Vector2(268,38),_switch_object.bind(targets2[i]))
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
		label(body,"Solmere / 永居申请",Vector2(100,90),Vector2(1050,65),38,BLUE)
		var names := ["申请要求","个人信息","生活记录","居民认可","七天作品集","最终文件"]
		var keys := ["requirements","personal","life","recognition","days","final"]
		for i in 6:
			var b := button(body,names[i],Vector2(100+(i%3)*385,205+(i/3)*205),Vector2(350,175),func() -> void: archive_tab=keys[i]; build())
			b.name="ArchiveSection_"+keys[i]
		return
	var keys := ["requirements","personal","life","recognition","days","final"]
	var titles := ["申请要求","个人信息","生活记录","居民认可","七天作品集","最终文件"]
	var translations := ["Requirements","Personal","Life Log","Recognition","Seven Days Portfolio","Final Paper"]
	for i in keys.size():
		var target: String = keys[i]
		var chosen := target==archive_tab
		var b := _tab(titles[i],translations[i],Vector2(98+i*201,62 if chosen else 70),Vector2(198,72 if chosen else 64),i,chosen,func() -> void: archive_tab=target; WorldSound.play_ui("paper"); build())
		b.name="ArchiveTab_"+target
	match archive_tab:
		"requirements":
			_requirements_sheet()
		"final": _final_paper()
		"days":
			for i in 7:
				var d := i+1
				var b := button(body,"%02d" % d,Vector2(290+i*105,138),Vector2(85,35),func() -> void: day=d; build())
				b.name="PortfolioDay_%02d" % d
				b.selected=day==d
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
	canvas.position=Vector2(103,177); canvas.size=Vector2(1200,460)
	canvas.pieces=pages[key]
	canvas.page_id=key
	canvas.read_only=not ResidencySystem.state().submitted.is_empty() and key!="notebook"
	body.add_child(canvas)
	canvas.changed.connect(func() -> void:
		if key=="day_%d" % GameState.current_day: ResidencySystem._record_organize()
		ResidencySystem.persist())
	canvas.selection_changed.connect(_selection_toolbar)
	if not canvas.read_only:
		button(body,"＋ 素材",Vector2(105,654),Vector2(110,36),_material_tray)
		button(body,"＋ 文字",Vector2(225,654),Vector2(110,36),_write_piece)
		button(body,"画笔",Vector2(345,654),Vector2(110,36),func() -> void: canvas.drawing=not canvas.drawing; feedback.text="画笔已拿起 · 再按画笔收起" if canvas.drawing else "")

func _selection_toolbar() -> void:
	if is_instance_valid(selection_tools): selection_tools.queue_free()
	if not is_instance_valid(canvas) or canvas.selected<0: return
	selection_tools=Control.new(); selection_tools.position=Vector2(465,650); body.add_child(selection_tools)
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
		_official(questions[i],Vector2(110,148+i*91),Vector2(1140,30),21)
		var answer := edit(body,str(s.final_answers.get(key,"")),Vector2(110,181+i*91),Vector2(1140,50),func(value: String) -> void: s.final_answers[key]=value,"")
		answer.editable=s.submitted.is_empty()
	label(body,"签名",Vector2(110,624),Vector2(80,35),20,BLUE)
	var signature := edit(body,str(s.final_answers.get("signature","")),Vector2(195,620),Vector2(250,40),func(value: String) -> void: s.final_answers.signature=value,"")
	signature.editable=s.submitted.is_empty()
	label(body,"日期  Day %02d" % GameState.current_day,Vector2(490,624),Vector2(300,35),20,BLUE)
	button(body,"提交申请",Vector2(970,622),Vector2(260,40),func() -> void:
		var result := ResidencySystem.submit_free_application()
		build(); feedback.text=str(result.message))

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

func _tab(cn: String, en: String, at: Vector2, dimensions: Vector2, palette: int, chosen: bool, action: Callable) -> Button:
	if mode not in ["notebook","today","dossier","knowledge","fieldbook"]:
		var clean := button(body,cn+" / "+en,at,dimensions,action)
		clean.selected=chosen
		return clean
	var tab_button := TAB.new()
	tab_button.chinese=cn; tab_button.english=en; tab_button.position=at; tab_button.size=dimensions
	tab_button.tint=[Color("a4c6df"),Color("f3eee1"),LEMON][palette%3]
	tab_button.chosen=chosen; tab_button.pressed.connect(action); body.add_child(tab_button)
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
	browser.kind=kind; browser.owner_ui=self; browser.position=Vector2(85,142); body.add_child(browser)

func _notebook_page() -> void:
	for i in 3:
		var key: String=["today","heard","personal"][i]
		var b := button(body,["TODAY · 今天","HEARD · 听说了","PERSONAL · 私人"][i],Vector2(85+i*390,160),Vector2(365,48),func() -> void: notebook_section=key; build())
		b.selected=notebook_section==key
	if notebook_section=="today":
		label(body,"Day %02d · 今天从这里开始" % GameState.current_day,Vector2(100,245),Vector2(1100,55),29,BLUE)
		var tasks := GuidanceSystem.must_objectives()
		for i in tasks.size():
			var row: Dictionary=tasks[i]
			var check := CheckBox.new(); check.text=str(row.text); check.button_pressed=bool(row.done)
			check.position=Vector2(100,320+i*82); check.size=Vector2(1090,62); check.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			check.name="TaskCheck_"+str(i); body.add_child(check); task_checks.append(check)
			check.pressed.connect(func() -> void: _refresh_checks(); _guidance_action(row))
		label(body,"完成行动后会自动记下。选择一项，看看下一步去哪。",Vector2(100,620),Vector2(1090,40),20,BLUE)
	elif notebook_section=="heard":
		var rows := scroll_area(body,Vector2(90,245),Vector2(1150,440))
		var leads := GuidanceSystem.leads()
		if leads.is_empty(): label(body,"还没听到新的线索。沿街和遇见的人说说话吧。",Vector2(100,300),Vector2(1050,60),24,BLUE)
		for lead in leads:
			var row := HBoxContainer.new(); rows.add_child(row)
			var words := Label.new(); words.text=str(lead.text)+"\n— "+GuidanceSystem.source_name(str(lead.source)); words.custom_minimum_size=Vector2(800,85); words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; row.add_child(words)
			var follow := preload("res://scripts/ui/components/solmere_button.gd").new(); follow.text="取消追踪" if str(GuidanceSystem.state().tracked_lead)==str(lead.id) else "追踪"; follow.disabled=not bool(lead.available); row.add_child(follow)
			follow.pressed.connect(func() -> void: GuidanceSystem.track("" if str(GuidanceSystem.state().tracked_lead)==str(lead.id) else str(lead.id)); build())
			var map := preload("res://scripts/ui/components/solmere_button.gd").new(); map.text="看地图"; row.add_child(map); map.pressed.connect(func() -> void: _guidance_action({"action":"map","location":str(lead.location)}))
	else:
		label(body,"留给自己的话",Vector2(100,245),Vector2(1050,55),29,BLUE)
		var s := ResidencySystem.state()
		var note := edit(body,str(s.get("private_note","")),Vector2(100,315),Vector2(1110,345),func(value: String) -> void: s.private_note=value; ResidencySystem.persist(),"写下临时想法，或自己想继续的事……")
		note.name="PrivateNotebookText"

func _refresh_checks() -> void:
	var rows := GuidanceSystem.must_objectives()
	for i in mini(rows.size(),task_checks.size()):
		if is_instance_valid(task_checks[i]): task_checks[i].set_pressed_no_signal(bool(rows[i].done))


func _guidance_action(action: Dictionary) -> void:
	var kind := str(action.get("action","today"))
	if kind=="heard": mode="notebook"; notebook_section="heard"; build(); return
	if kind in ["exploration","requirements","recognition","receipts","personal"]:
		mode="dossier"; archive_tab={"exploration":"life","requirements":"requirements","recognition":"recognition","receipts":"life","personal":"personal"}[kind]; build(); return
	super._guidance_action(action)
