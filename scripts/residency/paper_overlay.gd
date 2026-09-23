extends Control
signal tool_requested(tool: String)
const INK := Color("405452")
const PAPER := Color("f6eedc")
const SKY := Color("a8cedb")
const PIECE = preload("res://scripts/residency/paper_piece.gd")
var mode := "dossier"
var tab := "packet"
var document_id := "welcome"
var day := 1
var filter := "all"
var detail_id := ""
var review_index := -1
var body: Control
var feedback: Label
var detail: Control
var audio_player: AudioStreamPlayer
var audio_wave: PackedFloat32Array = []
var map_board: Control
var map_drag := false
var map_selected := ""
var travel_pending := false
var remark: TextEdit
var note_selection := ""
var exploration_kind := "discover"
var exploration_location := ""
var exploration_text := ""
var exploration_evidence := ""
var show_dossier_reference := false
var proof_filter := "all"
var photo_picker_page := 0

const DOSSIER_SIZE := Vector2(1340, 750)
const DOSSIER_PREVIEW_POSITION := Vector2(130, 15)
const DOSSIER_PREVIEW_SIZE := Vector2(1080, 720)
const DOSSIER_REFERENCE_SIZE := Vector2(1536, 1024)
const DOSSIER_PHOTO_SOURCE := Rect2(245, 365, 390, 315)
const PHOTO_PICKER_PAGE_SIZE := 6

func _ready() -> void:
	add_to_group("meta_modal")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	day = clampi(GameState.current_day,1,7)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"])
	theme = preload("res://art/ui/solmere_ui.tres").duplicate()
	theme.default_font = font
	theme.default_font_size = 21
	ResidencySystem._sync_sources()
	build()

func panel(parent: Node, at: Vector2, dimensions: Vector2, color := PAPER) -> Panel:
	var node := Panel.new()
	node.position = at
	node.size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("c5b998")
	style.set_border_width_all(1)
	style.shadow_color = Color(0.12,0.1,0.08,0.13)
	style.shadow_size = 6
	node.add_theme_stylebox_override("panel",preload("res://scripts/ui/production_assets.gd").paper("paper_large",color,14))
	parent.add_child(node)
	return node

func label(parent: Node, text: String, at: Vector2, dimensions: Vector2, point := 21, color := INK) -> Label:
	var node := Label.new()
	node.position = at
	node.size = dimensions
	node.custom_maximum_size.x=dimensions.x
	node.text = LocalizationSystem.text(text)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",point)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func button(parent: Node, text: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var node := Button.new()
	node.text = LocalizationSystem.text(text)
	node.position = at
	node.size = dimensions
	node.add_theme_color_override("font_color",INK)
	node.add_theme_color_override("font_placeholder_color",Color("959d8c"))
	node.add_theme_color_override("font_hover_color",Color("986045"))
	for state_name in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e4ebdf") if state_name == "hover" else Color("e9e0cc")
		style.set_corner_radius_all(2)
		style.content_margin_left = 10
		style.content_margin_right = 10
		node.add_theme_stylebox_override(state_name,style)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func edit(parent: Node, value: String, at: Vector2, dimensions: Vector2, action: Callable, placeholder := "写在这里…") -> TextEdit:
	var node := TextEdit.new()
	node.position = at
	node.size = dimensions
	node.text = value
	node.placeholder_text = LocalizationSystem.text(placeholder)
	node.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	node.add_theme_color_override("font_color",INK)
	node.add_theme_color_override("background_color",Color("fffaf0"))
	node.add_theme_color_override("font_placeholder_color",Color("8e9888"))
	node.add_theme_font_size_override("font_size",19)
	node.text_changed.connect(func() -> void: action.call(node.text))
	parent.add_child(node)
	return node

func scroll_area(parent: Node, at: Vector2, dimensions: Vector2) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.position = at
	scroll.size = dimensions
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",14)
	scroll.add_child(box)
	return box

func build() -> void:
	# Remove the prior page before adding the next one.  This keeps the new page
	# tabs addressable during the same click instead of briefly competing with
	# queued-for-deletion controls from the previous sheet.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	audio_player = null
	detail = null
	var dim := ColorRect.new()
	dim.color = Color("17262a",0.58)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	# Supplied dossier sheets are artwork, not a generic window.  Present them
	# whole and centered so their paper edges and right-side tabs remain usable.
	if mode == "dossier" and show_dossier_reference and tab in ["requirements", "days", "exploration", "recognition", "personal", "proof"]:
		_dossier_reference_page()
		return
	body = panel(self,Vector2.ZERO,DOSSIER_SIZE,Color("d5c8a7"))
	# Keep the editable dossier centered at every supported window size/aspect ratio.
	body.set_anchors_preset(Control.PRESET_CENTER)
	body.offset_left = -DOSSIER_SIZE.x * 0.5
	body.offset_top = -DOSSIER_SIZE.y * 0.5
	body.offset_right = DOSSIER_SIZE.x * 0.5
	body.offset_bottom = DOSSIER_SIZE.y * 0.5
	body.clip_contents = true
	var names := {"dossier":"RP-07  /  居住档案","organize":"回房整理  /  桌上的纸","fieldbook":"素材本","gallery":"相册","map":"Solmere  /  随身地图","home":"随身物品","pause":"暂停","controls":"操作","settings":"设置","counter":"社区中心  /  资料柜台","proofs":"领取证明","notebook":"私人手记"}
	label(body,str(names.get(mode,mode)),Vector2(32,20),Vector2(1000,42),30)
	button(body,"收起  Esc",Vector2(1150,22),Vector2(154,38),close)
	feedback = label(body,"",Vector2(32,700),Vector2(1270,38),18,Color("935d42"))
	match mode:
		"today": _today()
		"knowledge": _knowledge()
		"dossier": _dossier()
		"organize": _organize()
		"fieldbook","gallery": _materials()
		"home","pause","controls","settings": _home()
		"map": _map()
		"counter": _counter()
		"proofs": _proofs()
		"notebook": _notebook()
	preload("res://scripts/ui/solmere_motion.gd").page_turn(body,SettingsSystem.reduced_motion())

func close() -> void:
	if not ResidencySystem.persist():
		if is_instance_valid(feedback): feedback.text="保存失败，内容仍保留在当前页面。请稍后重试。"
		return
	WorldSound.play_ui("paper")
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if is_instance_valid(detail): detail.queue_free(); detail = null; detail_id = ""
			elif mode in ["controls","settings"]: mode = "home"; build()
			else: close()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F and not detail_id.is_empty() and not get_viewport().gui_get_focus_owner() is TextEdit:
			_attach(detail_id)
			get_viewport().set_input_as_handled()

func _dossier() -> void:
	var names := {"packet":"申请进度","requirements":"要求","days":"七日","proof":"证明","recognition":"认可","personal":"个人","loose":"散页"}
	if tab == "packet":
		_dossier_dashboard()
		return
	if tab == "starter":
		_starter_packet()
		return
	if show_dossier_reference and tab in ["requirements", "days", "exploration", "recognition", "personal", "proof"]:
		_dossier_reference_page()
		return
	var x := 28.0
	for key in names:
		var entry := button(body,str(names[key]),Vector2(x,78),Vector2(172,42),_select_dossier_tab.bind(str(key)))
		entry.name = "DossierTab_"+str(key)
		x += 186
	match tab:
		"packet": _starter_packet()
		"document": _starter_reader()
		"cover": _dossier_cover()
		"requirements": _requirements()
		"days": _day_page()
		"recognition": _recognition()
		"personal": _personal_page()
		"proof": _filed("proof")
		"loose": _filed("loose")
		"receipts": _living_receipts()
		"exploration": _explore_records()
	if not ResidencySystem.state().packet:
		feedback.text = LocalizationSystem.text("可以先填写草稿；到社区中心领取 RP-07 资料袋后即可归档与提交。")

func _dossier_dashboard() -> void:
	# The illustrated dossier is the whole surface on its home screen. Remove
	# the generic paper window chrome so only the book floats over the world.
	body.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for chrome in body.get_children():
		chrome.hide()
	var preview := TextureRect.new()
	preview.name = "DossierPreview"
	preview.texture = load("res://art/ui/dossier-open-reference.png")
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(preview)
	# TextureRect resets itself to the texture's native dimensions when its
	# expansion mode changes, so assign the designed rect after adding it.
	preview.position = DOSSIER_PREVIEW_POSITION
	preview.size = DOSSIER_PREVIEW_SIZE
	_dashboard_cover_photo()
	var audit := ResidencySystem.audit()
	var progress: Dictionary = audit.get("progress", {})
	var requirements: Dictionary = audit.get("requirements", {})
	var actions := [
		{"id":"days", "source":Rect2(770, 278, 570, 102), "tooltip":"七日作品集", "status":"%d / 7" % _audit_count(progress, "pages")},
		{"id":"income", "source":Rect2(770, 380, 570, 90), "tooltip":"收入证明", "status":"%d / 1" % _audit_count(progress, "income")},
		{"id":"exploration", "source":Rect2(770, 470, 570, 90), "tooltip":"探索材料", "status":"%d / 3" % _audit_count(progress, "exploration")},
		{"id":"recognition", "source":Rect2(770, 560, 570, 90), "tooltip":"居民认可", "status":"%d / 12" % _audit_count(progress, "recognition")},
		{"id":"contribution", "source":Rect2(770, 650, 570, 90), "tooltip":"贡献记录", "status":"已完成" if bool(requirements.get("contribution", false)) else "未完成"},
		{"id":"personal", "source":Rect2(770, 740, 570, 90), "tooltip":"个人页", "status":"已完成" if bool(requirements.get("personal", false)) else "未完成"},
		{"id":"final", "source":Rect2(770, 830, 570, 90), "tooltip":"最终居住说明", "status":"已完成" if bool(requirements.get("why_stay", false)) else ("可填写" if GameState.current_day >= 7 else "第 7 天开放")}
	]
	for action in actions:
		_dashboard_status(str(action.status) + "   ›", _source_point(Vector2(1120, float(action.source.position.y) + 10.0)), bool(requirements.get(_requirement_for_action(str(action.id)), false)))
	# The illustrated dossier is the complete player-facing RP-07 view. Its rows
	# and side tabs are intentionally not links: the old generic form duplicated
	# the same dossier content.
	var photo_button := button(body,"更换照片" if not str(ResidencySystem.state().get("cover_photo_id","")).is_empty() else "贴一张照片",_source_point(Vector2(327,700)),Vector2(190,38),_open_dossier_photo_picker)
	photo_button.name = "DossierCoverPhotoAction"
	photo_button.add_theme_font_size_override("font_size",16)
	photo_button.modulate = Color(1,1,1,0.9)

func _dashboard_cover_photo() -> void:
	var id := str(ResidencySystem.state().get("cover_photo_id",""))
	if id.is_empty(): return
	var image := _load_photo_image(id)
	if image == null: return
	var target := _source_rect(DOSSIER_PHOTO_SOURCE)
	var photo := TextureRect.new()
	photo.name = "DossierCoverPhoto"
	photo.texture = ImageTexture.create_from_image(image)
	photo.position = target.position
	photo.size = target.size
	photo.pivot_offset = target.size * 0.5
	photo.rotation = -0.075
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(photo)

func _open_dossier_photo_picker() -> void:
	if is_instance_valid(detail):
		detail.queue_free()
		detail = null
	detail = panel(self,Vector2.ZERO,Vector2(940,620),Color("f6eedc"))
	detail.name = "DossierPhotoPicker"
	detail.set_anchors_preset(Control.PRESET_CENTER)
	detail.offset_left = -470
	detail.offset_top = -310
	detail.offset_right = 470
	detail.offset_bottom = 310
	detail.z_index = 20
	label(detail,"选择一张照片贴在档案封面",Vector2(30,22),Vector2(700,45),28)
	button(detail,"关闭",Vector2(780,24),Vector2(125,38),func() -> void: detail.queue_free(); detail = null)
	var candidates: Array = []
	for item in ResidencySystem.state().materials.values():
		if str(item.get("kind","")) == "photo" and str(item.get("status","DEVELOPED")) == "DEVELOPED": candidates.append(item)
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if int(a.get("day",0)) == int(b.get("day",0)): return int(a.get("minute",a.get("game_minute",0))) > int(b.get("minute",b.get("game_minute",0)))
		return int(a.get("day",0)) > int(b.get("day",0)))
	if candidates.is_empty():
		label(detail,"相册里还没有冲洗完成的照片。拍完并取回照片后，就可以贴在这里。",Vector2(55,220),Vector2(830,120),25)
		return
	var page_count := maxi(1,ceili(float(candidates.size()) / PHOTO_PICKER_PAGE_SIZE))
	photo_picker_page = clampi(photo_picker_page,0,page_count-1)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(35,88)
	grid.size = Vector2(870,430)
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",14)
	detail.add_child(grid)
	var first := photo_picker_page * PHOTO_PICKER_PAGE_SIZE
	var last := mini(first + PHOTO_PICKER_PAGE_SIZE,candidates.size())
	for index in range(first,last):
		var item: Dictionary = candidates[index]
		var id := str(item.get("id",item.get("photo_id","")))
		var card := Panel.new()
		card.custom_minimum_size = Vector2(278,198)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("eee3cc")
		card_style.set_corner_radius_all(3)
		card.add_theme_stylebox_override("panel",card_style)
		grid.add_child(card)
		_photo(card,id,Vector2(9,9),Vector2(260,128))
		var choose := button(card,"贴到封面 · "+str(item.get("title","照片")).left(10),Vector2(9,145),Vector2(260,40),func() -> void:
			if ResidencySystem.set_cover_photo(id): build())
		choose.name = "ChooseDossierPhoto_"+id
	if page_count > 1:
		var previous := button(detail,"上一页",Vector2(250,548),Vector2(150,40),func() -> void: photo_picker_page -= 1; _open_dossier_photo_picker())
		previous.disabled = photo_picker_page <= 0
		label(detail,"%d / %d" % [photo_picker_page+1,page_count],Vector2(420,552),Vector2(100,34),20)
		var next := button(detail,"下一页",Vector2(540,548),Vector2(150,40),func() -> void: photo_picker_page += 1; _open_dossier_photo_picker())
		next.disabled = photo_picker_page >= page_count-1
	if not str(ResidencySystem.state().get("cover_photo_id","")).is_empty():
		button(detail,"移除封面照片",Vector2(720,548),Vector2(185,40),func() -> void: ResidencySystem.set_cover_photo(""); build())

func _audit_count(progress: Dictionary, key: String) -> int:
	return int(progress.get(key, {}).get("count", 0))

func _requirement_for_action(action: String) -> String:
	return str({"days":"pages", "income":"income", "exploration":"exploration", "recognition":"recognition", "contribution":"contribution", "personal":"personal", "final":"why_stay"}.get(action, action))

func _source_point(point: Vector2) -> Vector2:
	return DOSSIER_PREVIEW_POSITION + point * (DOSSIER_PREVIEW_SIZE.y / DOSSIER_REFERENCE_SIZE.y)

func _source_rect(source: Rect2) -> Rect2:
	var scale := DOSSIER_PREVIEW_SIZE.y / DOSSIER_REFERENCE_SIZE.y
	return Rect2(DOSSIER_PREVIEW_POSITION + source.position * scale, source.size * scale)

func _dashboard_status(text: String, at: Vector2, complete: bool) -> void:
	var status := label(body, text, at, Vector2(120, 42), 15, Color("527b70") if complete else Color("665748"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var background := StyleBoxFlat.new()
	background.bg_color = Color("f2e6ce")
	background.set_corner_radius_all(3)
	status.add_theme_stylebox_override("normal", background)

func _select_dossier_tab(target: String) -> void:
	WorldSound.play_ui("paper")
	match target:
		"income", "contribution":
			tab = "proof"
			proof_filter = target
		"final":
			tab = "days"
			day = 7
		"days":
			tab = "days"
			day = clampi(GameState.current_day,1,7)
		_:
			tab = target
			if target == "proof": proof_filter = "all"
	build()

func _dossier_reference_page() -> void:
	var images := {
		"requirements": "res://art/ui/dossier-open-reference.png",
		"days": "res://art/ui/dossier-seven-days.png",
		"exploration": "res://art/ui/dossier-exploration.png",
		"recognition": "res://art/ui/dossier-recognition.png",
		"personal": "res://art/ui/dossier-personal.png",
		"proof": "res://art/ui/dossier-final-statement.png"
	}
	var viewport := get_viewport_rect().size
	if viewport.x <= 1 or viewport.y <= 1:
		viewport = Vector2(1600,900)
	var art_size := Vector2(viewport.x * 0.60, viewport.y * 0.76)
	var art_position := Vector2((viewport.x - art_size.x) * 0.5, (viewport.y - art_size.y) * 0.5)
	var preview := TextureRect.new()
	preview.name = "DossierReferencePreview"
	preview.texture = load(str(images.get(tab, "")))
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.position = art_position
	preview.size = art_size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview)
	var tabs := [
		["requirements", 0.202],
		["days", 0.328],
		["exploration", 0.454],
		["recognition", 0.580],
		["personal", 0.705],
		["proof", 0.831]
	]
	for row in tabs:
		var hit := Button.new()
		hit.name = "DossierTab_" + str(row[0])
		hit.position = art_position + Vector2(art_size.x * 0.874, art_size.y * float(row[1]))
		hit.size = Vector2(art_size.x * 0.104, art_size.y * 0.086)
		hit.flat = true
		hit.modulate = Color(1, 1, 1, 0.01)
		hit.pressed.connect(_select_dossier_tab.bind(str(row[0])))
		add_child(hit)
	var close_link := Button.new()
	close_link.text = LocalizationSystem.text("收起  Esc")
	close_link.flat = true
	close_link.position = Vector2(art_position.x + art_size.x - 112, art_position.y - 40)
	close_link.size = Vector2(112, 32)
	close_link.add_theme_font_size_override("font_size", 18)
	close_link.add_theme_color_override("font_color", Color("fff4dc"))
	close_link.pressed.connect(close)
	add_child(close_link)

func _starter_packet() -> void:
	var s := ResidencySystem.state()
	if not s.packet:
		label(body,"尚未领取 RP-07 资料袋。\n你仍可从申请进度预览每一项对应的真实功能。",Vector2(70,180),Vector2(1120,130),27)
		button(body,"在地图上找到社区中心",Vector2(70,350),Vector2(1120,60),func() -> void: mode = "map"; map_selected = "print_shop"; build())
		feedback.text = LocalizationSystem.text("社区中心柜台开放时间：09:00–18:00。")
		return
	var paper_count: int = s.materials.size()
	var layers := clampi(2+paper_count/6,2,7)
	for i in range(layers,0,-1):
		panel(body,Vector2(48+i*3,164+i*2),Vector2(1238,480),Color("e8dec5"))
	var folder := panel(body,Vector2(40,147),Vector2(1250,515),Color("cbbb96"))
	label(folder,"%s 的资料袋  ·  六份独立文件" % GameState.current_role,Vector2(25,13),Vector2(840,36),25)
	label(folder,"Day %d / 7  ·  已收 %d 件材料" % [GameState.current_day,paper_count],Vector2(850,16),Vector2(365,30),18)
	for i in ResidencySystem.content.starter.size():
		var paper: Dictionary = ResidencySystem.content.starter[i]
		var at := Vector2(26+(i%2)*607,68+(i/2)*141)
		panel(folder,at+Vector2(4,5),Vector2(583,120),Color("e2d5b8"))
		var sheet := panel(folder,at,Vector2(583,120))
		label(sheet,"%02d" % [i+1],Vector2(14,9),Vector2(42,28),18,Color("899282"))
		label(sheet,str(paper.title),Vector2(65,10),Vector2(493,32),22)
		label(sheet,str(paper.get("subtitle","")),Vector2(65,46),Vector2(490,28),20)
		var open := button(sheet,"展开  →",Vector2(413,78),Vector2(151,31),_open_starter.bind(str(paper.id)))
		open.name = "Starter_"+str(paper.id)
	feedback.text = LocalizationSystem.text("点一张纸展开。七日作品集单独成册，其他文件各自保留。")

func _open_starter(id: String) -> void:
	detail_id = ""
	if is_instance_valid(detail): detail.queue_free(); detail = null
	document_id = id
	mode = "dossier"
	match id:
		"portfolio": tab = "days"
		"requirements": tab = "requirements"
		"folder": tab = "cover"
		"map": mode = "map"
		_: tab = "document"
	build()

func _starter_reader() -> void:
	var paper: Dictionary = {}
	for candidate in ResidencySystem.content.starter:
		if str(candidate.id) == document_id: paper = candidate; break
	if paper.is_empty(): return
	panel(body,Vector2(171,164),Vector2(1010,503),Color("e5d9bd"))
	var sheet := panel(body,Vector2(164,155),Vector2(1010,503))
	label(sheet,str(paper.title),Vector2(40,25),Vector2(930,48),30)
	label(sheet,str(paper.get("subtitle","")),Vector2(40,77),Vector2(900,33),21)
	var rows := scroll_area(sheet,Vector2(42,126),Vector2(926,292))
	var text := Label.new()
	text.text = LocalizationSystem.text(str(paper.text))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 895
	text.add_theme_color_override("font_color",INK)
	text.add_theme_font_size_override("font_size",23)
	rows.add_child(text)
	button(sheet,"收回资料袋",Vector2(40,439),Vector2(235,40),func() -> void: tab = "starter"; build())
	button(sheet,"下一份文件  →",Vector2(650,439),Vector2(315,40),func() -> void: _open_starter("seven_days" if document_id == "welcome" else "requirements"))

func _dossier_cover() -> void:
	var s := ResidencySystem.state()
	var cover := panel(body,Vector2(68,150),Vector2(1185,520),Color("d0c39f"))
	label(cover,"RP-07\nRESIDENCY DOSSIER",Vector2(45,36),Vector2(640,114),36)
	label(cover,"申请人 %s  ·  Day %d / 7" % [GameState.current_role,GameState.current_day],Vector2(48,170),Vector2(1000,43),25)
	label(cover,"六份资料各自保留。这个文件夹收存你愿意交出的记录。\n晚上在住处整理，散页可以继续留在自己手里。",Vector2(48,242),Vector2(1080,100),23)
	button(cover,"翻开七日作品集",Vector2(48,378),Vector2(340,58),_open_starter.bind("portfolio"))
	button(cover,"查看收入与贡献证明",Vector2(414,378),Vector2(340,58),func() -> void: tab = "proof"; build())
	button(cover,"查看当前申请要求",Vector2(779,378),Vector2(340,58),_open_starter.bind("requirements"))
	label(cover,"已封存" if not s.submitted.is_empty() else "收件截止  Day 7 · 18:00",Vector2(48,460),Vector2(1060,35),20)

func _personal_page() -> void:
	button(body,"打开 Day 5 · 介绍自己",Vector2(45,146),Vector2(1230,49),func() -> void: day = 5; tab = "days"; build())
	var rows := scroll_area(body,Vector2(45,214),Vector2(1230,445))
	for id in ResidencySystem.state().filing:
		if str(ResidencySystem.state().filing[id]) == "personal": _material_row(rows,str(id))
	if rows.get_child_count() == 0: label(body,"这里可以夹照片、声音与自己的作品。也可以在 Day 5 回答三个问题，或自由写一页。",Vector2(75,290),Vector2(1130,150),25)

func requirement_name(key: String) -> String:
	return str({"packet":"社区资料袋","pages":"七张每日记录","income":"收入证明","living_receipts":"有效生活小票","receipt_categories":"消费用途类别","ledger":"七日收支核对","exploration":"三种实地探索","recognition":"十二位居民签记","recognition_circles":"不同生活圈","contribution":"已留下的贡献与证明","personal":"个人介绍","why_stay":"最终选择与签名"}.get(key,key))

func _requirements() -> void:
	var audit := ResidencySystem.audit()
	var sheet := panel(body,Vector2(48,145),Vector2(1235,530))
	label(sheet,"RESIDENCY REQUIREMENTS",Vector2(30,16),Vector2(700,36),28)
	label(sheet,"%s · Day 7 / 18:00 前" % GameState.current_role,Vector2(837,20),Vector2(375,36),21)
	var rows := scroll_area(sheet,Vector2(25,70),Vector2(1183,400))
	rows.add_theme_constant_override("separation",5)
	for key in ["pages","income","living_receipts","receipt_categories","ledger","exploration","recognition","recognition_circles","contribution","personal","why_stay"]:
		var progress: Dictionary = audit.get("progress",{}).get(key,{"count":0,"target":1})
		var fulfilled: bool = audit.requirements[key]
		var row := Control.new()
		row.custom_minimum_size = Vector2(0,44)
		rows.add_child(row)
		var entry := button(row,("✓  " if fulfilled else "○  ")+requirement_name(key),Vector2.ZERO,Vector2(670,43),_requirement_open.bind(key))
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.name = "Requirement_"+key
		label(row,"%d / %d" % [int(progress.count),int(progress.target)],Vector2(705,4),Vector2(145,32),24)
		label(row,"已满足" if fulfilled else "未完成",Vector2(920,4),Vector2(200,32),23,INK if fulfilled else Color("947048"))
	label(sheet,"点选任一要求，查看对应记录。证明领取后仍需亲手归档。",Vector2(30,482),Vector2(1170,35),19)
	if not audit.submitted.is_empty(): feedback.text = LocalizationSystem.text(str(audit.submitted.outcome))

func _requirement_open(key: String) -> void:
	match key:
		"pages": tab = "days"; day = clampi(GameState.current_day,1,7)
		"income","contribution": tab = "proof"
		"living_receipts","receipt_categories": tab = "receipts"
		"ledger": tab = "days"; day = clampi(GameState.current_day,1,7)
		"exploration": tab = "exploration"
		"recognition","recognition_circles": tab = "recognition"
		"personal": tab = "personal"
		"why_stay": tab = "days"; day = 7
	build()

func _day_page() -> void:
	for i in range(1,8):
		var b := button(body,"DAY %d" % i,Vector2(40+(i-1)*178,137),Vector2(165,36),func() -> void: day = i; build())
		b.name = "PortfolioDay_%d" % i
	var page: Dictionary = ResidencySystem.state().pages[day-1]
	var definition: Dictionary = ResidencySystem.content.pages[day-1]
	var left := panel(body,Vector2(38,185),Vector2(680,491))
	label(left,"DAY %d / 7 · %s" % [day,definition.title],Vector2(22,14),Vector2(640,38),23)
	var rows := scroll_area(left,Vector2(22,61),Vector2(639,405))
	_form_row(rows,"TODAY · 今天",str(page.today),"today",70)
	_form_row(rows,"RECORD · 记录",str(page.record),"record",100)
	for field in definition.fields: _form_row(rows,str(field.label),str(page.fields.get(str(field.id),"")),str(field.id),100 if field.id != "why_stay" else 210)
	var keep := _drop(body,"day_%d" % day,Vector2(742,185),Vector2(555,294),"KEEP  /  留下的材料")
	var kept := scroll_area(keep,Vector2(14,50),Vector2(524,220))
	for id in page.keep: _material_row(kept,str(id))
	if page.keep.is_empty(): label(keep,"从素材本选择，或回房间拖进这一页。",Vector2(20,120),Vector2(510,90),22)
	var ledger := ResidencySystem.ledger_for(day)
	label(body,"收支  ·  收入 %d / 支出 %d / 余额 %d" % [ledger.income,ledger.expense,ledger.balance],Vector2(750,505),Vector2(555,54),21)
	var ledger_button := button(body,"已核对" if page.ledger_checked else "核对当天收支",Vector2(750,565),Vector2(260,42),func() -> void: ResidencySystem.check_ledger(day); build())
	ledger_button.disabled = day > GameState.current_day
	if day == 2: button(body,"制作实地记录 →",Vector2(1022,565),Vector2(273,42),func() -> void: tab = "exploration"; build())
	if day == 3: button(body,"生活小票 →",Vector2(1022,565),Vector2(273,42),func() -> void: tab = "receipts"; build())
	var mark_names: Array[String] = []
	for resident in page.marks: mark_names.append(str(ScheduleSystem.residents.get(resident,{}).get("display_name",resident)))
	label(body,"居民签记 %d / 2：%s" % [page.marks.size(),"、".join(mark_names)],Vector2(750,625),Vector2(550,42),18)
	feedback.text = LocalizationSystem.text("%s · 当前 Day %d / 7 · 这页到当天可以填写" % [GameState.current_role,GameState.current_day] if day > GameState.current_day else "%s · 当前 Day %d / 7 · 每天一页，材料按自己的选择收好" % [GameState.current_role,GameState.current_day])

func _form_row(rows: VBoxContainer, caption: String, value: String, key: String, height: float) -> void:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0,height+32)
	rows.add_child(row)
	label(row,caption,Vector2.ZERO,Vector2(610,28),18)
	var current_day := day
	var input := edit(row,value,Vector2(0,31),Vector2(607,height),func(text: String) -> void: ResidencySystem.set_field(current_day,key,text))
	input.editable = day <= GameState.current_day and ResidencySystem.state().submitted.is_empty()
	input.focus_exited.connect(func() -> void: ResidencySystem.persist())

func _recognition() -> void:
	var audit := ResidencySystem.audit()
	var has_packet := bool(ResidencySystem.state().packet)
	label(body,"已归档 %d / 12  ·  生活圈 %d / 4  ·  每页两处签记" % [int(audit.recognitions),audit.recognition_circles.size()],Vector2(40,145),Vector2(1200,40),24)
	var rows := scroll_area(body,Vector2(40,200),Vector2(1250,467))
	for resident in GameState.confirmed_residents:
		var row := Control.new()
		row.custom_minimum_size = Vector2(0,77)
		rows.add_child(row)
		var name := str(ScheduleSystem.residents.get(resident,{}).get("display_name",resident))
		var id := "recognition_"+str(resident)
		label(row,name,Vector2(8,4),Vector2(160,42),22)
		var circle := ResidencySystem.recognition_circle(str(resident))
		label(row,str(ResidencySystem.content.recognition_circles.labels.get(circle,"待核实来源")),Vector2(8,48),Vector2(850,25),17)
		var file_button := button(row,"收进认可页",Vector2(170,4),Vector2(158,42),func() -> void: ResidencySystem.file_material(id,"recognition"); build())
		file_button.disabled = not has_packet
		for i in range(1,8):
			var marked: bool = ResidencySystem.state().pages[i-1].marks.has(resident)
			var b := button(row,("✓ " if marked else "")+"Day %d" % i,Vector2(339+(i-1)*124,4),Vector2(116,42),func() -> void:
				if ResidencySystem.assign_mark(resident,i): build()
				else: feedback.text = LocalizationSystem.text("这一页已有两处签记，或日期尚未到来。"))
			b.disabled = not has_packet or i > GameState.current_day
	if GameState.confirmed_residents.is_empty(): label(body,"还没有居民签记。先在小镇里一起做些事。",Vector2(70,280),Vector2(1100,80),26)

func _living_receipts() -> void:
	var audit := ResidencySystem.audit()
	label(body,"生活小票 %d / 3  ·  用途 %d / 2" % [int(audit.progress.living_receipts.count),int(audit.progress.receipt_categories.count)],Vector2(45,145),Vector2(1210,38),25)
	label(body,"真实消费小票可选择归档。报销后仍保留原件与报销章。",Vector2(45,188),Vector2(1210,35),20)
	var rows := scroll_area(body,Vector2(45,238),Vector2(1230,421))
	var s := ResidencySystem.state()
	for item in s.materials.values():
		if item.kind not in ["receipt","ticket"]: continue
		var row := Control.new()
		row.custom_minimum_size = Vector2(0,94)
		rows.add_child(row)
		var valid := ResidencySystem.valid_living_receipt(item,s.ledger)
		label(row,str(item.title),Vector2(12,4),Vector2(850,35),23)
		var category := str(item.get("category","unclassified"))
		var purpose := str({"food":"饮食","groceries":"生活采买","household":"日用品","transport":"交通","photography":"摄影","culture":"文化活动","collection":"收藏","collectible":"收藏","unclassified":"用途待核实"}.get(category,category))
		label(row,"%s · %d 元 · %s · %s" % [purpose,int(item.get("total",0)),"可用于生活记录" if valid else "保留为一般凭条","已报销" if bool(item.get("reimbursed",false)) else _filing_name(str(s.filing.get(item.id,"loose")))],Vector2(12,49),Vector2(850,36),18)
		button(row,"展开小票",Vector2(885,15),Vector2(270,45),func() -> void: _show_detail(str(item.id)))
	if rows.get_child_count() == 0: label(body,"买东西或乘车后，小票会先放进素材本。",Vector2(70,320),Vector2(1120,90),25)

func _explore_records() -> void:
	label(body,"三种实地记录  ·  地点与到访时间来自走过的路",Vector2(45,141),Vector2(1235,45),25)
	var s := ResidencySystem.state()
	var visited: Array = s.visits.keys()
	if visited.is_empty(): label(body,"先去一个地方走走。",Vector2(80,280),Vector2(1130,85),26); return
	if not visited.has(exploration_location): exploration_location = str(visited[0])
	var kinds: Array = ["discover","revisit","shareplace"]
	var kind := OptionButton.new()
	kind.name = "ExploreKind"
	kind.position = Vector2(50,202); kind.size = Vector2(575,43)
	for title in ["自己发现的地方","换个时段的回访","愿意带别人去的地方"]: kind.add_item(LocalizationSystem.text(title))
	kind.select(kinds.find(exploration_kind))
	kind.item_selected.connect(func(index: int) -> void: exploration_kind = str(kinds[index]))
	body.add_child(kind)
	var places := OptionButton.new()
	places.name = "ExploreLocation"
	places.position = Vector2(650,202); places.size = Vector2(620,43)
	for location in visited: places.add_item(LocalizationSystem.text(TravelSystem.location_name(str(location))))
	places.select(visited.find(exploration_location))
	places.item_selected.connect(func(index: int) -> void: exploration_location = str(visited[index]); build())
	body.add_child(places)
	var input := edit(body,exploration_text,Vector2(50,269),Vector2(1215,152),func(value: String) -> void: exploration_text = value,"写一句发现、变化，或想带谁来……")
	input.name = "ExploreObservation"
	var evidence := OptionButton.new()
	evidence.position = Vector2(50,437); evidence.size = Vector2(760,40)
	evidence.name = "ExploreEvidence"
	evidence.add_item(LocalizationSystem.text("文字观察 · 可以附一件同地点的照片或声音"))
	var evidence_ids: Array[String] = [""]
	for item in s.materials.values():
		if item.kind not in ["photo","sound"] or str(item.get("location_id",item.get("location",""))) != exploration_location: continue
		evidence_ids.append(str(item.id)); evidence.add_item(LocalizationSystem.text(str(item.title)))
	if not evidence_ids.has(exploration_evidence): exploration_evidence = ""
	evidence.select(evidence_ids.find(exploration_evidence))
	evidence.item_selected.connect(func(index: int) -> void: exploration_evidence = evidence_ids[index])
	body.add_child(evidence)
	var create_button := button(body,"留下这张记录",Vector2(855,435),Vector2(410,44),func() -> void:
		var result := ResidencySystem.record_exploration(exploration_kind,exploration_location,exploration_text,exploration_evidence)
		build(); feedback.text = LocalizationSystem.text(str(result.message)))
	create_button.name = "CreateExploreRecord"
	var records := scroll_area(body,Vector2(50,500),Vector2(1215,165))
	for type in ["discover","revisit","shareplace"]:
		var id := str(s.explorations.get(type,""))
		if not id.is_empty(): _material_row(records,id)

func _filed(destination: String) -> void:
	if destination == "proof": _proof_folder(); return
	var rows := scroll_area(body,Vector2(42,150),Vector2(1250,520))
	for item in ResidencySystem.state().materials.values():
		if item.kind == "official": continue
		if str(ResidencySystem.state().filing.get(item.id,"loose")) == destination: _material_row(rows,str(item.id))
	if rows.get_child_count() == 0: label(body,"这里还留着空位。B 打开素材本，选择愿意归档的材料。",Vector2(70,260),Vector2(1150,120),26)

func _proof_folder() -> void:
	label(body,"完成工作/作品 → 到对应柜台领取证明 → 自己归档",Vector2(45,137),Vector2(700,38),22)
	var filters := [["all","全部证明"],["income","收入证明"],["contribution","贡献证明"]]
	for i in filters.size():
		var option: Array = filters[i]
		var filter_button := button(body, ("• " if proof_filter == str(option[0]) else "") + str(option[1]), Vector2(760 + i * 178, 134), Vector2(166, 40), func() -> void: proof_filter = str(option[0]); build())
		filter_button.name = "ProofFilter_" + str(option[0])
	var rows := scroll_area(body,Vector2(45,190),Vector2(1230,470))
	var s := ResidencySystem.state()
	for item in s.materials.values():
		if item.kind != "proof" and not (item.kind == "work" and not str(item.get("proof_kind","")).is_empty()): continue
		if item.kind == "work" and s.materials.has("proof_"+str(item.id)): continue
		if proof_filter != "all" and str(item.get("proof_kind", "")) != proof_filter: continue
		var row := Control.new()
		row.custom_minimum_size = Vector2(0,100)
		rows.add_child(row)
		label(row,str(item.title),Vector2(12,7),Vector2(840,39),23)
		if item.kind == "proof":
			var filed := str(s.filing.get(item.id,"loose")) != "loose"
			label(row,"已领取 · "+("已归档" if filed else "散页待整理"),Vector2(12,56),Vector2(810,32),19)
			button(row,"展开证明",Vector2(860,16),Vector2(310,45),func() -> void: _show_detail(str(item.id)))
		else:
			var issuer := str(item.get("issuer",""))
			var pending := "作品已完成 · 待交给店里" if str(item.get("proof_kind","")) == "contribution" and not bool(item.get("contribution_entered_town",false)) else "已留下 · 证明待领取" if str(item.get("proof_kind","")) == "contribution" else "收入已结算 · 证明待领取"
			if ResidencySystem.requires_record_archive(item): pending = "声音已完成 · 去制片台制作唱片并入库"
			label(row,pending+" · "+TravelSystem.location_name(issuer),Vector2(12,56),Vector2(840,32),19)
			button(row,"在地图上找到柜台",Vector2(860,16),Vector2(310,45),func() -> void: mode = "map"; map_selected = issuer; build())
	if rows.get_child_count() == 0:
		var empty_text := "完成有报酬的工作后，收入证明会在对应柜台等待领取。" if proof_filter == "income" else "作品被小镇收下后，贡献证明会在对应柜台等待领取。" if proof_filter == "contribution" else "工作或作品完成后，这里会留下领取证明的记录。"
		label(body,empty_text,Vector2(75,280),Vector2(1120,140),25)

func _materials() -> void:
	var kinds := {"all":"全部","photo":"照片","sound":"声音","ticket":"票据","note":"笔记","object":"物件"}
	var x := 36.0
	for key in kinds:
		if mode == "gallery" and key not in ["all","photo"]: continue
		button(body,str(kinds[key]),Vector2(x,82),Vector2(154,38),func() -> void: filter = key; build())
		x += 163
	if mode == "fieldbook": button(body,"写一页手记",Vector2(1060,82),Vector2(238,38),func() -> void: mode = "notebook"; build())
	var rows := scroll_area(body,Vector2(38,145),Vector2(1262,525))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",18)
	rows.add_child(grid)
	for item in ResidencySystem.state().materials.values():
		if mode == "gallery" and item.kind != "photo": continue
		if filter != "all" and item.kind != filter and not (filter == "ticket" and item.kind == "receipt") and not (filter == "object" and item.kind in ["work","proof","official","exploration","recognition"]): continue
		var card := PIECE.new()
		card.material_id = str(item.id)
		card.custom_minimum_size = Vector2(292,232)
		var style := StyleBoxFlat.new()
		style.bg_color = PAPER
		style.shadow_size = 4
		style.shadow_color = Color(0.1,0.1,0.1,0.15)
		card.add_theme_stylebox_override("panel",style)
		grid.add_child(card)
		if item.kind == "photo": _photo(card,str(item.id),Vector2(10,10),Vector2(272,145))
		elif item.kind == "sound": label(card,"∿  ∿∿  ∿   ∿∿  ∿",Vector2(16,35),Vector2(255,85),31)
		else: label(card,str(item.title),Vector2(16,25),Vector2(255,112),23)
		button(card,str(item.title).left(16),Vector2(10,166),Vector2(272,31),func() -> void: _show_detail(str(item.id)))
		label(card,"Day %d · %s" % [int(item.day),TravelSystem.location_name(str(item.location))],Vector2(12,201),Vector2(270,26),14)
	if grid.get_child_count() == 0: label(body,"还没有这一类材料。走走、拍照，或录一小段声音。",Vector2(70,280),Vector2(1120,90),27)

func _photo(parent: Node, id: String, at: Vector2, dimensions: Vector2) -> void:
	var image := _load_photo_image(id)
	if image == null: label(parent,"照片文件暂时无法读取",at,dimensions,18); return
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture = ImageTexture.create_from_image(image)
	rect.position = at
	rect.size = dimensions
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(rect)

func _load_photo_image(id: String) -> Image:
	var item: Dictionary = ResidencySystem.state().materials.get(id,{})
	var library := PhotoLibrary.new()
	if not item.is_empty(): library.root_path = str(item.get("library_root",library.root_path))
	return library.load_photo(id)

func _material_row(rows: VBoxContainer, id: String) -> void:
	var item: Dictionary = ResidencySystem.state().materials.get(id,{})
	if item.is_empty(): return
	var row := Control.new()
	row.custom_minimum_size = Vector2(0,48)
	rows.add_child(row)
	button(row,str(item.title).left(32),Vector2.ZERO,Vector2(490,42),func() -> void: _show_detail(id))

func _show_detail(id: String) -> void:
	if id.begins_with("starter_"):
		_open_starter(id.trim_prefix("starter_"))
		return
	if is_instance_valid(detail): detail.queue_free()
	detail_id = id
	var item: Dictionary = ResidencySystem.state().materials.get(id,{})
	if item.is_empty(): return
	detail = panel(self,Vector2(240,105),Vector2(1120,680),PAPER)
	label(detail,str(item.title),Vector2(35,20),Vector2(1000,48),29)
	button(detail,"返回",Vector2(962,22),Vector2(120,38),func() -> void: detail.queue_free(); detail = null; detail_id = "")
	if item.kind == "photo":
		_photo(detail,id,Vector2(30,88),Vector2(630,424))
		var film := get_node_or_null("/root/FilmSystem")
		if film != null and film.has_method("open_photo_actions"):
			button(detail,"给人看、拼贴、房间或公共展示",Vector2(35,546),Vector2(610,44),func() -> void: film.open_photo_actions(id,self)).name = "PhotoActions"
	elif item.kind == "sound":
		var store := SampleStore.new()
		for sample in store.list_samples():
			if str(sample.id) != id: continue
			if bool(sample.get("missing",false)): break
			audio_player = AudioStreamPlayer.new()
			audio_player.bus = "Music"
			audio_player.stream = AudioStreamWAV.load_from_file(str(sample.file_path))
			detail.add_child(audio_player)
			label(detail,"声音采样 · %.1f 秒" % float(sample.duration),Vector2(35,110),Vector2(620,55),26)
			button(detail,"播放 / 停止",Vector2(35,220),Vector2(260,48),func() -> void:
				if audio_player.playing: audio_player.stop()
				else: audio_player.play())
			var waveform = load("res://scripts/residency/sound_paper.gd").new()
			waveform.wav = audio_player.stream
			waveform.markers = sample.get("markers",item.get("markers",[]))
			waveform.position = Vector2(35,320)
			waveform.size = Vector2(590,140)
			detail.add_child(waveform)
	else:
		var description := str(item.get("text",item.get("detail","")))
		if item.kind == "proof": description = "%s\n申请人：%s\n日期：%s\n时长：%s\n实付：%s\n开具：Day %s\n签记：%s" % [item.title,item.get("applicant",GameState.current_role),item.get("work_dates",item.get("dates","")),item.get("hours","—"),str(item.get("paid","—")),str(item.get("issued_day",item.day)),item.get("signature","")]
		elif item.kind in ["receipt","ticket"]:
			description = "Day %d · %02d:%02d\n" % [int(item.day),int(item.minute)/60,int(item.minute)%60]
			for line in item.get("line_items",[]): description += "%s × %d     %d 元\n" % [str(line.get("name",line.get("item_id",""))),int(line.get("quantity",1)),int(line.get("total",0))]
			description += "\n合计 %d 元\n用途：%s\n%s" % [int(item.get("total",-int(item.get("amount",0)))),str(item.get("category","用途待核实")),"可用于生活记录" if ResidencySystem.valid_living_receipt(item,ResidencySystem.state().ledger) else "一般凭条"]
			if bool(item.get("reimbursed",false)): description += "\n\nREIMBURSED · 已报销\nDay %d · 原件保留" % int(item.get("reimbursed_day",item.day))
		elif item.kind == "work": description += "\nDay %d · %02d:%02d\n金额：%s\n%s" % [int(item.day),int(item.minute)/60,int(item.minute)%60,str(item.get("amount",item.get("paid","—"))),"作品已进入小镇" if bool(item.get("contribution_entered_town",false)) else "作品可交给对应柜台"]
		elif item.kind == "exploration":
			description = TravelSystem.location_name(str(item.location))+"\n\n"+str(item.text)+"\n\n到访记录：\n"
			for visit in item.get("visits",[]): description += "Day %d · %02d:%02d\n" % [int(visit.day),int(visit.minute)/60,int(visit.minute)%60]
		label(detail,description,Vector2(35,100),Vector2(615,430),24)
	label(detail,"自己的备注",Vector2(700,90),Vector2(370,40),22)
	remark = edit(detail,str(item.get("remark","")),Vector2(700,135),Vector2(375,255),func(value: String) -> void: ResidencySystem.state().materials[id].remark = value)
	remark.focus_exited.connect(func() -> void: ResidencySystem.persist())
	button(detail,"夹入当前日  F",Vector2(700,425),Vector2(375,45),func() -> void: _attach(id))
	button(detail,"夹入认可" if item.kind == "recognition" else "夹入证明",Vector2(700,483),Vector2(180,42),func() -> void: _file_detail(id,"recognition" if item.kind == "recognition" else "proof"))
	button(detail,"夹入个人页",Vector2(894,483),Vector2(180,42),func() -> void: _file_detail(id,"personal"))
	button(detail,"留在素材本",Vector2(700,542),Vector2(375,42),func() -> void: _file_detail(id,"loose"))
	label(detail,"原始文件保留 · 归档仅改变文件夹里的位置",Vector2(35,617),Vector2(1020,34),18)

func _attach(id: String) -> void:
	_file_detail(id,"day_%d" % clampi(GameState.current_day,1,7))

func _file_detail(id: String, destination: String) -> void:
	if ResidencySystem.file_material(id,destination):
		if is_instance_valid(detail): label(detail,"已收好",Vector2(720,590),Vector2(320,32),20)
	else:
		if is_instance_valid(detail): label(detail,"请先领取资料袋；已提交的档案保持封存。",Vector2(690,590),Vector2(405,50),18)

func _drop(parent: Node, destination: String, at: Vector2, dimensions: Vector2, caption: String) -> Panel:
	var zone := PIECE.new()
	zone.destination = destination
	zone.require_home = mode == "organize"
	zone.position = at
	zone.size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color("a5b6a5")
	style.set_border_width_all(2)
	zone.add_theme_stylebox_override("panel",style)
	parent.add_child(zone)
	label(zone,caption,Vector2(15,12),Vector2(dimensions.x-28,35),23)
	zone.filed.connect(func() -> void: call_deferred("build"))
	return zone

func _organize() -> void:
	if not ResidencySystem.can_organize(): label(body,"18:00 后，回自己的房间整理。F 可先查看档案。",Vector2(70,240),Vector2(1150,150),28); return
	if not ResidencySystem.state().packet: label(body,"先到社区中心领取资料袋。素材会一直留在素材本里。",Vector2(70,240),Vector2(1150,150),28); return
	ResidencySystem._sync_sources()
	var table := panel(body,Vector2(28,80),Vector2(1284,600),Color("a67e5a"))
	label(table,"今天的材料放在前面 · 拖动归档 · 时间暂停",Vector2(22,12),Vector2(1240,34),23,PAPER)
	for i in range(1,8):
		var zone := _drop(table,"day_%d" % i,Vector2(20+(i-1)*178,58),Vector2(165,120),"DAY %d" % i)
		label(zone,"%d 材料 · %d 签记" % [ResidencySystem.state().pages[i-1].keep.size(),ResidencySystem.state().pages[i-1].marks.size()],Vector2(12,65),Vector2(147,30),15)
	_drop(table,"proof",Vector2(20,197),Vector2(294,100),"Proof · 证明")
	_drop(table,"recognition",Vector2(334,197),Vector2(294,100),"Recognition · 认可")
	_drop(table,"personal",Vector2(648,197),Vector2(294,100),"Personal · 个人")
	_drop(table,"loose",Vector2(962,197),Vector2(294,100),"Loose · 自己留着")
	var rows := scroll_area(table,Vector2(20,320),Vector2(1235,258))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",15)
	grid.add_theme_constant_override("v_separation",12)
	rows.add_child(grid)
	var materials: Array = ResidencySystem.state().materials.values()
	materials.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.day)>int(b.day))
	for item in materials:
		if item.kind == "official": continue
		var card := PIECE.new()
		card.material_id = str(item.id)
		card.custom_minimum_size = Vector2(292,90)
		var style := StyleBoxFlat.new()
		style.bg_color = PAPER
		card.add_theme_stylebox_override("panel",style)
		grid.add_child(card)
		label(card,str(item.title).left(25),Vector2(14,10),Vector2(265,42),20)
		label(card,"Day %d · %s" % [int(item.day),_filing_name(str(ResidencySystem.state().filing.get(item.id,"")))],Vector2(14,58),Vector2(265,25),15)

func _home() -> void:
	if mode == "settings":
		label(body,"声音",Vector2(95,92),Vector2(1050,42),28)
		_add_settings_volume_slider("主音量",155,SettingsSystem.master_volume(),SettingsSystem.set_master_volume)
		_add_settings_volume_slider("音乐音量",230,SettingsSystem.music_volume(),SettingsSystem.set_music_volume)
		_add_settings_volume_slider("音效音量",305,SettingsSystem.sound_effects_volume(),SettingsSystem.set_sound_effects_volume)
		var mute_text := "取消静音" if SettingsSystem.is_audio_muted() else "全部静音"
		button(body,mute_text,Vector2(95,390),Vector2(400,58),func() -> void: SettingsSystem.set_audio_muted(not SettingsSystem.is_audio_muted()); build())
		button(body,"全屏 / 窗口",Vector2(520,390),Vector2(425,58),func() -> void: SettingsSystem.set_fullscreen(not SettingsSystem.fullscreen()))
		button(body,"减弱动效："+("开" if SettingsSystem.reduced_motion() else "关"),Vector2(95,478),Vector2(850,58),func() -> void: SettingsSystem.set_reduced_motion(not SettingsSystem.reduced_motion()); build())
		label(body,"调整会立即生效，并在下次启动时保留。",Vector2(95,565),Vector2(900,40),20,Color("6f7770"))
		return
	if mode == "controls":
		label(body,"A / D    沿街行走\nW    与人交谈     E    门、路口与物件     1    问点事\nSpace    继续对话     C    相机 / 拍照\nR    录音与停止     Space    留标记\nG    相册     Tab    地图     B    素材本\nF    居住档案     H    随身物品     J    私人手记\nEsc    返回上一层，再暂停",Vector2(100,135),Vector2(1140,420),28)
		label(body,"地图、档案和整理时，游戏时间暂停。拍照与录音时，小镇继续生活。",Vector2(100,580),Vector2(1150,70),22)
		return
	var items: Array = [["相机  C","camera"],["录音机  R","recorder"],["相册  G","gallery"],["随身地图  Tab","map"],["素材本  B","fieldbook"],["居住档案  F","dossier"],["私人手记  J","notebook"],["操作","controls"],["设置","settings"]]
	if mode == "pause": items = [["继续走走","close"],["设置","settings"],["操作","controls"],["保存并回到封面","exit"]]
	label(body,"%s 的随身物品     ·     余额 %d 元" % [GameState.current_role,GameState.money],Vector2(85,85),Vector2(1100,42),23)
	button(body,"今日  T",Vector2(800,580),Vector2(345,45),func() -> void: mode="today"; build())
	button(body,"账目与听来的消息",Vector2(800,636),Vector2(345,45),func() -> void: mode="knowledge"; build())
	for i in items.size():
		var item: Array = items[i]
		button(body,str(item[0]),Vector2(100,151+i*57),Vector2(565,44),_home_action.bind(str(item[1])))
	var objects = load("res://scripts/residency/pocket_objects.gd").new()
	objects.position = Vector2(755,105)
	body.add_child(objects)


func _add_settings_volume_slider(title: String, y: float, value: int, setter: Callable) -> void:
	label(body,title,Vector2(95,y),Vector2(190,42),23)
	var slider := HSlider.new()
	slider.position = Vector2(305,y-5)
	slider.size = Vector2(640,48)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value
	slider.tooltip_text = LocalizationSystem.text("%s，0 到 100" % title)
	body.add_child(slider)
	var value_label := label(body,"%d%%" % value,Vector2(970,y),Vector2(100,42),22)
	slider.value_changed.connect(func(changed_value: float) -> void:
		setter.call(changed_value)
		value_label.text = "%d%%" % int(round(changed_value)))

func _filing_name(destination: String) -> String:
	if destination.begins_with("day_"): return "第 %s 天" % destination.trim_prefix("day_")
	return str({"proof":"证明","recognition":"居民认可","personal":"个人","loose":"留在自己手里"}.get(destination,"未归档"))

func _home_action(action: String) -> void:
	match action:
		"close": close()
		"exit":
			if SaveManager.save_or_report("保存失败"): SceneRouter.main_menu()
		"camera","recorder":
			remove_from_group("meta_modal")
			tool_requested.emit(action)
			close()
		_:
			mode = action
			build()

func _counter() -> void:
	if review_index >= 0:
		if review_index < 7:
			var page: Dictionary = ResidencySystem.state().pages[review_index]
			label(body,"社区中心 · 值班人",Vector2(65,130),Vector2(1050,45),24)
			label(body,"Day %d：%s" % [review_index+1,ResidencySystem.content.pages[review_index].title],Vector2(65,200),Vector2(1140,50),30)
			label(body,str(page.today)+"\n\n"+str(page.record).left(240),Vector2(65,280),Vector2(1140,220),24)
			label(body,"夹着 %d 张材料，留下 %d 处居民签记。" % [page.keep.size(),page.marks.size()],Vector2(65,515),Vector2(1100,45),23)
			button(body,"翻到下一页",Vector2(900,610),Vector2(330,48),func() -> void: review_index += 1; build())
		else:
			var result := ResidencySystem.submit()
			label(body,str(result.message),Vector2(70,230),Vector2(1150,150),29)
			if bool(result.ok): label(body,str(ResidencySystem.state().pages[6].fields.get("why_stay","")),Vector2(70,410),Vector2(1150,230),24)
		return
	label(body,"资料领取与交件  /  09:00–18:00",Vector2(60,135),Vector2(1150,60),27)
	if GameState.current_minute < 540:
		var wait_minutes := 540-GameState.current_minute
		var wait := button(body,"在旁边坐一会 · 等到 09:00（%d 分钟）" % wait_minutes,Vector2(65,198),Vector2(1110,45),func() -> void:
			if GameState.use_free_time(wait_minutes):
				ResidencySystem.persist()
				build()
				feedback.text = LocalizationSystem.text("柜台开门了，可以领取资料。")
			else: feedback.text = LocalizationSystem.text("这段时间已有安排，可以稍后回来。"))
		wait.name = "WaitForCommunityCounter"
	var collect := button(body,"展开已领取的资料袋" if ResidencySystem.state().packet else "领取七日资料袋",Vector2(65,260),Vector2(1110,65),func() -> void:
		var message := ResidencySystem.collect_packet()
		if ResidencySystem.state().packet: mode = "dossier"; tab = "packet"; build()
		feedback.text = LocalizationSystem.text(message))
	collect.name = "CollectStarterPacket"
	collect.disabled = not ResidencySystem.office_open() and not ResidencySystem.state().packet
	button(body,"查看居住档案",Vector2(65,365),Vector2(1110,65),func() -> void: mode = "dossier"; tab = "packet"; build())
	button(body,"提交 · 请值班人逐页查看",Vector2(65,470),Vector2(1110,65),func() -> void:
		if GameState.current_day != 7 or not ResidencySystem.office_open(): feedback.text = LocalizationSystem.text("请在 Day 7 · 09:00–18:00 交件。")
		elif not ResidencySystem.audit().ready: feedback.text = LocalizationSystem.text("还有材料待补齐，可先查看要求页。")
		elif not ResidencySystem.state().submitted.is_empty(): feedback.text = LocalizationSystem.text("档案已经收好，感谢你留下这些记录。")
		else: review_index = 0; build())
	button(body,"公共展示 · 领取贡献证明",Vector2(65,570),Vector2(1110,55),func() -> void: mode = "proofs"; build()).name = "CommunityProofCounter"

func _proofs() -> void:
	label(body,"作品在小镇留下后，柜台可开具证明。",Vector2(45,100),Vector2(1190,45),24)
	var rows := scroll_area(body,Vector2(45,160),Vector2(1235,510))
	for item in ResidencySystem.proof_candidates(GameState.current_location):
		var row := Control.new()
		row.custom_minimum_size = Vector2(0,110)
		rows.add_child(row)
		label(row,str(item.title),Vector2(12,8),Vector2(875,45),23)
		var collected: bool = ResidencySystem.state().materials.has("proof_"+str(item.id))
		var needs_placement: bool = str(item.get("proof_kind","")) == "contribution" and not bool(item.get("contribution_entered_town",false))
		var needs_archive: bool = ResidencySystem.requires_record_archive(item)
		var status := "作品已完成 · 待交给店里" if needs_placement else ("收入已结算 · " if str(item.get("proof_kind","")) == "income" else "已留下 · ")+("证明已领取" if collected else "证明待领取")
		if needs_archive: status = "声音已完成 · 去制片台制作唱片并入库"
		label(row,status,Vector2(12,58),Vector2(860,32),18)
		var b := button(row,"收起，去制片台" if needs_archive else "交给店里" if needs_placement else "领取",Vector2(935,20),Vector2(230,50),func() -> void:
			if needs_archive: close(); return
			var message := ""
			if needs_placement: message = str(ResidencySystem.accept_contribution(str(item.id),GameState.current_location,{"source":"counter_handover"}).message)
			else: message = ResidencySystem.collect_proof(str(item.id))
			build(); feedback.text = LocalizationSystem.text(message))
		b.name = "PlaceContribution_"+str(item.id) if needs_placement else "CollectProof_"+str(item.id)
		b.disabled = collected and not needs_placement
	if rows.get_child_count() == 0: label(body,"这里暂时没有待领取的工作证明。",Vector2(65,290),Vector2(1150,100),28)

func _notebook() -> void:
	label(body,"保留原话，也可以划掉后重新写。",Vector2(45,90),Vector2(1200,42),24)
	button(body,"账目 / 已知消息",Vector2(968,91),Vector2(308,43),func() -> void: mode="knowledge"; build())
	var old: Dictionary = ResidencySystem.state().materials.get(note_selection,{})
	var input := edit(body,str(old.get("text","")),Vector2(45,150),Vector2(700,420),func(_text: String) -> void: pass)
	button(body,"保存新页",Vector2(45,590),Vector2(163,50),func() -> void: ResidencySystem.add_note(input.text); build())
	button(body,"划去修订",Vector2(220,590),Vector2(163,50),func() -> void: ResidencySystem.add_note(input.text,note_selection,"→"); build())
	button(body,"留个疑问 ？",Vector2(395,590),Vector2(163,50),func() -> void: ResidencySystem.add_note(input.text,note_selection,"?"); build())
	button(body,"圈起来 ○",Vector2(570,590),Vector2(175,50),func() -> void: ResidencySystem.add_note(input.text,"","○"); build())
	var rows := scroll_area(body,Vector2(775,150),Vector2(500,485))
	for item in ResidencySystem.state().materials.values():
		if item.kind != "note" or item.get("source","") != "player": continue
		var b := Button.new()
		b.text = ""
		b.custom_minimum_size.y = 68
		b.add_theme_color_override("font_color",INK)
		b.pressed.connect(func() -> void: note_selection = str(item.id); build())
		rows.add_child(b)
		var words := RichTextLabel.new()
		words.bbcode_enabled = true
		words.position = Vector2(12,12)
		words.size = Vector2(460,48)
		words.mouse_filter = MOUSE_FILTER_IGNORE
		words.add_theme_color_override("default_color",INK)
		var text := str(item.get("mark",""))+" "+str(item.get("text","")).left(55).replace("[","[lb]")
		var crossed: bool = ResidencySystem.state().annotations.any(func(row: Dictionary) -> bool: return str(row.from)==str(item.id))
		words.text = "[s]"+text+"[/s] →" if crossed else text
		b.add_child(words)



func _today() -> void:
	label(body,"TODAY MUST  ·  第 %d 天" % GameState.current_day,Vector2(45,94),Vector2(1200,40),27)
	var next := GuidanceSystem.next_step()
	label(body,"NEXT  "+str(next.text),Vector2(48,140),Vector2(1220,50),22)
	var tasks := GuidanceSystem.today_rows()
	for i in tasks.size():
		var task: Dictionary = tasks[i]
		button(body,("✓  " if bool(task.done) else "□  ")+str(task.text),Vector2(45,210+i*62),Vector2(1248,52),_guidance_action.bind(task)).name="TodayTask_"+str(i)
	label(body,"TODAY OPPORTUNITIES  ·  已知机会",Vector2(45,418),Vector2(1200,40),25)
	var rows := scroll_area(body,Vector2(45,468),Vector2(1248,201))
	var opportunities := GuidanceSystem.opportunities()
	if opportunities.is_empty():
		var line := Label.new()
		line.text=LocalizationSystem.text("问问店主，新的消息会留在这里。")
		line.add_theme_color_override("font_color",INK)
		rows.add_child(line)
	for opportunity in opportunities:
		var line := Button.new()
		line.text=LocalizationSystem.text(str(opportunity.text))
		line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size=Vector2(1200,62)
		line.add_theme_color_override("font_color",INK)
		line.pressed.connect(_guidance_action.bind({"action":"map","location":str(opportunity.get("location",""))}))
		rows.add_child(line)

func _guidance_action(action: Dictionary) -> void:
	var kind := str(action.get("action","today"))
	if kind=="map":
		map_selected=str(action.get("location",GameState.current_location))
		mode="map"
	elif kind=="organize":
		var home := "home_a" if GameState.current_role=="A" else "home_b"
		if SceneRouter.active_space_id==home: mode="organize"
		else:
			map_selected="residence" if GameState.current_role=="A" else "dorm"
			mode="map"
	elif kind in ["exploration","requirements","recognition","receipts","personal"]:
		mode="dossier"; tab="packet"
	else: mode=kind
	build()

func _knowledge() -> void:
	label(body,"账目",Vector2(45,98),Vector2(560,42),27)
	label(body,"从谁那里听来",Vector2(697,98),Vector2(560,42),27)
	var money_rows := scroll_area(body,Vector2(45,158),Vector2(588,512))
	var fact_rows := scroll_area(body,Vector2(697,158),Vector2(588,512))
	for entry in [[money_rows,EconomySystem.notebook_text()],[fact_rows,KnowledgeSystem.text()]]:
		var text := Label.new()
		text.text=LocalizationSystem.text(str(entry[1]))
		text.custom_minimum_size.x=552
		text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_color_override("font_color",INK)
		text.add_theme_font_size_override("font_size",22)
		entry[0].add_child(text)

func _map() -> void:
	label(body,("追踪："+str(GuidanceSystem.tracked_lead().get("text",""))+" — "+GuidanceSystem.source_name(str(GuidanceSystem.tracked_lead().get("source","")))) if not GuidanceSystem.tracked_lead().is_empty() else "选择地点查看路线 · 拖动 / 滚轮缩放",Vector2(35,86),Vector2(1240,38),21)
	var viewport := panel(body,Vector2(28,137),Vector2(1284,540),Color("e4ead9"))
	viewport.name = "MapViewport"
	viewport.clip_contents = true
	map_board = load("res://scripts/residency/map_paper.gd").new()
	map_board.position = Vector2(12,-142)
	map_board.scale = Vector2.ONE*1.2
	map_board.selected.connect(_map_select)
	viewport.add_child(map_board)
	_map_select(GameState.current_location if map_selected.is_empty() else map_selected)

func _map_select(location: String) -> void:
	map_selected = location
	var old := body.get_node_or_null("MapDetails")
	if old != null: body.remove_child(old); old.queue_free()
	if location == GameState.current_location:
		return
	var side := panel(body,_map_card_position(location),Vector2(368,284),Color("f7efd9"))
	side.name = "MapDetails"
	label(side,TravelSystem.location_name(location),Vector2(18,12),Vector2(285,38),25)
	label(side,"从 %s 出发" % TravelSystem.location_name(GameState.current_location),Vector2(18,46),Vector2(325,28),15,Color("6c756d"))
	var travel_methods := [
		{"id":"walk", "title":"步行", "name":"TravelWalk"},
		{"id":"friend", "title":"找人借车", "name":"TravelFriend"},
		{"id":"taxi", "title":"坐出租", "name":"TravelTaxi"},
	]
	for i in travel_methods.size():
		var method := str(travel_methods[i].id)
		var route := TravelSystem.route(GameState.current_location,location,method,GameState.current_role,GameState.current_minute)
		var title := LocalizationSystem.text(str(travel_methods[i].title))
		var available := bool(route.get("available",false))
		var reason := str(route.get("reason",""))
		if available:
			title = LocalizationSystem.text_with_values("%s · %d 分钟 / %d 元", [title,int(route.minutes),int(route.cost)])
			if int(route.cost) > GameState.money: available = false; reason = "余额不足。"
		else:
			title = LocalizationSystem.text_with_values("%s · 暂不可用", [title])
		var b := button(side,title,Vector2(17,78+i*55),Vector2(334,44),_travel_selected.bind(method))
		b.name = str(travel_methods[i].name)
		b.disabled = not available or travel_pending
		b.tooltip_text = LocalizationSystem.text(reason)
		if method=="taxi" and bool(route.get("available",false)):
			MetaExperience.queue_important("route_taxi_choice",{"protagonist_id":GameState.current_role,"location_id":GameState.current_location,"taxi_cost":int(route.cost),"to":location})
	label(side,"路程越远，时间和费用越高 · 跨街出租车最低 50 元",Vector2(18,247),Vector2(320,25),13,Color("6c756d"))
	var cancel := button(side,"×",Vector2(320,10),Vector2(32,32),func() -> void: _map_select(GameState.current_location))
	cancel.name = "TravelCancel"
	cancel.tooltip_text = LocalizationSystem.text("关闭")

func _map_card_position(location: String) -> Vector2:
	var marker := Vector2(525,350)
	var map_points = map_board.get("points")
	if map_points is Dictionary:
		marker = Vector2(map_points.get(location, marker))
	var on_map := Vector2(28,137) + map_board.position + marker * map_board.scale.x
	var card_size := Vector2(368,284)
	var x := on_map.x + 28
	if x + card_size.x > 1300:
		x = on_map.x - card_size.x - 28
	return Vector2(clampf(x,40,1300-card_size.x),clampf(on_map.y-42,150,680-card_size.y))

func _travel_selected(method: String) -> void:
	if travel_pending or SceneRouter.transitioning: return
	travel_pending = true
	var result := SceneRouter.travel_to(map_selected,method)
	if bool(result.get("ok",false)): close()
	else:
		travel_pending = false
		feedback.text = LocalizationSystem.text(str(result.get("message","当前无法出发。")))
		_map_select(map_selected)
