extends Node2D

const Paper = preload("paper_object.gd")
const Tool = preload("tool_object.gd")
const Audio = preload("../scripts/audio_manager.gd")
const PaperArt = preload("material_page.gd")
const BottleClient = preload("../scripts/bottle_client.gd")
const BottleDock = preload("../scripts/bottle_dock.gd")
const TypeLayout = preload("typewriter_layout.gd")
const SIZE := Vector2(1600,900)
const INK := Color("443f32")
const CREAM := Color("f6ebd5")
const ASSETS := "res://extensions/collage_letter/workshop/open_assets/"
enum Mode { DESK, MATERIAL_BROWSER, SCISSOR_CUTTING, CUTTING_MAT, KNIFE_CUTTING, TYPEWRITER, DRAWING, TAPE, FOLDING, ENVELOPE, WAX_SEALING, SENT, GLUE }

var mode := Mode.DESK
var stage := "WORKBENCH"
var letter_mode := "npc"
var bottle_published_id := 0
var bottle_request_id := ""
var reply_parent: Dictionary = {}
var compose_server := ""
var letter_title := "一封来自窗边的信"
var bottle: Node
var dock_open := false
var busy := false
var ready_done := false
var smoke := false
var save_path := "user://workshop_v3.json"
var preview_path := "user://workshop_letter.png"
var audio: Node
var font: SystemFont
var mono: Font
var ui: CanvasLayer
var papers: Node2D
var tools_root: Node2D
var tape_roll: Node2D
var mat_tool: Node2D
var scissors_tool: Node2D
var knife_tool: Node2D
var dragged_tool: Node2D
var tool_drag_start := Vector2.ZERO
var main_paper: Node2D
var active: Node2D
var focused: Node2D
var dragged: Node2D
var grab_offset := Vector2.ZERO
var pointer := Vector2.ZERO
var previous_pointer := Vector2.ZERO
var ink_target: Node2D
var pen_width := 1.3
var pen_color := Color("34464a")
var tool := "move"
var hint := "翻开左边的纸张，或者从打字机开始。"
var hovered_title := ""
var elapsed := 0.0
var save_clock := 0.0
var sound_clock := 0.0
var backdrop: Texture2D
var reference: Texture2D
var sprites: Dictionary = {}
var materials: Array = []
var material_images: Array[Image] = []
var material_textures: Array[Texture2D] = []
var browser_category := "全部"
var browser_index := 0
var preview_image: Texture2D
var material_viewports: Array = []
var focused_original: Dictionary = {}
var undo_stack: Array = []
var redo_stack: Array = []
var focus_amount := 0.0
var focus_tween: Tween
var focused_tool := ""
var cut_start := Vector2(510,370)
var cut_end := Vector2(1090,520)
var cut_progress := 0.0
var cut_handle := -1
var mat_paper_id := ""
var cutting := false
var knife_path := PackedVector2Array()
var knife_angle := 0.0
var scissor_phase := 0.0
var tape_start := Vector2.ZERO
var tape_end := Vector2.ZERO
var tape_pulling := false
var tape_pending := false
var tape_angle := 0.0
var typed_text := ""
var type_key := ""
var key_age := 10.0
var carriage := 0.0
var eject_amount := 0.0
var typed_preview: Texture2D
var typepaper: Node2D
var type_viewport: SubViewport
var type_ink: Node2D
var type_queue: Array[String] = []
var type_delay := 0.0
var type_save_requested := false
var fold := 0
var fold_amount := 0.0
var fold_drag := false
var letter_preview: ImageTexture
var envelope_inserted := false
var envelope_flap := 0.0
var flap_drag_y := 0.0
var flap_drag_start := 0.0
var insert_amount := 0.0
var packing_drag := ""
var packed_letter_at := Vector2(580,420)
var wax_step := 0
var wax_heat := 0.0
var wax_pour := 0.0
var wax_hold := 0.0
var wax_cool := 0.0
var wax_drag := ""
var match_heat := 0.0
var match_lit := false
var candle_lit := false
var spoon_filled := false
var spoon_on_fire := false
var stamp_imprint := false
var notes_open := false
var settings_open := false
var session_context: Dictionary = {}

func _ready() -> void:
	session_context=get_meta("solmere_context",{})
	if not session_context.is_empty() and has_node("/root/GameState"):
		preview_path="user://letter_%s_%s.png"%[str(get_node("/root/GameState").shared_state.get("journey_id","local")),str(session_context.current_character)]
	smoke = OS.get_cmdline_user_args().has("--workshop-test")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="): save_path = "user://workshop_" + arg.trim_prefix("--profile=").validate_filename() + ".json"
	font = SystemFont.new()
	font.font_names = ["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"]
	mono = load(ASSETS + "fonts/specialelite/SpecialElite-Regular.ttf")
	mono.fallbacks = [font]
	audio = Audio.new()
	add_child(audio)
	bottle = BottleClient.new()
	add_child(bottle)
	reference = load(ASSETS + "desk.svg")
	backdrop = reference
	for id in ["typewriter", "scissors", "knife", "tape", "mat", "pen", "pencil", "marker", "glue", "envelope", "wax-tray", "candle", "spoon", "stamp", "matchbox"]:
		var source: Texture2D = load(ASSETS + "tools/" + id + ".svg")
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(Vector2.ZERO,source.get_size())
		sprites[id] = atlas
	tools_root = Node2D.new()
	add_child(tools_root)
	_make_tool("mat", "刻板 · 保持原位，把纸铺上来", Rect2(400,530,720,326))
	_make_tool("typewriter", "打字机 · 一个字一个字印在纸上", Rect2(820,280,430,265))
	_make_tool("tape", "纸胶带 · 拉出后用剪刀剪断", Rect2(1450,595,110,87))
	_make_tool("pen", "钢笔 · 细线墨迹", Rect2(1245,365,26,135))
	_make_tool("pencil", "铅笔 · 柔软的石墨线", Rect2(1283,355,26,145))
	_make_tool("marker", "马克笔 · 宽幅叠色", Rect2(1321,374,26,126))
	_make_tool("envelope", "信封 · 折信、装封", Rect2(54,684,275,148))
	_make_tool("wax-tray", "蜡粒盘 · 封口时用勺子舀蜡", Rect2(1150,753,430,102))
	_make_tool("knife", "刻刀 · 在绿色刻板上划线", Rect2(1254,573,36,155))
	_make_tool("scissors", "剪刀 · 拖到纸上剪裁", Rect2(1142,569,93,157))
	_make_tool("glue", "胶棒 · 翻面涂胶，再压贴", Rect2(1330,591,53,120))
	_make_tool("candle", "蜡烛 · 封口时划火柴点亮", Rect2(1155,738,68,105))
	_make_tool("spoon", "蜡勺 · 舀蜡、加热、倾倒", Rect2(1233,804,162,43))
	_make_tool("stamp", "印章 · 压住温热的蜡", Rect2(1430,735,54,107))
	_make_tool("matchbox", "火柴 · 封口时划动点火", Rect2(1497,777,74,46))
	papers = Node2D.new()
	add_child(papers)
	main_paper = Paper.new()
	main_paper.object_id = "letter"
	main_paper.title = _localized("信纸")
	main_paper.set_image(_blank_paper(Vector2i(500,290)))
	main_paper.position = Vector2(765,690)
	main_paper.rotation = -0.012
	main_paper.is_cuttable = false
	main_paper.is_movable = false
	main_paper.is_foldable = true
	papers.add_child(main_paper)
	ui = CanvasLayer.new()
	add_child(ui)
	materials = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "materials.json"))
	for i in materials.size():
		var viewport := SubViewport.new()
		viewport.size = Vector2i(300,240)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(viewport)
		var art := PaperArt.new()
		art.sheet_data = materials[i]
		art.font = mono
		art.asset_root = ASSETS
		viewport.add_child(art)
		material_viewports.append(viewport)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for viewport in material_viewports:
		material_images.append(viewport.get_texture().get_image())
		material_textures.append(ImageTexture.create_from_image(material_images[-1]))
		viewport.queue_free()
	material_viewports.clear()
	_append_developed_photos()
	ready_done = true
	if not smoke and not OS.get_cmdline_user_args().has("--fresh"): load_game()
	build_ui()
	queue_redraw()

func _make_tool(id: String, caption: String, rect: Rect2) -> void:
	var object := Tool.new()
	object.object_id = id
	object.action = id
	object.title = caption
	object.bounds = rect
	object.texture = sprites.get(id)
	tools_root.add_child(object)
	if id == "tape": tape_roll = object
	if id == "mat": mat_tool = object
	if id == "scissors": scissors_tool = object
	if id == "knife": knife_tool = object

func _blank_paper(dimensions: Vector2i) -> Image:
	var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	for y in dimensions.y:
		for x in dimensions.x:
			var edge := 2.0 + sin(y * 1.4) + sin(x * 1.25)
			if x < edge or y < edge or x > dimensions.x - edge - 1 or y > dimensions.y - edge - 1: continue
			var grain := (fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453,1.0)-0.5) * 0.025
			image.set_pixel(x,y, Color(0.975 + grain,0.938 + grain,0.84 + grain,1))
	return image

func _process(delta: float) -> void:
	if not ready_done: return
	# The roll is either on the desk or at the loose strip's end, never both.
	tape_roll.visible = not (tape_pulling or tape_pending)
	knife_tool.visible = mode != Mode.KNIFE_CUTTING
	for object in tools_root.get_children():
		if object.action in ["pen","pencil","marker","glue"]:
			object.visible = not (mode in [Mode.DRAWING,Mode.GLUE] and object.action == tool)
	elapsed += delta
	save_clock += delta
	sound_clock += delta
	key_age += delta
	if mode == Mode.TYPEWRITER: _advance_typewriter(delta)
	carriage = lerpf(carriage, 0, minf(delta * 8, 1))
	var target := 0.0 if mode in [Mode.DESK,Mode.DRAWING,Mode.TAPE,Mode.SENT,Mode.GLUE,Mode.CUTTING_MAT,Mode.KNIFE_CUTTING] else 1.0
	focus_amount = lerpf(focus_amount,target,minf(delta*9,1))
	if mode == Mode.WAX_SEALING:
		_process_wax(delta)
	if save_clock > 8 and not busy and not dragged and not focused and not ink_target:
		save_game()
		save_clock = 0
	queue_redraw()

func _caption(text: String, point: Vector2, size: int = 18, color: Color = INK) -> void:
	draw_string(font, point, _localized(text), HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _sprite(id: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if sprites.has(id): draw_texture_rect(sprites[id],rect,false,tint)

func _draw() -> void:
	if not reference: return
	draw_texture_rect(backdrop,Rect2(Vector2.ZERO,SIZE),false)
	# Discreet paper labels belong to the desk; the art remains the whole screen.
	if mode in [Mode.DESK,Mode.DRAWING,Mode.TAPE,Mode.SENT,Mode.GLUE]:
		draw_style_box(_paper_style(),Rect2(22,20,190,75))
		draw_string(mono,Vector2(38,54),"Solmere",HORIZONTAL_ALIGNMENT_LEFT,-1,34,INK)
		_caption("书 信 事 务 所",Vector2(37,78),14)
		_draw_rack()
	if focus_amount > 0.01:
		draw_rect(Rect2(Vector2.ZERO,SIZE),Color(0.13,0.14,0.12,focus_amount*0.38))
	if mode == Mode.MATERIAL_BROWSER: _draw_browser()
	if mode == Mode.TYPEWRITER: _draw_typewriter()
	if mode == Mode.FOLDING: _draw_folding()
	if mode == Mode.ENVELOPE: _draw_envelope()
	if mode == Mode.WAX_SEALING: _draw_wax()
	if mode == Mode.SENT:
		draw_style_box(_paper_style(),Rect2(540,210,540,128))
		_caption("信已经出发了。",Vector2(580,260),26)
		_caption("留一点空白，给另一个人的回音。",Vector2(580,299),18)

func _draw_overlay() -> void:
	pass

func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(CREAM,0.95)
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0.15,0.10,0.05,0.2)
	style.shadow_size = 4
	return style

func _label(text: String, rect: Rect2, size: int = 18) -> Label:
	var label := Label.new()
	label.text = _localized(text)
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",INK)
	ui.add_child(label)
	return label

func _button(text: String, rect: Rect2, callback: Callable) -> Button:
	var button: Button
	if has_node("/root/LocalizationSystem") and ResourceLoader.exists("res://scripts/ui/components/solmere_button.gd"):
		button=load("res://scripts/ui/components/solmere_button.gd").new()
		button.variant="paper"
	else: button=Button.new()
	button.text = _localized(text)
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font",font)
	button.add_theme_font_size_override("font_size",17)
	button.add_theme_color_override("font_color",INK)
	button.add_theme_color_override("font_hover_color",Color("87533b"))
	button.add_theme_stylebox_override("normal",_paper_style())
	button.add_theme_stylebox_override("hover",_paper_style())
	button.pressed.connect(callback)
	ui.add_child(button)
	return button

func build_ui() -> void:
	if not ui: return
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	var ribbon := Panel.new()
	ribbon.position = Vector2(385,815)
	ribbon.size = Vector2(725,32)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.add_theme_stylebox_override("panel",_paper_style())
	ui.add_child(ribbon)
	_label(hint,Rect2(400,821,700,28),14)
	if mode in [Mode.DESK,Mode.DRAWING,Mode.TAPE,Mode.SENT,Mode.GLUE]:
		_button("代写信件  /  委托",Rect2(30,122,225,60),show_notes)
		_button("自由拼贴  /  素材",Rect2(30,194,225,60),func(): open_browser())
		_button("漂流信箱  /  回信",Rect2(30,266,225,60),open_bottles)
		_build_material_rack()
		_build_shelf()
		if is_instance_valid(active) and active != main_paper:
			_button("翻到正面" if active.flipped else "翻到背面",Rect2(450,495,125,32),flip_active)
			_button("压贴 / 揭起",Rect2(585,495,130,32),press_active)
			_button("涂背胶",Rect2(725,495,115,32),func(): use_tool("glue"))
		_button("笔记",Rect2(1430,26,65,38),show_notes)
		_button("设置",Rect2(1510,26,65,38),show_settings)
		_button("完成 · 折信" if mode != Mode.SENT else "写下一封",Rect2(1375,858,197,36),begin_folding if mode != Mode.SENT else restart)
		if mode in [Mode.DRAWING,Mode.TAPE,Mode.GLUE]: _button("放回工具",Rect2(1150,532,220,33),return_desk)
	else:
		_button("← 回到桌边",Rect2(32,28,155,40),return_desk)
		if mode == Mode.MATERIAL_BROWSER:
			_button("〈",Rect2(378,423,48,58),func(): browse(-1))
			_button("〉",Rect2(1174,423,48,58),func(): browse(1))
			_button("拿到桌上",Rect2(704,736,190,42),take_material)
			var categories: Array = ["全部"]
			for material in materials:
				var kind: String=material.get("paper_type",material.category)
				if kind not in categories: categories.append(kind)
			for i in categories.size():
				var category: String = categories[i]
				_button(category,Rect2(338+i*113,127,105,33),func(): browser_category=category;browser_index=0;_update_browser();build_ui())
		if mode == Mode.SCISSOR_CUTTING:
			_label("Shift + 拖动端点规划剪线，再从圆点沿线慢慢剪。",Rect2(516,145,680,38))
		if mode == Mode.CUTTING_MAT:
			_button("拿起刻刀",Rect2(688,760,220,40),take_knife)
		if mode == Mode.TYPEWRITER:
			var save_button := _button("正在逐字打完…" if type_save_requested else "SAVE · 抽出纸张",Rect2(1160,715,212,46),save_typed_paper)
			save_button.disabled = type_save_requested
			_label("直接敲键盘 · Enter 换行 · Backspace 退格",Rect2(555,155,660,32),16)
		if mode == Mode.WAX_SEALING and wax_step == 6:
			_button("SEND · 寄出",Rect2(1120,750,210,52),send_letter)
	if notes_open or settings_open: _build_note_panel()
	var overlay := Node2D.new()
	overlay.set_script(preload("workshop_overlay.gd"))
	overlay.workshop = self
	ui.add_child(overlay)

func say(message: String) -> void:
	hint = message
	build_ui()

func _material_ids() -> Array:
	var ids: Array = []
	for i in materials.size():
		if browser_category == "全部" or materials[i].get("paper_type",materials[i].category) == browser_category: ids.append(i)
	return ids

func open_browser() -> void:
	if mode not in [Mode.DESK,Mode.DRAWING,Mode.SENT]: return
	_return_focus()
	mode = Mode.MATERIAL_BROWSER
	tools_root.hide()
	papers.hide()
	_update_browser()
	say("一张一张翻，不必急着选。")

func _update_browser() -> void:
	var ids := _material_ids()
	if ids.is_empty(): return
	browser_index = posmod(browser_index,ids.size())
	var material: Dictionary = materials[ids[browser_index]]
	preview_image = ImageTexture.create_from_image(material_images[ids[browser_index]])
	audio.play("PAPER_MOVE",0.45)

func browse(direction: int) -> void:
	browser_index += direction
	_update_browser()
	var tween := create_tween()
	var target := 0.9
	focus_amount = target
	tween.tween_property(self,"focus_amount",1.0,0.2)

func _draw_browser() -> void:
	if preview_image:
		var ids := _material_ids()
		var rect := Rect2(455,210,690,505)
		if materials[ids[browser_index]].kind == "decoration":
			var fit := minf(rect.size.x/preview_image.get_width(),rect.size.y/preview_image.get_height())
			var size := preview_image.get_size()*fit
			rect = Rect2(rect.get_center()-size*0.5,size)
		draw_texture_rect(preview_image,rect,false)
		_caption("%s   %d / %d" % [materials[ids[browser_index]].title,browser_index+1,ids.size()],Vector2(585,195),20,CREAM)

func take_material() -> void:
	checkpoint()
	var id: int = _material_ids()[browser_index]
	var decoration: bool = materials[id].kind == "decoration"
	var at: Vector2 = main_paper.position + Vector2(100,50) if decoration else Vector2(650,640)
	var paper = create_paper(material_images[id],at,materials[id].title,"decoration" if decoration else "paper")
	paper.source_id = id
	paper.photo_id = str(materials[id].get("photo_id",""))
	paper.scale = Vector2.ONE * 1.0
	return_desk()
	select_paper(paper)
	say("拖动摆放 · Q / E 旋转 · 滚轮缩放 · [ / ] 调整前后 · Ctrl+Z 撤销")

func create_paper(image: Image, at: Vector2, title: String, kind: String = "paper") -> Node2D:
	var paper := Paper.new()
	paper.object_id = Crypto.new().generate_random_bytes(8).hex_encode()
	paper.title = title
	paper.paper_kind = kind
	paper.set_image(image)
	paper.position = at
	paper.z_index = papers.get_child_count()
	papers.add_child(paper)
	return paper

func select_paper(paper: Node2D) -> void:
	if is_instance_valid(active): active.selected = false; active.queue_redraw()
	active = paper
	if is_instance_valid(active): active.selected = true; active.queue_redraw()
	if ready_done: build_ui()

func paper_at(point: Vector2) -> Node2D:
	var found: Node2D
	for paper in papers.get_children():
		if paper.contains_point(point) and (not found or paper.z_index >= found.z_index): found = paper
	return found

func _focus_paper(paper: Node2D) -> void:
	if not paper or paper == main_paper: return
	focused = paper
	focused_original = {"position":paper.position, "rotation":paper.rotation, "scale":paper.scale}
	for other in papers.get_children(): other.visible = other == paper
	tools_root.hide()
	var tween := create_tween().set_parallel(true)
	focus_tween=tween
	tween.tween_property(paper,"position",Vector2(800,440),0.28).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(paper,"rotation",0.0,0.28)
	var fit := minf(620.0/paper.image.get_width(),420.0/paper.image.get_height())
	tween.tween_property(paper,"scale",Vector2.ONE*fit,0.28)

func _return_focus() -> void:
	if focus_tween and focus_tween.is_valid(): focus_tween.kill()
	if is_instance_valid(focused) and not focused_original.is_empty():
		focused.position = focused_original.position
		focused.rotation = focused_original.rotation
		focused.scale = focused_original.scale
	focused = null
	focused_original = {}
	for paper in papers.get_children(): paper.show()

func return_desk() -> void:
	if busy: return
	if mode in [Mode.FOLDING,Mode.ENVELOPE,Mode.WAX_SEALING]:
		mode = Mode.DESK
		stage = "WORKBENCH"
		fold = 0
		wax_step = 0
		wax_drag = ""
	_return_focus()
	mode = Mode.DESK
	type_save_requested = false
	DisplayServer.window_set_ime_active(false)
	tool = "move"
	cutting = false
	knife_path.clear()
	ink_target = null
	if is_instance_valid(dragged): dragged.held=false
	dragged = null
	dragged_tool = null
	papers.show()
	tools_root.show()
	say("桌边的物件都可以试试。Ctrl+Z / Ctrl+Y 撤销或重做。")

func use_tool(id: String) -> void:
	match id:
		"typewriter":
			mode=Mode.TYPEWRITER; papers.hide();tools_root.hide()
			_ensure_type_page()
			type_ink.queue_redraw()
			DisplayServer.window_set_ime_active(true)
			DisplayServer.window_set_ime_position(Vector2i(680,300))
			say("按下一个字母，听见一小声回应。")
		"scissors":
			if tape_pending: finish_tape();return
			if is_instance_valid(active) and active.is_cuttable and not active.attached and not active.flipped:
				checkpoint();_focus_paper(active);mode=Mode.SCISSOR_CUTTING
				cut_start=Vector2(485,420);cut_end=Vector2(1115,465);cut_progress=0
				say("拖动端点调整剪线，从圆点起剪。")
			else:
				tool="choose_scissors";say("先点一张桌上的纸，剪刀会跟着过去。")
		"mat":
			mode=Mode.CUTTING_MAT
			say("刻板保持原位。把纸拖到绿色刻板上，再拿起刻刀。")
		"knife":
			take_knife()
		"pen", "pencil", "marker":
			mode=Mode.DRAWING;tool=id
			pen_width={"pen":1.3,"pencil":0.8,"marker":7.0}[id]
			pen_color={"pen":Color("34464a"),"pencil":Color("807c72"),"marker":Color("c28d72")}[id]
			say("按住写画 · 右键切换粗细 · Esc 放回笔")
		"glue":
			if not is_instance_valid(active) or active == main_paper:
				say("先选一张纸片，再拿胶棒。背胶只涂在纸片背面。")
				return
			if active.attached: say("先点‘压贴 / 揭起’揭下纸片。") ;return
			if not active.flipped: checkpoint();active.flipped=true;active.queue_redraw()
			mode=Mode.GLUE;tool="glue";say("按住涂背胶；翻回正面，放在信纸上，点‘压贴’。")
		"tape":
			mode=Mode.TAPE;tool="tape";say("按住拉出胶带，松开后仍连着胶带卷，再点剪刀剪断。")
		"envelope": begin_folding()
		"wax-tray", "candle", "spoon", "stamp", "matchbox": say("先完成拼贴、折信和装封，再来点蜡烛。")

func take_knife() -> void:
	if mode not in [Mode.DESK,Mode.CUTTING_MAT]: return
	if not is_instance_valid(active) or active == main_paper or not active.is_cuttable or active.attached or active.flipped or not mat_tool.contains_point(active.position):
		say("先把一张可裁切的纸拖到绿色刻板上。")
		return
	checkpoint()
	focused=active
	focused_original={"position":active.position,"rotation":active.rotation,"scale":active.scale}
	mode=Mode.KNIFE_CUTTING
	tool="knife"
	say("按住自由划线；闭合一圈挖出局部，边到边划线分成两张。")

func _input(event: InputEvent) -> void:
	# Keep a started gesture captured even when the pointer crosses a UI button.
	# Otherwise a GUI-consumed release would leave paper/tools stuck to the mouse.
	if not ready_done or dock_open or busy: return
	var captured: bool=dragged!=null or dragged_tool!=null or ink_target!=null or tape_pulling or cutting or cut_handle>=0 or fold_drag or not packing_drag.is_empty() or not wax_drag.is_empty()
	if not captured or not event is InputEventMouse: return
	previous_pointer=pointer
	pointer=get_global_transform_with_canvas().affine_inverse()*event.position
	if event is InputEventMouseMotion:
		_motion(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		_release()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not ready_done or dock_open or busy or notes_open or settings_open: return
	if event is InputEventKey and event.pressed:
		if mode == Mode.TYPEWRITER:
			_type_key(event);get_viewport().set_input_as_handled();return
		if event.keycode == KEY_ESCAPE: return_desk();return
		if mode==Mode.GLUE and event.keycode==KEY_F: flip_active();return
		if event.ctrl_pressed and event.keycode == KEY_Z: undo();return
		if event.ctrl_pressed and event.keycode == KEY_Y: redo();return
		if mode in [Mode.DESK,Mode.CUTTING_MAT] and is_instance_valid(active):
			match event.keycode:
				KEY_F: flip_active()
				KEY_P: press_active()
				KEY_Q:
					if not active.attached: checkpoint();active.rotation -= 0.055
				KEY_E:
					if not active.attached: checkpoint();active.rotation += 0.055
				KEY_BRACKETLEFT: checkpoint();active.z_index = maxi(1,active.z_index-1)
				KEY_BRACKETRIGHT: checkpoint();active.z_index += 1
				KEY_DELETE:
					if active != main_paper: checkpoint();active.queue_free();active=null
		return
	if event is InputEventMouse:
		previous_pointer = pointer
		pointer = get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventMouseMotion:
		_motion(event)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and mode == Mode.DRAWING:
			pen_width = 2.8 if pen_width < 2 else 1.3
			say("墨水笔 · 较粗" if pen_width > 2 else "钢笔 · 较细")
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			if is_instance_valid(active) and not active.attached and mode in [Mode.DESK,Mode.CUTTING_MAT]:
				checkpoint();active.scale *= 1.06 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.94
				active.scale = active.scale.clamp(Vector2(0.25,0.25),Vector2(3,3))
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _press()
			else: _release()

func _motion(_event: InputEventMouseMotion) -> void:
	if pointer.distance_to(previous_pointer)>0.5:
		knife_angle=(pointer-previous_pointer).angle()+PI*0.5
		if cutting: scissor_phase+=pointer.distance_to(previous_pointer)*0.09
	if dragged_tool:
		dragged_tool.position += pointer-previous_pointer
	if dragged:
		dragged.position = (pointer-grab_offset).clamp(Vector2(70,170),Vector2(1510,810))
	if ink_target:
		if mode == Mode.GLUE:
			ink_target.paint_glue(ink_target.local_pixel(previous_pointer),ink_target.local_pixel(pointer))
			_sound_tick("GLUE_SPREAD",0.09)
		else:
			ink_target.stroke(ink_target.local_pixel(previous_pointer),ink_target.local_pixel(pointer),pen_width,pen_color)
			_sound_tick("PEN_WRITE",0.065)
	if tape_pulling:
		tape_end=pointer;tape_angle+=pointer.distance_to(previous_pointer)*0.05
		_sound_tick("TAPE_PULL",0.16)
	if mode == Mode.SCISSOR_CUTTING: _scissor_motion()
	if mode == Mode.KNIFE_CUTTING and cutting:
		if knife_path.is_empty() or knife_path[-1].distance_to(pointer)>3: knife_path.append(pointer)
		_sound_tick("KNIFE_SLICE",0.08)
	if mode == Mode.FOLDING and fold_drag:
		fold_amount = clampf((600-pointer.y)/230.0,0,1) if fold == 0 else clampf((pointer.y-300)/225.0,0,1)
	if mode == Mode.ENVELOPE:
		if packing_drag == "letter": packed_letter_at=pointer
		if packing_drag == "flap": envelope_flap=clampf(flap_drag_start+(pointer.y-flap_drag_y)/330.0,0,1)
	if mode == Mode.WAX_SEALING and wax_drag == "match" and not match_lit:
		if Rect2(325,595,165,75).has_point(pointer):
			match_heat += pointer.distance_to(previous_pointer)
			_sound_tick("MATCH_STRIKE",0.15)
			if match_heat > 145: match_lit=true
	if mode == Mode.DESK:
		hovered_title=""
		for object in tools_root.get_children():
			object.set_hover(object.contains_point(pointer))
			if object.hovered: hovered_title=object.title
		var paper=paper_at(pointer)
		for item in papers.get_children(): item.set_hover(item==paper and item!=main_paper)
		if paper and paper!=main_paper: hovered_title=paper.title

func _press() -> void:
	match mode:
		Mode.DESK,Mode.CUTTING_MAT:
			if scissors_tool.is_visible_in_tree() and scissors_tool.contains_point(pointer):
				dragged_tool=scissors_tool;tool_drag_start=pointer;return
			# A sheet on the mat may cover the knife artwork; the explicit button
			# remains available, while uncovered tools are still directly usable.
			var paper=paper_at(pointer)
			if paper and paper!=main_paper:
				select_paper(paper)
				if tool=="choose_scissors": use_tool("scissors");return
				if paper.attached: say("纸片已经压贴；点‘压贴 / 揭起’才能移动。") ;return
				checkpoint();paper.held=true;dragged=paper;grab_offset=pointer-paper.position;paper.z_index=papers.get_child_count()+1
				audio.play("PAPER_MOVE",0.5);return
			var objects=tools_root.get_children();objects.reverse()
			for object in objects:
				if object.contains_point(pointer): use_tool(object.action);return
		Mode.GLUE:
			if is_instance_valid(active) and active.flipped and active.contains_point(pointer):
				checkpoint();ink_target=active;active.paint_glue(active.local_pixel(pointer),active.local_pixel(pointer))
		Mode.DRAWING:
			var paper=paper_at(pointer)
			if paper and not paper.flipped: checkpoint();ink_target=paper
		Mode.TAPE:
			if scissors_tool.contains_point(pointer) and tape_pending: finish_tape();return
			if not tape_pending: tape_start=pointer;tape_end=pointer;tape_pulling=true
		Mode.SCISSOR_CUTTING:
			if pointer.distance_to(cut_start)<20 and Input.is_key_pressed(KEY_SHIFT): cut_handle=0
			elif pointer.distance_to(cut_end)<20 and Input.is_key_pressed(KEY_SHIFT): cut_handle=1
			elif pointer.distance_to(cut_start.lerp(cut_end,cut_progress))<42: cutting=true
		Mode.KNIFE_CUTTING:
			cutting=true;knife_path=PackedVector2Array([pointer])
		Mode.FOLDING: fold_drag=true
		Mode.ENVELOPE:
			if not envelope_inserted and pointer.distance_to(packed_letter_at)<160: packing_drag="letter"
			elif envelope_inserted and insert_amount>=1:
				packing_drag="flap";flap_drag_y=pointer.y;flap_drag_start=envelope_flap
		Mode.WAX_SEALING: _wax_press()

func _release() -> void:
	if dragged_tool:
		var moved := tool_drag_start.distance_to(pointer)>6
		dragged_tool=null
		var target_paper=paper_at(pointer)
		if moved and target_paper and target_paper.is_cuttable: select_paper(target_paper);use_tool("scissors")
		elif not moved: use_tool("scissors")
		return
	if dragged:
		dragged.held=false
		if mat_tool.contains_point(dragged.position):
			mat_paper_id=dragged.object_id
			say("纸已经铺在刻板上。现在可以拿起刻刀。")
		audio.play("PAPER_PRESS",0.4);dragged=null
	ink_target=null
	if tape_pulling:
		tape_pulling=false;tape_pending=tape_start.distance_to(tape_end)>20
		say("胶带仍连着卷。点右侧剪刀，剪断这段胶带。")
	if mode==Mode.SCISSOR_CUTTING: cutting=false;cut_handle=-1
	if mode==Mode.KNIFE_CUTTING and cutting:
		if knife_path.is_empty() or knife_path[-1].distance_to(pointer)>0.5: knife_path.append(pointer)
		cutting=false;_finish_knife()
	if mode==Mode.FOLDING and fold_drag:
		fold_drag=false
		if fold_amount>0.65:
			fold+=1;audio.play("PAPER_FOLD",0.7)
			if fold>=2:
				mode=Mode.ENVELOPE;stage="ENVELOPE";packed_letter_at=Vector2(490,470)
				say("把折好的信拖进信封开口。")
			else: say("再把上半部向下折，留下两道折痕。")
		fold_amount=0
	if mode==Mode.ENVELOPE:
		if packing_drag=="letter" and Rect2(760,335,500,260).has_point(pointer):
			envelope_inserted=true;audio.play("ENVELOPE_INSERT",0.7)
			insert_amount=0
			create_tween().tween_property(self,"insert_amount",1.0,0.55).set_trans(Tween.TRANS_CUBIC)
			say("拖动上方信封盖，向下合上。")
		if packing_drag=="flap" and envelope_flap>0.72:
			envelope_flap=1;mode=Mode.WAX_SEALING;stage="WAX_SEAL";wax_step=0
			audio.play("ENVELOPE_CLOSE",0.7);say("拿火柴在火柴盒侧面划动，再移到灯芯。")
		packing_drag=""
	if mode==Mode.WAX_SEALING: _wax_release()

func _sound_tick(id: String, interval: float) -> void:
	if sound_clock>interval: audio.play(id,0.32);sound_clock=0

func _scissor_motion() -> void:
	if cut_handle==0: cut_start=pointer;cut_progress=0
	elif cut_handle==1: cut_end=pointer;cut_progress=0
	elif cutting:
		var line := cut_end-cut_start
		if line.length()<30: return
		var along := clampf((pointer-cut_start).dot(line)/line.length_squared(),0,1)
		var near := cut_start.lerp(cut_end,along)
		if pointer.distance_to(near)<32 and along<=cut_progress+0.13:
			cut_progress=maxf(cut_progress,along)
			_sound_tick("SCISSOR_CUT",0.10)
			if cut_progress>0.96:
				var a: Vector2=focused.local_pixel(cut_start)
				var b: Vector2=focused.local_pixel(cut_end)
				var tangent := (b-a).normalized()*3000
				var normal := Vector2(-tangent.y,tangent.x)
				_split_focused(PackedVector2Array([a-tangent,b+tangent,b+tangent+normal,a-tangent+normal]),"scissors")

func _finish_knife() -> void:
	if not focused or knife_path.size()<2: knife_path.clear();return
	var local_path := PackedVector2Array()
	for point in knife_path: local_path.append(focused.local_pixel(point))
	if local_path.size()<3 or knife_path[0].distance_to(knife_path[-1])>28:
		# An open stroke must enter and leave the paper. Close it around the
		# clockwise edge, keeping the actual curved stroke as the cut boundary.
		var dimensions: Vector2=focused.image.get_size()
		# Mouse strokes normally begin/end beyond the paper. Clip that actual
		# crossing instead of rejecting it for being over 20 pixels outside.
		for endpoint in [0,local_path.size()-1]:
			var near := _border_point(local_path[endpoint],dimensions)
			if local_path[endpoint].distance_to(near)<=20: local_path[endpoint]=near
		var boundary := PackedVector2Array([Vector2.ZERO,Vector2(dimensions.x,0),dimensions,Vector2(0,dimensions.y)])
		var paths := Geometry2D.intersect_polyline_with_polygon(local_path,boundary)
		if paths.size()!=1 or paths[0].size()<2:
			knife_path.clear();say("让这一刀穿过纸面，或在纸上闭合一圈。")
			return
		local_path=paths[0]
		var first := _border_point(local_path[0],dimensions)
		var last := _border_point(local_path[-1],dimensions)
		if local_path[0].distance_to(first)>20 or local_path[-1].distance_to(last)>20:
			knife_path.clear();say("镂空请闭合一圈；分纸请从纸边划到另一处纸边。")
			return
		local_path[0]=first;local_path[-1]=last
		var perimeter := 2*(dimensions.x+dimensions.y)
		var first_t := _border_time(first,dimensions)
		var last_t := _border_time(last,dimensions)
		if first_t<=last_t: first_t+=perimeter
		var corners := [Vector2.ZERO,Vector2(dimensions.x,0),dimensions,Vector2(0,dimensions.y),Vector2.ZERO]
		var times := [0.0,dimensions.x,dimensions.x+dimensions.y,2*dimensions.x+dimensions.y,perimeter]
		for lap in range(2):
			for i in range(1,5):
				var moment: float=times[i]+lap*perimeter
				if moment>last_t and moment<first_t: local_path.append(corners[i])
	_split_focused(local_path,"knife")
	knife_path.clear()

func _border_point(point: Vector2, dimensions: Vector2) -> Vector2:
	var p:=point.clamp(Vector2.ZERO,dimensions)
	var distances := [p.y,dimensions.x-p.x,dimensions.y-p.y,p.x]
	match distances.find(distances.min()):
		0: p.y=0
		1: p.x=dimensions.x
		2: p.y=dimensions.y
		3: p.x=0
	return p

func _border_time(p: Vector2, size: Vector2) -> float:
	if p.y==0: return p.x
	if p.x==size.x: return size.x+p.y
	if p.y==size.y: return size.x+size.y+size.x-p.x
	return 2*size.x+size.y+size.y-p.y

func _split_focused(polygon: PackedVector2Array, kind: String) -> void:
	if not is_instance_valid(focused): return
	var halves: Array=focused.split_mask(polygon,kind)
	if halves.is_empty(): say("这一刀没有分开纸面，换一条经过纸张的线试试。") ;return
	var title: String=focused.title
	var source_id: int=focused.source_id
	var photo_id: String=focused.photo_id
	var history: Array=focused.cut_history.duplicate(true)
	_return_focus()
	var original=active
	var at: Vector2=original.position
	var scale_before: Vector2=original.scale
	var rotation_before: float=original.rotation
	papers.remove_child(original);original.queue_free();active=null
	for i in halves.size():
		var piece=create_paper(halves[i],at+Vector2((i*2-1)*28,0),title+" · 裁片")
		piece.scale=scale_before;piece.rotation=rotation_before
		piece.photo_id=photo_id
		piece.source_id=source_id;piece.cut_history=history.duplicate(true)
		select_paper(piece)
	cutting=false
	audio.play("PAPER_CUT",0.6)
	return_desk()
	say("两边都留下了。透明的空洞也是真正裁开的。")

func finish_tape() -> void:
	if not tape_pending: return
	checkpoint()
	var length:=clampi(int(tape_start.distance_to(tape_end)),25,700)
	var tape:=Image.create(length,26,false,Image.FORMAT_RGBA8)
	for y in 26:
		for x in length:
			if x<2+int(y%3) or x>length-3-int(y%2): continue
			var color:=Color(0.64,0.72,0.72,0.68)
			if x%15<2 or y%13<2: color=Color(0.89,0.86,0.71,0.72)
			tape.set_pixel(x,y,color)
	var piece=create_paper(tape,(tape_start+tape_end)*0.5,"纸胶带","tape")
	piece.rotation=(tape_end-tape_start).angle()
	for paper in papers.get_children():
		if paper!=piece and paper.contains_point(piece.position):
			paper.tape_layers.append(piece.object_id)
	select_paper(piece)
	tape_pending=false;tape_pulling=false
	audio.play("TAPE_TEAR",0.7)
	audio.play("TAPE_STICK",0.4)
	return_desk()

func _type_key(event: InputEventKey) -> void:
	if event.keycode==KEY_ESCAPE: return_desk();return
	if event.echo or type_save_requested: return
	if event.ctrl_pressed and event.keycode==KEY_V:
		_queue_type_text(DisplayServer.clipboard_get())
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
	match event.keycode:
		KEY_BACKSPACE: _queue_type_text("\b")
		KEY_ENTER,KEY_KP_ENTER: _queue_type_text("\n")
		KEY_SPACE: _queue_type_text(" ")
		_:
			if event.unicode>=32: _queue_type_text(String.chr(event.unicode))

func _apply_type_operation(text: String, operation: String) -> String:
	return text.left(maxi(0,text.length()-1)) if operation=="\b" else text+operation

func _pending_type_text() -> String:
	var text:=typed_text
	for operation in type_queue: text=_apply_type_operation(text,operation)
	return text

func _queue_type_text(text: String) -> void:
	var projected:=_pending_type_text()
	for letter in text.replace("\r\n","\n").replace("\r","\n").replace("\t","    "):
		if letter.unicode_at(0)<32 and letter not in ["\n","\b"]: continue
		var next:=_apply_type_operation(projected,letter)
		if _type_fits(next) and type_queue.size()<512:
			type_queue.append(letter)
			projected=next
		elif letter!="\b":
			say("这张纸写满了。抽出纸张，再写下一张。")
			break

func _advance_typewriter(delta: float) -> void:
	if busy: return
	type_delay=maxf(0,type_delay-delta)
	if type_delay>0: return
	if type_queue.is_empty():
		if type_save_requested:
			type_save_requested=false
			save_typed_paper()
		return
	# At most one strike per rendered frame, even after a slow frame or IME batch.
	var operation: String=type_queue.pop_front()
	typed_text=_apply_type_operation(typed_text,operation)
	type_key=operation.to_upper()
	key_age=0
	type_delay=0.085
	var sound:="TYPE_KEY"
	match operation:
		"\n": type_key="Enter";carriage=25;type_delay=0.30;sound="TYPE_RETURN"
		"\b": type_key="Backspace";sound="TYPE_BACKSPACE"
		" ": type_key="Space";sound="TYPE_SPACE"
	audio.play(sound,0.55)
	_ensure_type_page()
	type_ink.queue_redraw()
	queue_redraw()

func _type_fits(text: String) -> bool:
	return TypeLayout.arrange(text,mono).fits

func _draw_type_ink() -> void:
	for glyph in TypeLayout.arrange(typed_text,mono).glyphs:
		var index: int=glyph.index
		var at: Vector2=glyph.position+Vector2(sin(index*19.2)*0.35,sin(index*32.5)*0.35)
		var opacity:=0.84+0.15*absf(sin(index*12.17+0.9))
		type_ink.draw_string(mono,at,glyph.text,HORIZONTAL_ALIGNMENT_LEFT,-1,TypeLayout.FONT_SIZE,Color(INK,opacity))

func _ensure_type_page() -> void:
	if is_instance_valid(type_viewport): return
	type_viewport=SubViewport.new()
	type_viewport.size=TypeLayout.PAGE_SIZE
	type_viewport.transparent_bg=true
	type_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(type_viewport)
	type_ink=Node2D.new()
	type_viewport.add_child(type_ink)
	type_ink.draw.connect(_draw_type_ink)
	type_ink.queue_redraw()

func _draw_typewriter() -> void:
	var zoom:=lerpf(0.90,1.0,focus_amount)
	var box:=Rect2(Vector2(365,198)+Vector2(carriage,0),Vector2(870,600)*zoom)
	_sprite("typewriter",box)
	draw_set_transform(box.position,0,Vector2.ONE*zoom)
	if is_instance_valid(type_viewport):
		# Ink follows the perspective of the actual paper and cannot reach the keys.
		var paper_quad:=PackedVector2Array([Vector2(205,12),Vector2(665,12),Vector2(665,292),Vector2(205,292)])
		draw_polygon(paper_quad,PackedColorArray([Color.WHITE]),PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]),type_viewport.get_texture())
	var rows := ["QWERTYUIOP","ASDFGHJKL","ZXCVBNM"]
	for row in rows.size():
		for i in rows[row].length():
			var key: String=rows[row][i]
			var at:=Vector2(220+i*43+row*18,376+row*40)
			var down:=key_age<0.16 and type_key.to_upper()==key
			if down:
				draw_circle(at+Vector2(0,5),14,Color("988566"))
			draw_string(mono,at+Vector2(-5,5 if not down else 10),key,HORIZONTAL_ALIGNMENT_LEFT,-1,13,INK)
	if key_age<0.12:
			draw_line(Vector2(430,325),Vector2(435,282),Color("6b6250"),4,true)
	if type_key=="Space" and key_age<0.15: draw_line(Vector2(290,501),Vector2(570,501),Color(0.2,0.17,0.13,0.3),10,true)
	draw_set_transform(Vector2.ZERO)
	if eject_amount>0 and typed_preview:
		draw_texture_rect(typed_preview,Rect2(665,265-eject_amount*175,340,220),false)
		draw_line(Vector2(520,385),Vector2(1145,418),Color("746953"),3,true)

func save_typed_paper() -> void:
	if busy or mode!=Mode.TYPEWRITER: return
	if _pending_type_text().strip_edges().is_empty(): say("先敲下一句话，再抽出纸张。") ;return
	if not type_queue.is_empty():
		type_save_requested=true
		build_ui()
		return
	busy=true
	checkpoint()
	audio.play("TYPE_ROLLER",0.6)
	_ensure_type_page()
	type_ink.queue_redraw()
	await RenderingServer.frame_post_draw
	var image:=_blank_paper(TypeLayout.PAGE_SIZE)
	var ink_image:=type_viewport.get_texture().get_image()
	image.blend_rect(ink_image,Rect2i(Vector2i.ZERO,TypeLayout.PAGE_SIZE),Vector2i.ZERO)
	typed_preview=ImageTexture.create_from_image(image)
	eject_amount=0
	var tween:=create_tween()
	tween.tween_property(self,"eject_amount",1.0,0.65)
	await tween.finished
	audio.play("PAPER_MOVE",0.6)
	var paper=create_paper(image,Vector2(800,580),"打字纸","typed")
	typed_text=""
	type_ink.queue_redraw()
	select_paper(paper)
	eject_amount=0
	busy=false
	return_desk()
	say("你的话成为了一张纸。可以剪成单词，也可以整张留下。")

func begin_folding() -> void:
	if mode not in [Mode.DESK,Mode.DRAWING,Mode.TAPE,Mode.GLUE]: return
	for piece in papers.get_children():
		if piece.flipped: say("还有纸片朝着背面，翻回正面再折信。") ;return
	var has_content: bool=not main_paper.drawing_layer.is_empty()
	for paper in papers.get_children():
		if paper!=main_paper and main_paper.contains_point(paper.position): has_content=true
	if not has_content: say("信纸还空着。放一张裁片，或者拿笔写下几笔。") ;return
	if tape_pending: say("还有一段胶带没有剪断，先拿剪刀收尾。") ;return
	checkpoint()
	busy=true
	select_paper(null)
	# Render only the letter and the intersecting scraps, never the desk/UI.
	var viewport:=SubViewport.new()
	viewport.size=main_paper.image.get_size()
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var copies: Array=[]
	for paper in papers.get_children():
		var copy:=Paper.new()
		copy.restore(paper.record())
		copy.position=main_paper.to_local(paper.position)+Vector2(main_paper.image.get_size())*0.5
		copy.rotation=paper.rotation-main_paper.rotation
		viewport.add_child(copy)
		copies.append(copy)
	await RenderingServer.frame_post_draw
	letter_preview=ImageTexture.create_from_image(viewport.get_texture().get_image())
	viewport.queue_free()
	if not smoke: letter_preview.get_image().save_png(preview_path)
	envelope_inserted=false;envelope_flap=0;insert_amount=0;packing_drag=""
	wax_step=0;wax_heat=0;wax_pour=0;wax_hold=0;wax_cool=0;wax_drag=""
	match_lit=false;candle_lit=false;spoon_filled=false;spoon_on_fire=false;stamp_imprint=false
	mode=Mode.FOLDING;stage="FOLDING";fold=0;fold_amount=0
	papers.hide();tools_root.hide();busy=false
	say("把信纸下半部向上拖，折出第一道折痕。")

func _draw_folding() -> void:
	if not letter_preview: return
	var rect:=Rect2(530,225,540,480)
	draw_texture_rect(letter_preview,rect,false)
	var third:=rect.size.y/3
	for i in [1,2]: draw_line(Vector2(530,225+i*third),Vector2(1070,225+i*third),Color(0.38,0.31,0.21,0.25),1,true)
	if fold==0 and fold_amount>0:
		draw_texture_rect(letter_preview,Rect2(530,545-fold_amount*160,540,160*fold_amount),false,Color(1,0.97,0.9))
	if fold>=1:
		draw_rect(Rect2(530,545,540,160),Color(0.1,0.1,0.1,0.15))
		draw_style_box(_paper_style(),Rect2(530,385,540,160))
		if fold_amount>0: draw_style_box(_paper_style(),Rect2(530,225+fold_amount*160,540,160))
	_caption("01 / 下缘向上" if fold==0 else "02 / 上缘向下",Vector2(670,762),21,CREAM)

func _draw_envelope() -> void:
	var body := Rect2(760,435,525,295)
	if envelope_flap <= 0.5: _draw_envelope_flap(body,envelope_flap)
	if envelope_inserted and insert_amount<1:
		draw_style_box(_paper_style(),Rect2(Vector2(840,265).lerp(Vector2(840,445),insert_amount),Vector2(350,136*(1-insert_amount))))
	_draw_envelope_body(body)
	if envelope_flap > 0.5: _draw_envelope_flap(body,envelope_flap)
	if not envelope_inserted:
		var at:=packed_letter_at
		if packing_drag=="letter" and at.distance_to(Vector2(995,450))<135: at=at.lerp(Vector2(995,450),0.22)
		draw_style_box(_paper_style(),Rect2(at-Vector2(175,68),Vector2(350,136)))
		draw_line(at+Vector2(-165,-15),at+Vector2(165,-15),Color(0.36,0.29,0.22,0.16),1)

func _envelope_regions() -> Array[Rect2]:
	var texture: AtlasTexture = sprites.envelope
	var region := Rect2(280,20,976,960)
	# The source artwork's horizontal fold is at y=432. Keep its painted
	# edge, grain and alpha; split only the rendering, never paint over it.
	var hinge := 432.0
	return [Rect2(region.position,Vector2(region.size.x,hinge-region.position.y)),
		Rect2(region.position.x,hinge,region.size.x,region.end.y-hinge)]

func _draw_envelope_body(body: Rect2) -> void:
	var texture: AtlasTexture = sprites.envelope
	draw_texture_rect_region(texture.atlas,body,_envelope_regions()[1])

func _draw_envelope_flap(body: Rect2, closure: float) -> void:
	var texture: AtlasTexture = sprites.envelope
	var source := _envelope_regions()[0]
	var height := source.size.y * body.size.x / source.size.x
	var tilt := cos(clampf(closure,0,1) * PI)
	if absf(tilt) < 0.002: return
	draw_set_transform(body.position,0,Vector2(1,tilt))
	draw_texture_rect_region(texture.atlas,Rect2(0,-height,body.size.x,height),source)
	draw_set_transform(Vector2.ZERO)

func _draw_wax() -> void:
	# The extracted tray stays together on the desk; focus provides independently
	# moving tools with the same wood, brass and wax palette.
	# Put the painted flap tip at the wax interaction point (1000,477).
	var envelope_body := Rect2(760,275,480,270)
	_draw_envelope_body(envelope_body)
	_draw_envelope_flap(envelope_body,1.0)
	_sprite("matchbox",Rect2(300,595,190,100))
	# Candle and animated, layered translucent flame.
	_sprite("candle",Rect2(440,370,142,210))
	if candle_lit:
		_flame(Vector2(509,382),1.0)
	# The box contains actual visible pellets; the spoon changes through 4 phases.
	draw_rect(Rect2(319,292,150,78),Color("684b33"))
	for i in 17:
		var at:=Vector2(331+(i%6)*23,309+(i/6)*19)
		draw_circle(at,8,Color("a74835"));draw_circle(at+Vector2(-2,-2),3,Color("c36c45"))
	var spoon:=pointer if wax_drag=="spoon" else Vector2(600,322)
	if wax_step==2 and wax_drag!="spoon" and spoon_on_fire: spoon=Vector2(509,350)
	if wax_step==3 and wax_drag!="spoon": spoon=Vector2(600,322)
	var tilt:=clampf(wax_pour,0,1)*0.55
	draw_set_transform(spoon,tilt,Vector2.ONE)
	_sprite("spoon",Rect2(-37,-22,216,71))
	draw_set_transform(Vector2.ZERO)
	if spoon_filled:
		if wax_heat<2.8:
			for i in 5: draw_circle(spoon+Vector2(-19+i*9,sin(i)*5),maxf(3,7-wax_heat),Color("b44d36"))
		else: draw_ellipse_custom(spoon,Vector2(31,13),Color("b6452c").lerp(Color("da6846"),clampf((wax_heat-2.8)/3.2,0,1)))
	if wax_pour>0:
		if wax_drag=="spoon" and wax_step==3: draw_line(spoon+Vector2(-5,5),Vector2(1000,473),Color("be4a30"),5,true)
		var pool:=PackedVector2Array()
		for i in 48:
			var angle:=i*TAU/48
			var radius: float=(41+sin(i*2.7)*3)*minf(wax_pour,1.0)
			pool.append(Vector2(1000,477)+Vector2(cos(angle),sin(angle))*radius)
		draw_colored_polygon(pool,Color("d36742").lerp(Color("944333"),clampf(wax_cool/2.5,0,1)))
		if stamp_imprint:
			draw_arc(Vector2(1000,477),25,0,TAU,40,Color("783529"),2,true)
			draw_ellipse_custom(Vector2(1000,477),Vector2(14,9),Color("80372b"))
			draw_line(Vector2(1008,470),Vector2(1016,461),Color("80372b"),3,true)
	var stamp:=pointer if wax_drag=="stamp" else Vector2(1360,468)
	if wax_hold>0 and wax_hold<1.0: stamp=Vector2(1000,445)
	_sprite("stamp",Rect2(stamp+Vector2(-41,-121),Vector2(82,165)))
	var match_at:=pointer if wax_drag=="match" else Vector2(365,707)
	draw_line(match_at,match_at+Vector2(75,24),Color("d6b487"),6,true)
	draw_circle(match_at,5,Color("9c4c32"))
	if match_lit and wax_drag=="match": _flame(match_at,0.55)
	elif wax_drag=="match" and match_heat>0:
		for i in 4: draw_circle(match_at+Vector2(sin(elapsed*30+i)*12,-7-i*3),1.7,Color("ffd189"))
	var steps: Array=["划燃火柴，再点亮灯芯","把勺子移到红蜡粒上，舀一勺","放到火焰上方，慢慢等蜡融化","把勺子拖到封口，停留倾倒","按住印章，在蜡池停留一秒","让火漆慢慢凝固","封好了。现在可以寄出。"]
	_caption(steps[clampi(wax_step,0,6)],Vector2(450,175),25,CREAM)
	if wax_step==2: _caption("融蜡  %.1f / 6 秒" % wax_heat,Vector2(420,225),17,CREAM)

func draw_ellipse_custom(at: Vector2, radius: Vector2, color: Color) -> void:
	var polygon:=PackedVector2Array()
	for i in 40: polygon.append(at+Vector2(cos(i*TAU/40),sin(i*TAU/40))*radius)
	draw_colored_polygon(polygon,color)

func _flame(at: Vector2, size: float) -> void:
	var sway:=sin(elapsed*5.4)*5
	var height:=50+sin(elapsed*8.1)*5
	draw_circle(at,56*size,Color(1,0.71,0.27,0.045+0.01*sin(elapsed*5)))
	var flame:=PackedVector2Array([at+Vector2(-13,0)*size,at+Vector2(-9,-height*0.45)*size,at+Vector2(sway,-height)*size,at+Vector2(11,-height*0.4)*size,at+Vector2(13,0)*size])
	draw_colored_polygon(flame,Color(1,0.66,0.18,0.78))
	draw_ellipse_custom(at+Vector2(0,-12)*size,Vector2(7,18)*size,Color(1,0.91,0.62,0.93))

func _wax_press() -> void:
	if wax_step==0 and Rect2(285,590,220,165).has_point(pointer): wax_drag="match";match_heat=0
	elif wax_step in [1,2,3] and (pointer.distance_to(Vector2(600,322))<125 or pointer.distance_to(Vector2(509,350))<80): wax_drag="spoon";spoon_on_fire=false
	elif wax_step==4 and pointer.distance_to(Vector2(1360,455))<100: wax_drag="stamp"

func _wax_release() -> void:
	if wax_drag=="spoon":
		if wax_step==1 and Rect2(300,270,200,120).has_point(pointer):
			spoon_filled=true;wax_step=2;audio.play("WAX_PELLETS",0.65);say("把勺子放到火焰上方，保持六秒。")
		elif wax_step==2 and pointer.distance_to(Vector2(509,350))<90:
			# Rest on the holder over the flame, so the slow melt is watchable.
			spoon_on_fire=true;wax_drag="";return
	if wax_drag=="stamp" and wax_hold>=1:
		stamp_imprint=true;wax_step=5;wax_drag="";audio.play("STAMP_RELEASE",0.7)
		return
	if wax_drag=="stamp": wax_hold=0
	wax_drag=""

func _process_wax(delta: float) -> void:
	if wax_step==0 and match_lit and wax_drag=="match" and pointer.distance_to(Vector2(509,382))<40:
		wax_hold+=delta
		if wax_hold>0.5: candle_lit=true;wax_step=1;wax_hold=0;audio.play("FIRE_LOOP",0.3);say("拿起金属勺，到红色蜡粒盒中舀蜡。")
	if candle_lit: _sound_tick("FIRE_LOOP",0.6)
	if wax_step==2 and candle_lit and spoon_filled:
		if spoon_on_fire or (wax_drag=="spoon" and pointer.distance_to(Vector2(509,350))<85):
			wax_heat=minf(6,wax_heat+delta)
			if wax_heat>=6: wax_step=3;say("蜡已融化。把勺子移到信封封口，停留倾倒。")
	if wax_step==3 and wax_drag=="spoon" and pointer.distance_to(Vector2(1000,455))<95:
		wax_pour=minf(1,wax_pour+delta/1.8)
		_sound_tick("WAX_POUR",0.3)
		if wax_pour>=1: wax_step=4;spoon_filled=false;wax_drag="";say("拿起木柄印章，压住温软的火漆一秒，再松开。")
	if wax_step==4 and wax_drag=="stamp":
		if pointer.distance_to(Vector2(1000,477))<60:
			if wax_hold==0: audio.play("STAMP_PRESS",0.6)
			wax_hold+=delta
		else: wax_hold=0
	if wax_step==5:
		wax_cool+=delta
		if wax_cool>=2.5: wax_step=6;say("柠檬印记已经凝固。寄出吧。")

func send_letter() -> void:
	if mode!=Mode.WAX_SEALING or wax_step!=6 or busy: return
	if letter_mode!="npc":
		await send_bottle()
		return
	stage="END";mode=Mode.SENT
	audio.play("MAIL_DROP",0.7)
	say("信已封存。谢谢你留给这封信的时间。")
	save_game()

func open_bottles() -> void:
	if busy or dock_open or mode not in [Mode.DESK,Mode.SENT]: return
	save_game();dock_open=true
	var dock:=BottleDock.new()
	dock.client=bottle;dock.font=font
	add_child(dock)
	dock.compose_requested.connect(start_bottle)
	dock.closed.connect(func(): dock_open=false)
	dock.open()

func start_bottle(parent: Dictionary) -> void:
	if mode==Mode.SENT: restart()
	letter_mode="bottle" if parent.is_empty() else "reply"
	reply_parent=parent.duplicate(true)
	compose_server=bottle.base_url
	letter_title="窗边的一封信" if parent.is_empty() else ("回信："+str(parent.get("title",""))).left(40)
	bottle_request_id="";bottle_published_id=0
	return_desk()
	say("写给还没有遇见的人。" if parent.is_empty() else "正在回复："+str(parent.get("title","")))

func send_bottle() -> void:
	if not letter_preview: return
	if not compose_server.is_empty() and compose_server!=bottle.base_url: say("请连接这封草稿原来的邮局，再寄出。") ;return
	busy=true
	if bottle.player.is_empty():
		var connection: Dictionary=await bottle.connect_service(bottle.base_url,bottle.display_name)
		if not connection.ok: busy=false;say(connection.get("error","连接失败"));return
	if bottle_request_id.is_empty(): bottle_request_id=Crypto.new().generate_random_bytes(16).hex_encode();save_game()
	var payload: Dictionary={"request_id":bottle_request_id,"title":letter_title,"caption":"","art_png":Marshalls.raw_to_base64(letter_preview.get_image().save_png_to_buffer()),"parent_id":reply_parent.get("id") if letter_mode=="reply" else null}
	var result: Dictionary=await bottle.publish(payload)
	busy=false
	if not result.ok: say(result.get("error","寄出失败，信仍在这里。"));return
	bottle_published_id=int(result.letter_id)
	stage="END";mode=Mode.SENT
	audio.play("MAIL_DROP",0.7)
	say("漂流瓶已寄出。读一封旧信，给另一个人回信。" if letter_mode=="bottle" else "回信已送出，可以再写一封新的漂流瓶。")
	save_game()

func restart() -> void:
	checkpoint()
	for paper in papers.get_children():
		if paper!=main_paper: papers.remove_child(paper);paper.queue_free()
	main_paper.set_image(_blank_paper(Vector2i(500,290)))
	main_paper.drawing_layer.clear();main_paper.tape_layers.clear()
	active=null;stage="WORKBENCH";letter_mode="npc";bottle_published_id=0;bottle_request_id=""
	wax_step=0;wax_heat=0;wax_pour=0;wax_hold=0;wax_cool=0;match_lit=false;candle_lit=false;spoon_filled=false;stamp_imprint=false
	envelope_inserted=false;envelope_flap=0;fold=0;letter_preview=null
	return_desk()

func snapshot() -> Dictionary:
	var records: Array=[]
	for paper in papers.get_children():
		var record: Dictionary=paper.record()
		if paper==focused and not focused_original.is_empty():
			var p: Vector2=focused_original.position
			var s: Vector2=focused_original.scale
			record.position=[p.x,p.y];record.scale=[s.x,s.y];record.rotation=focused_original.rotation
		records.append(record)
	return {"version":3,"catalog":"open-office-1","papers":records,"stage":stage,"letter_mode":letter_mode,"parent":reply_parent,"server":compose_server,"type_draft":_pending_type_text(),"haptic_level":audio.haptic_level,"muted":audio.muted,
		"title":letter_title,"request_id":bottle_request_id,"published_id":bottle_published_id,
		"fold":fold,"inserted":envelope_inserted,"flap":envelope_flap,"wax_step":wax_step,"wax_heat":wax_heat,"wax_pour":wax_pour,
		"wax_cool":wax_cool,"candle":candle_lit,"spoon":spoon_filled,"spoon_on_fire":spoon_on_fire,"imprint":stamp_imprint,
		"preview":Marshalls.raw_to_base64(letter_preview.get_image().save_png_to_buffer()) if letter_preview else ""}

func restore_snapshot(data: Dictionary) -> void:
	audio.haptic_level=clampi(int(data.get("haptic_level",audio.haptic_level)),0,3)
	audio.muted=bool(data.get("muted",audio.muted))
	focused=null;focused_original={};active=null;dragged=null;ink_target=null
	for paper in papers.get_children(): papers.remove_child(paper);paper.queue_free()
	for original_record in data.get("papers",[]):
		var record: Dictionary=original_record.duplicate(true)
		# Preserve player-authored collages embedded in local saves; retired assets are never loaded.
		var paper:=Paper.new()
		if paper.restore(record):
			papers.add_child(paper)
			if paper.object_id=="letter":
				main_paper=paper
				if data.get("catalog","") != "open-office-1":
					main_paper.position=Vector2(765,690)
		else: paper.free()
	stage=data.get("stage","WORKBENCH")
	typed_text=data.get("type_draft","")
	type_queue.clear();type_delay=0;type_save_requested=false
	if is_instance_valid(type_ink): type_ink.queue_redraw()
	letter_mode=data.get("letter_mode","npc");reply_parent=data.get("parent",{});compose_server=data.get("server","")
	letter_title=data.get("title","窗边的一封信");bottle_request_id=data.get("request_id","");bottle_published_id=int(data.get("published_id",0))
	fold=int(data.get("fold",0));envelope_inserted=data.get("inserted",false);envelope_flap=float(data.get("flap",0))
	wax_step=int(data.get("wax_step",0));wax_heat=float(data.get("wax_heat",0));wax_pour=float(data.get("wax_pour",0));wax_cool=float(data.get("wax_cool",0))
	candle_lit=data.get("candle",false);spoon_filled=data.get("spoon",false);stamp_imprint=data.get("imprint",false)
	spoon_on_fire=data.get("spoon_on_fire",false)
	var image:=Image.new()
	if not str(data.get("preview","")).is_empty() and image.load_png_from_buffer(Marshalls.base64_to_raw(data.get("preview","")))==OK: letter_preview=ImageTexture.create_from_image(image)
	else: letter_preview=null
	mode={"WORKBENCH":Mode.DESK,"FOLDING":Mode.FOLDING,"ENVELOPE":Mode.ENVELOPE,"WAX_SEAL":Mode.WAX_SEALING,"END":Mode.SENT}.get(stage,Mode.DESK)
	papers.visible=mode==Mode.DESK
	tools_root.visible=mode==Mode.DESK
	build_ui()

func checkpoint() -> void:
	undo_stack.append(snapshot())
	if undo_stack.size()>20: undo_stack.pop_front()
	redo_stack.clear()

func undo() -> void:
	if undo_stack.is_empty() or busy or mode==Mode.TYPEWRITER: return
	redo_stack.append(snapshot())
	restore_snapshot(undo_stack.pop_back())
	say("撤回了上一步。")

func redo() -> void:
	if redo_stack.is_empty() or busy: return
	undo_stack.append(snapshot())
	restore_snapshot(redo_stack.pop_back())
	say("恢复了刚才那一步。")

func save_game() -> void:
	if not ready_done or smoke: return
	if not session_context.is_empty():
		if str(session_context.current_character)!=get_node("/root/GameState").current_role: return
		if not get_node("/root/GameState").artifacts.has("minigame_drafts"): get_node("/root/GameState").artifacts["minigame_drafts"]={}
		get_node("/root/GameState").artifacts.minigame_drafts["ghostwriting"]=snapshot()
		get_node("/root/GameState").commit_active_role_state()
		if not get_node("/root/SaveManager").save_game(): hint="草稿仍在桌上，但未能写入存档。请再试一次保存。"
	else:
		var file:=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
		if not file: return
		file.store_string(JSON.stringify(snapshot()))
		file.close()
		if DirAccess.rename_absolute(save_path+".tmp",save_path)!=OK: return
	if has_node("/root/FilmSystem"):
		for paper in papers.get_children():
			if not str(paper.photo_id).is_empty() and not bool(get_node("/root/FilmSystem").photo(paper.photo_id).get("used_in_collage",false)): get_node("/root/FilmSystem").mark_photo_use(paper.photo_id,"collage")

func load_game() -> void:
	if not session_context.is_empty():
		var draft: Dictionary=get_node("/root/GameState").artifacts.get("minigame_drafts",{}).get("ghostwriting",{})
		if draft.get("version",0)==3: restore_snapshot(draft)
		return
	if not FileAccess.file_exists(save_path): return
	var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if data is Dictionary and data.get("version",0)==3: restore_snapshot(data)

func show_drafts() -> void:
	save_game()
	if not session_context.is_empty() and not get_node("/root/SaveManager").save_or_report("草稿未能保存"): return
	say("当前草稿已保存。下次回到桌边，会继续这封信。")

func show_notes() -> void:
	notes_open=true;build_ui()

func show_settings() -> void:
	settings_open=true;build_ui()

func _build_note_panel() -> void:
	var shield:=ColorRect.new()
	shield.position=Vector2.ZERO;shield.size=SIZE;shield.color=Color(0.1,0.12,0.1,0.3)
	ui.add_child(shield)
	var panel:=Panel.new()
	panel.position=Vector2(475,220);panel.size=Vector2(650,420);panel.add_theme_stylebox_override("panel",_paper_style())
	ui.add_child(panel)
	if notes_open:
		_label("书信事务所的委托",Rect2(510,250,550,50),28)
		var text:="给很久没见的朋友写一封信。\n留一张旧车票，可以加上公交站的画面。\n别直说‘我想你’，也别写成告别。\n\n拖动纸片 · Q / E 旋转 · 滚轮缩放 · [ / ] 层级\n剪刀端点：Shift + 拖动；从圆点沿线剪\n刻刀需要刻板；胶带要用剪刀剪断。\n胶棒：选纸→翻面涂胶→翻回→摆放→压贴。\nCtrl+Z 撤销 · Ctrl+Y 重做 · Esc 放回工具"
		_label(text,Rect2(510,310,580,290),18)
	else:
		_label("桌边的声音",Rect2(515,265,520,60),28)
		_button("声音：关" if audio.muted else "声音：开",Rect2(530,365,225,48),func(): audio.toggle();build_ui())
		_button("保存草稿",Rect2(790,365,225,48),save_game)
		_button("手柄反馈："+["关闭","轻","中","强"][audio.haptic_level],Rect2(530,435,300,44),func(): audio.haptic_level=(audio.haptic_level+1)%4;build_ui())
	_button("收起",Rect2(945,568,130,43),func(): notes_open=false;settings_open=false;build_ui())

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST: save_game()

func flip_active() -> void:
	if not is_instance_valid(active) or active == main_paper or active.attached: return
	checkpoint()
	active.flipped=not active.flipped
	active.flip_fold=0.7
	active.queue_redraw()
	audio.play("PAPER_MOVE",0.45)
	return_desk()
	say("背面：拿胶棒按住涂抹。" if active.flipped else "正面：摆好位置，再压贴到信纸上。")

func press_active() -> void:
	if not is_instance_valid(active) or active == main_paper: return
	if active.attached:
		checkpoint();active.attached=false;active.glue_marks.clear();active._rebuild_glue_cells();active.back_dirty=true;active.queue_redraw()
		audio.play("TAPE_TEAR",0.4);say("纸片揭起来了。重新粘贴前需要再涂背胶。")
		return
	if active.flipped: say("先翻回正面再压贴。") ;return
	if not main_paper.contains_point(active.position): say("把纸片放到信纸上再压贴。") ;return
	if active.glue_coverage() < 0.12: say("背胶还不够，翻到背面多涂几道。") ;return
	checkpoint();active.attached=true;active.press_bounce=5.0;active.queue_redraw()
	audio.play("PAPER_PRESS",0.65);return_desk();say("压贴好了。纸片会留在信上；需要调整时可以揭起。")

func _build_material_rack() -> void:
	var titles := ["报纸","纸张","艺术册","乐谱","票据"]
	var cats := ["印刷","纸张","艺术册","乐谱","票据"]
	for i in 5:
		var category: String=cats[i]
		var index := 0
		for j in materials.size():
			if materials[j].category == category: index=j;break
		_button(titles[i],Rect2(33+i*149,474,137,34),func(): browser_category=category;browser_index=0;open_browser())
		var cover := _button("",Rect2(35+i*149,350,135,120),func(): browser_category=category;browser_index=0;open_browser())
		cover.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		cover.add_theme_stylebox_override("hover",StyleBoxEmpty.new())
		cover.add_theme_stylebox_override("pressed",StyleBoxEmpty.new())
		cover.tooltip_text=titles[i]
	_button("图案 / 花叶",Rect2(1395,352,165,34),func(): browser_category="图案";browser_index=0;open_browser())
	_button("纸张 / 印刷",Rect2(1395,420,165,34),func(): browser_category="纸张";browser_index=0;open_browser())
	_button("草稿",Rect2(1395,486,165,34),show_drafts)

var shelf_start := 0
func _build_shelf() -> void:
	_button("素材",Rect2(26,857,78,37),func(): browser_category="全部";open_browser())
	_button("〈",Rect2(279,857,44,37),func(): shelf_start=posmod(shelf_start-10,materials.size());build_ui())
	for i in 10:
		var id := posmod(shelf_start+i,materials.size())
		var tile := _button("",Rect2(337+i*88,851,78,48),func(): browser_category="全部";browser_index=id;take_material())
		var thumb: Image=material_images[id]
		if materials[id].kind=="decoration": thumb=thumb.get_region(thumb.get_used_rect())
		tile.icon=ImageTexture.create_from_image(thumb)
		tile.expand_icon=true
		tile.add_theme_constant_override("icon_max_width",38)
		tile.tooltip_text=materials[id].title
	_button("〉",Rect2(1230,857,44,37),func(): shelf_start=posmod(shelf_start+10,materials.size());build_ui())

func _draw_rack() -> void:
	if material_images.is_empty(): return
	draw_rect(Rect2(27,356,753,153),Color("b58d69"))
	var categories := ["印刷","纸张","艺术册","乐谱","票据"]
	for i in categories.size():
		for j in materials.size():
			if materials[j].category == categories[i]:
				var rect := Rect2(35+i*149,350+(i%2)*7,135,120)
				draw_rect(Rect2(rect.position+Vector2(5,-5),rect.size),Color("e6d4b6"))
				draw_texture_rect(material_textures[j],rect,false)
				break
		draw_rect(Rect2(28+i*149,462,150,49),Color("b58d69"))

func _append_developed_photos() -> void:
	if not has_node("/root/FilmSystem"): return
	for photo in get_node("/root/FilmSystem").developed_photos():
		var library = load("res://scripts/town_sound/data/PhotoLibrary.gd").new(); library.root_path=str(photo.get("library_root","user://photos"))
		var id := str(photo.get("id",photo.get("photo_id","")))
		var image: Image = library.load_photo(id)
		if image==null: continue
		var copy := image.duplicate() as Image
		copy.convert(Image.FORMAT_RGBA8)
		var fit := minf(280.0/copy.get_width(),190.0/copy.get_height())
		copy.resize(roundi(copy.get_width()*fit),roundi(copy.get_height()*fit),Image.INTERPOLATE_LANCZOS)
		var print_image := Image.create(300,240,false,Image.FORMAT_RGBA8); print_image.fill(Color("faf7ee"))
		print_image.blit_rect(copy,Rect2i(Vector2i.ZERO,copy.get_size()),Vector2i((300-copy.get_width())/2,12))
		materials.append({"id":"photo_"+id,"photo_id":id,"title":str(photo.get("title","自己的照片")),"category":"影像","paper_type":"影像","kind":"photo"})
		material_images.append(print_image)
		material_textures.append(ImageTexture.create_from_image(print_image))

func _localized(value: String) -> String:
	var localization=get_node_or_null("/root/LocalizationSystem")
	return localization.text(value) if localization else value
