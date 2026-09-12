extends Node2D

const PaperArt = preload("res://scripts/paper_art.gd")
const Piece = preload("res://scripts/collage_piece.gd")
const BottleClient = preload("res://scripts/bottle_client.gd")
const BottleDock = preload("res://scripts/bottle_dock.gd")
const Audio = preload("res://scripts/audio_manager.gd")
const INK = Color("354a43")
const RUST = Color("a85740")
const LETTER = Rect2(455,174,530,582)
var save_path := "user://letter_v1.json"
var font: SystemFont
var audio: Node
var ui: CanvasLayer
var pieces_root: Node2D
var textures: Array[Texture2D] = []
var sources := [Rect2(62,190,300,240),Rect2(70,450,300,240),Rect2(74,450,300,240),Rect2(1074,482,300,240),Rect2(1070,196,300,240)]
var stage := "DIALOGUE"
var dialogue := 0
var tool := "move"
var selected: Node2D
var dragging := false
var drag_offset := Vector2.ZERO
var start := Vector2.ZERO
var path := PackedVector2Array()
var cutting_source := -1
var secondary := 1
var last_sound := Vector2.ZERO
var hint := ""
var fold := 0
var envelope_inserted := false
var wax_step := 0
var wax_progress := 0.0
var seal_style := 0
var seal_points := PackedVector2Array()
var stage_drag := ""
var stage_pos := Vector2(700,310)
var stamp_holding := false
var elapsed := 0.0
var save_clock := 0.0
var entry: LineEdit
var tape_start := Vector2.ZERO
var tape_drawing := false
var letter_preview: ImageTexture
var preview_path := "user://letter_preview.png"
var status_label: Label
var phase_label: Label
var help_open := false
var ready_done := false
var final_feedback := ""
var smoke := false
var busy := false
var fold_visual := 0.0
var insert_visual := 0.0
var flap_visual := 0.0
var pour_visual := 1.0
var mail_visual := 0.0
var stamp_lift := 0.0
var materials: Array = []
var category := "全部"
var material_page := 0
var primary := 0
var album_source := 4
var bottle: Node
var dock_open := false
var letter_mode := "npc"
var reply_parent: Dictionary = {}
var letter_title := "一封来自海边的信"
var bottle_request_id := ""
var bottle_published_id := 0
var compose_server := ""
var title_entry: LineEdit

func _ready() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("This visual game needs a rendering display. Run --smoke-test without --headless; editor import can use --headless.")
		get_tree().quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			var profile:=arg.trim_prefix("--profile=").validate_filename()
			save_path="user://letter_"+profile+".json"
			preview_path="user://preview_"+profile+".png"
	materials=JSON.parse_string(FileAccess.get_file_as_string("res://assets/materials.json"))
	bottle=BottleClient.new()
	add_child(bottle)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC","PingFang SC","sans-serif"])
	font.allow_system_fallback = true
	audio = Audio.new()
	add_child(audio)
	pieces_root = Node2D.new()
	add_child(pieces_root)
	ui = CanvasLayer.new()
	add_child(ui)
	for i in materials.size():
		var viewport := SubViewport.new()
		viewport.size = Vector2i(300,240)
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var art := PaperArt.new()
		art.kind = i
		art.sheet_data = materials[i]
		art.font = font
		viewport.add_child(art)
		textures.append(viewport.get_texture())
		if i>=sources.size():
			sources.append(Rect2(62,190,300,240))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	load_game()
	update_material_slots()
	fold_visual = float(fold)
	flap_visual = 1.0 if stage in ["WAX_SEAL","SEND","END"] else 0.0
	build_ui()
	ready_done = true
	queue_redraw()
	if "--smoke-test" in OS.get_cmdline_user_args():
		smoke = true
		run_smoke_test()
	if "--network-test" in OS.get_cmdline_user_args():
		smoke=true
		run_network_test()
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png("res://preview.png")
	if "--open-dock" in OS.get_cmdline_user_args():
		open_bottles()

func label_at(text: String, rect: Rect2, size: int = 18, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font",font)
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	ui.add_child(node)
	return node

func button(text: String, rect: Rect2, action: Callable, active: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font",font)
	node.add_theme_font_size_override("font_size",17)
	node.add_theme_color_override("font_color",Color("faf3df") if active else INK)
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (RUST if active else Color("ece5d2")) if state == "normal" else Color("cbb89a")
		style.corner_radius_top_left = 5
		style.corner_radius_top_right = 5
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 5
		style.border_color = Color("b7aa90")
		style.set_border_width_all(1)
		node.add_theme_stylebox_override(state,style)
	node.pressed.connect(action)
	ui.add_child(node)
	return node

func build_ui() -> void:
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	label_at("海盐书信事务所",Rect2(54,27,600,42),30)
	label_at("COLLAGE LETTER   /   把捡到的语言，寄给某个人",Rect2(56,73,700,30),14)
	button("声音" if not audio.muted else "静音",Rect2(1220,39,70,34),func(): audio.toggle(); build_ui())
	button("操作说明",Rect2(1300,39,94,34),func(): help_open = not help_open; build_ui())
	phase_label = label_at(phase_title(),Rect2(760,39,440,34),18,RUST)
	status_label = label_at(hint,Rect2(58,851,1320,30),16)
	if stage in ["DIALOGUE","WORKBENCH","END"]:
		button("海边 · 漂流瓶邮局",Rect2(1190,78,204,30),open_bottles)
	if stage == "WORKBENCH":
		var names := ["移动","刻刀 · 方框","刻刀 · 自由","胶带","手写"]
		var ids := ["move","rect","free","tape","pen"]
		for i in names.size():
			var id: String = ids[i]
			button(names[i],Rect2(290+i*170,790,158,42),func(): set_tool(id),tool==id)
		button("完成这封信  →",Rect2(1158,790,220,42),complete_letter,true)
		var category_picker:=OptionButton.new()
		category_picker.position=Vector2(62,118)
		category_picker.size=Vector2(300,31)
		category_picker.add_theme_font_override("font",font)
		var categories: Array=["全部","日常","路途","自然","心绪","连接"]
		for item in categories:
			category_picker.add_item(item+" / 素材夹")
		category_picker.select(maxi(0,categories.find(category)))
		category_picker.item_selected.connect(func(index): category=categories[index]; material_page=0; update_material_slots(); build_ui())
		ui.add_child(category_picker)
		button("← 上一组",Rect2(62,708,140,34),func(): material_page-=1; update_material_slots(); build_ui())
		button("下一组 →",Rect2(220,708,140,34),func(): material_page+=1; update_material_slots(); build_ui())
		button("换张照片 →",Rect2(1220,445,152,30),cycle_photo)
		label_at("纸张 %02d / %02d · %s" % [material_page+1,maxi(1,ceili(material_ids().size()/2.0)),materials[primary].title],Rect2(62,151,340,28),15)
		label_at("相册 / "+str(materials[album_source].title),Rect2(1070,151,325,28),16)
		label_at("旧车票 / 私人素材",Rect2(1072,450,180,28),14)
		label_at("TO / "+("很久没见的朋友" if letter_mode=="npc" else ("海上的某个人" if letter_mode=="bottle" else "回复 #"+str(reply_parent.get("id",0)))),Rect2(483,184,480,30),14,Color("9a9787"))
		if tool == "pen":
			entry = LineEdit.new()
			entry.position = Vector2(481,716)
			entry.size = Vector2(345,36)
			entry.placeholder_text = "写一小段自己的话…"
			entry.max_length = 40
			entry.add_theme_font_override("font",font)
			ui.add_child(entry)
			button("落笔",Rect2(842,716,110,36),add_handwriting)
		if selected and is_instance_valid(selected):
			button("翻转",Rect2(460,122,78,32),func(): selected.scale.x *= -1; changed())
			button("置顶",Rect2(547,122,78,32),func(): pieces_root.move_child(selected,pieces_root.get_child_count()-1); changed())
			button("置底",Rect2(634,122,78,32),func(): pieces_root.move_child(selected,0); changed())
			button("移除",Rect2(721,122,78,32),delete_selected)
	elif stage == "DIALOGUE":
		var lines := ["她以前总在旧公交站等我。\n后来她搬走了，我们很多年没有见面。","我不想在信里直接写「我想你」。\n也别写得像告别。","如果你愿意，把这张旧车票放进去吧。\n她应该还记得，夏天的最后一班车。"]
		label_at("林舟  /  住在旧街的客人",Rect2(585,302,660,40),22,RUST)
		label_at(lines[dialogue],Rect2(585,369,700,120),25)
		if dialogue < 2:
			button("我在听。",Rect2(590,555,230,49),advance_dialogue,true)
			button("说说那个公交站吧。",Rect2(846,555,300,49),advance_dialogue)
		else:
			button("收下车票，开始写信  →",Rect2(590,555,450,49),advance_dialogue,true)
		label_at("第一封委托    /    夏季，仍然",Rect2(585,651,650,30),17)
	elif stage == "FOLDING":
		label_at("保留那些恰好的空白。",Rect2(515,147,700,50),26)
	elif stage == "ENVELOPE":
		if envelope_inserted:
			button("合上信封翻盖",Rect2(570,726,300,48),close_envelope,true)
	elif stage == "WAX_SEAL":
		for i in 3:
			var index := i
			button(["海鸟","柠檬枝","星星"][i],Rect2(985+i*125,682,112,38),func(): seal_style = index; changed(),seal_style==i)
	elif stage == "SEND":
		if letter_mode!="npc":
			label_at("给漂流瓶写一个标题",Rect2(490,241,460,28),17)
			title_entry=LineEdit.new()
			title_entry.position=Vector2(490,280)
			title_entry.size=Vector2(460,43)
			title_entry.max_length=40
			title_entry.text=letter_title
			title_entry.editable=bottle_request_id.is_empty()
			title_entry.add_theme_font_override("font",font)
			title_entry.text_changed.connect(func(value): letter_title=value; save_game())
			ui.add_child(title_entry)
		button("寄出这封信  →",Rect2(570,726,300,50),send_letter,true)
	elif stage == "END":
		label_at("信已经出发。",Rect2(540,262,700,55),36)
		label_at(final_feedback,Rect2(540,350,800,140),23)
		label_at("没有评分。你留下的排列、图像和空白，就是这封信。",Rect2(540,543,800,40),18)
		button("再写一封" if letter_mode=="npc" else "去海边读信 / 回信",Rect2(550,626,230,46),restart if letter_mode=="npc" else open_bottles,true)
		button("导出作品 PNG",Rect2(790,626,220,46),export_art)
	if help_open:
		var panel := ColorRect.new()
		panel.position = Vector2(350,192)
		panel.size = Vector2(740,510)
		panel.color = Color("f6efdb")
		ui.add_child(panel)
		label_at("桌边操作指南",Rect2(392,216,650,44),28)
		label_at("① 刻刀：在纸张上拖方框，或按住划出自由轮廓。\n② 移动：把裁下的纸片摆上信纸，松手就放好。\n③ 胶带：沿纸片边缘拖出一条装饰胶带。\n④ 素材夹：按主题换页，相册也能切换照片。\n⑤ 漂流瓶：自由发信、读旧信、回复其他寄信人。\n\n滚轮缩放 · Q / E 旋转 · Delete 删除 · 右键返回移动\n发出新漂流瓶后，需要回复一封来信，才能再发新信。\n自动保存作品和回信对象；发信失败可以原样重试。",Rect2(392,287,670,340),20)
		button("回到桌边",Rect2(804,630,230,43),func(): help_open=false; build_ui(),true)
	queue_redraw()

func phase_title() -> String:
	return {"DIALOGUE":"01  /  听一段往事","WORKBENCH":"02  /  捡到语言，重新排列","FOLDING":"03  /  折好这一页","ENVELOPE":"04  /  装进信封","WAX_SEAL":"05  /  留下一枚火漆","SEND":"06  /  寄向远方","END":"07  /  夏季，仍然"}.get(stage,"")

func say(text: String) -> void:
	hint = text
	if is_instance_valid(status_label):
		status_label.text = hint

func _draw() -> void:
	if not font:
		return
	draw_rect(Rect2(0,0,1440,900),Color("cec2a8"))
	draw_rect(Rect2(0,0,1440,114),Color("e9e2d2"))
	draw_line(Vector2(50,113),Vector2(1390,113),Color("b6ab92"),1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 18
	for i in 750:
		var p := Vector2(rng.randf_range(0,1440),rng.randf_range(115,900))
		draw_line(p,p+Vector2(rng.randf_range(3,15),1),Color(0.34,0.29,0.22,0.045))
	draw_rect(Rect2(0,838,1440,62),Color("e9e2d2"))
	if stage == "WORKBENCH":
		paper(LETTER,Color("faf6e9"))
		for i in [primary,secondary,3,album_source]:
			paper(sources[i],Color("ede6d4"))
			if textures.size()>i:
				draw_texture_rect(textures[i],sources[i],false)
		if cutting_source >= 0 and path.size()>1:
			if tool == "rect":
				draw_rect(Rect2(start,get_global_mouse_position()-start).abs(),Color(0.65,0.29,0.20,0.13))
				draw_rect(Rect2(start,get_global_mouse_position()-start).abs(),RUST,false,2)
			else:
				draw_polyline(path,RUST,2,true)
		if tape_drawing:
			draw_line(tape_start,get_global_mouse_position(),Color(0.77,0.67,0.43,0.6),22,true)
		if tool in ["rect","free"]:
			var tip:=get_global_mouse_position()
			draw_line(tip+Vector2(7,-9),tip+Vector2(27,-40),Color("735e4c"),8,true)
			draw_colored_polygon(PackedVector2Array([tip,tip+Vector2(5,-20),tip+Vector2(12,-12)]),Color("e5e9db"))
	elif stage == "DIALOGUE":
		paper(Rect2(506,234,805,475),Color("f4eddb"))
		draw_circle(Vector2(293,349),76,Color("b77758"))
		draw_circle(Vector2(293,339),61,Color("dec4a1"))
		draw_colored_polygon(PackedVector2Array([Vector2(221,344),Vector2(224,291),Vector2(266,263),Vector2(323,270),Vector2(362,312),Vector2(350,346),Vector2(329,312),Vector2(287,305),Vector2(251,327)]),Color("4e5144"))
		draw_colored_polygon(PackedVector2Array([Vector2(231,424),Vector2(347,422),Vector2(406,652),Vector2(183,652)]),Color("718474"))
		draw_line(Vector2(282,377),Vector2(307,378),Color("9d674e"),2)
		for x in [271,316]:
			draw_circle(Vector2(x,350),2.5,INK)
		draw_set_transform(Vector2(277,559),-0.18,Vector2(0.52,0.52))
		if textures.size()>3:
			draw_texture(textures[3],Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
	elif stage == "FOLDING":
		var rect := Rect2(520,227,400,480)
		rect.size.y -= minf(fold_visual,1.0)*160
		if fold_visual > 1:
			rect.position.y += (fold_visual-1)*160
			rect.size.y -= (fold_visual-1)*160
		paper(rect,Color("f7f0df"))
		if letter_preview and fold_visual < 0.01:
			draw_texture_rect(letter_preview,rect,false)
		elif letter_preview and fold_visual < 1:
			draw_texture_rect_region(letter_preview,Rect2(520,227,400,320),Rect2(Vector2.ZERO,Vector2(letter_preview.get_size())*Vector2(1,0.6667)))
			paper(Rect2(520,547-minf(fold_visual,1)*160,400,160*minf(fold_visual,1)),Color("eee5d0"))
		if fold < 2:
			var y := 547 if fold == 0 else 387
			for x in range(530,910,18):
				draw_line(Vector2(x,y),Vector2(x+9,y),Color("9d967e"),1)
			text_at("↑ 将下沿向上拖动" if fold==0 else "↓ 将上沿向下拖动",Vector2(582,742),22)
		else:
			text_at("按一下，压平最后的折痕",Vector2(552,625),22)
	elif stage in ["ENVELOPE","WAX_SEAL","SEND"]:
		draw_set_transform(Vector2(mail_visual*360,-mail_visual*160),mail_visual*0.12,Vector2.ONE*(1-mail_visual*0.22))
		draw_envelope()
		if stage == "ENVELOPE" and (not envelope_inserted or insert_visual>0):
			var letter_rect := Rect2(stage_pos-Vector2(150,65),Vector2(300,130))
			if insert_visual>0:
				letter_rect = Rect2(570,350+insert_visual*90,300,130*(1-insert_visual))
			paper(letter_rect,Color("f8f1df"))
			draw_line(letter_rect.position+Vector2(10,20),letter_rect.position+Vector2(290,20),Color("d4c9b1"),1)
			text_at("将折好的信拖进下方信封",Vector2(552,181),23)
		if stage == "WAX_SEAL":
			draw_wax_tools()
		if (wax_step >= 4 or stage == "SEND") and seal_points.size()>=3:
			draw_set_transform(Vector2(720,474)+Vector2(mail_visual*360,-mail_visual*160),mail_visual*0.12,Vector2.ONE*maxf(0.01,pour_visual)*(1.0+0.06*sin(minf(wax_progress,1)*PI)))
			draw_colored_polygon(seal_points,Color("a74736") if wax_step<6 else Color("943f32"))
			if wax_step < 6:
				draw_arc(Vector2(-2,-3),23,3.4,5.8,20,Color(0.98,0.63,0.38,0.55),3,true)
			if wax_step >= 6 or stage == "SEND":
				draw_arc(Vector2.ZERO,23,0,TAU,50,Color("c77954"),1.6,true)
				draw_seal(seal_style)
			draw_set_transform(Vector2.ZERO)
		draw_set_transform(Vector2.ZERO)
		if stage == "WAX_SEAL" and wax_step==4 and pour_visual<1:
			draw_line(Vector2(709,390),Vector2(720,474),Color("b05b3e"),3+pour_visual*2,true)
		if stage == "SEND":
			text_at("蜡已经凉了。可以出发了。",Vector2(539,208),25)
	elif stage == "END":
		paper(Rect2(490,222,850,497),Color("f5edda"))
		paper(Rect2(94,260,326,390),Color("f7efdf"))
		if letter_preview:
			draw_texture_rect(letter_preview,Rect2(104,270,306,370),false)

func text_at(text: String, at: Vector2, size: int = 20, color: Color = INK) -> void:
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func paper(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(rect.position+Vector2(5,7),rect.size),Color(0.27,0.23,0.17,0.12))
	draw_rect(rect,color)
	draw_line(rect.position+Vector2(2,2),Vector2(rect.position.x+2,rect.end.y-2),Color(1,1,1,0.3),2)

func draw_envelope() -> void:
	var rect := Rect2(490,390,460,255)
	if stage == "SEND":
		rect.position.y += sin(elapsed)*2
	paper(rect,Color("dcc69f"))
	draw_line(Vector2(492,640),Vector2(720,476),Color("b59e78"),1.5)
	draw_line(Vector2(948,640),Vector2(720,476),Color("b59e78"),1.5)
	var tip := Vector2(720,lerpf(267,484,flap_visual))
	draw_colored_polygon(PackedVector2Array([Vector2(490,390),Vector2(950,390),tip]),Color("e6d2af"))
	draw_polyline(PackedVector2Array([Vector2(490,390),tip,Vector2(950,390)]),Color("b49e7d"),1.5,true)
	text_at("给  /  很久没见的朋友",Vector2(543,589),19,Color("776c57"))

func draw_wax_tools() -> void:
	text_at(["点一下火柴，点亮蜡烛。","把蜡粒拖进金属小勺。","把小勺拖到烛火上，等待蜡融化。","将小勺拖到信封封口，缓缓倒下。","将印章拖到火漆上。","按住火漆 1 秒，再松开印章。","火漆正在冷却……"][mini(wax_step,6)],Vector2(401,173),22)
	draw_rect(Rect2(133,489,54,110),Color("f2e3b7"))
	draw_ellipse_custom(Vector2(160,489),Vector2(27,8),Color("fff0c8"))
	draw_line(Vector2(160,489),Vector2(160,474),INK,2)
	if wax_step > 0:
		draw_ellipse_custom(Vector2(160,454+sin(elapsed*8)*2),Vector2(9,22),Color("dc9c42"))
		draw_ellipse_custom(Vector2(160,461),Vector2(4,12),Color("fff0a3"))
	draw_line(Vector2(99,653),Vector2(197,623),Color("e7d8bb"),5)
	draw_circle(Vector2(197,623),5,RUST)
	text_at("火柴 / 蜡烛",Vector2(108,693),17)
	for i in 6:
		var p := Vector2(289+(i%3)*19,556+(i/3)*19)
		if stage_drag == "pellets":
			p += get_global_mouse_position()-Vector2(310,570)
		draw_circle(p,8,Color("a34f3c"))
	text_at("蜡粒",Vector2(285,632),17)
	var spoon := Vector2(328,371)
	if stage_drag == "spoon":
		spoon = get_global_mouse_position()
	elif wax_step == 2 and wax_progress > 0:
		spoon = Vector2(160,420)
	draw_line(spoon+Vector2(10,0),spoon+Vector2(97,-36),Color("766e5f"),9,true)
	draw_ellipse_custom(spoon,Vector2(32,19),Color("a7a18b"))
	draw_ellipse_custom(spoon+Vector2(0,-3),Vector2(26,13),Color("746f60"))
	if wax_step in [2,3]:
		draw_ellipse_custom(spoon+Vector2(0,-3),Vector2(21,10),Color("aa4d39"))
		if wax_progress < 1:
			for i in 3:
				draw_circle(spoon+Vector2(-12+i*11,-4),5*(1-wax_progress),Color("c17456"))
	text_at("金属小勺",Vector2(283,320),17)
	var stamp := Vector2(1170,460)
	if stage_drag == "stamp":
		stamp = get_global_mouse_position()
	elif wax_step == 5:
		stamp = Vector2(720,458+4*minf(wax_progress,1))
	elif wax_step == 6 and stamp_lift<1:
		stamp = Vector2(720,458-stamp_lift*120)
	draw_rect(Rect2(stamp-Vector2(31,0),Vector2(62,18)),Color("9c8961"))
	draw_rect(Rect2(stamp-Vector2(12,69),Vector2(24,73)),Color("795443"))
	draw_circle(stamp-Vector2(0,74),23,Color("865c45"))
	text_at("火漆印章",Vector2(1112,535),20)
	if wax_step in [2,5,6]:
		draw_rect(Rect2(527,712,386,5),Color("b4aa90"))
		draw_rect(Rect2(527,712,386*minf(wax_progress,1),5),RUST)

func draw_ellipse_custom(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 40:
		points.append(center+Vector2(cos(i*TAU/40),sin(i*TAU/40))*radius)
	draw_colored_polygon(points,color)

func draw_seal(style: int) -> void:
	var color := Color("d69569")
	match style:
		0:
			draw_polyline(PackedVector2Array([Vector2(-17,1),Vector2(-8,-7),Vector2(0,1),Vector2(8,-7),Vector2(17,1)]),color,2.4,true)
		1:
			draw_line(Vector2(-9,14),Vector2(8,-14),color,2,true)
			for p in [Vector2(-3,3),Vector2(3,-5)]:
				draw_arc(p+Vector2(4,0),5,PI,TAU,14,color,2,true)
				draw_arc(p-Vector2(4,2),5,0,PI,14,color,2,true)
		2:
			var star := PackedVector2Array()
			for i in 11:
				var a := i*TAU/10-PI/2
				star.append(Vector2(cos(a),sin(a))*(15 if i%2==0 else 6))
			draw_polyline(star,color,2,true)

func advance_dialogue() -> void:
	audio.play("DIALOGUE_ADVANCE")
	if dialogue < 2:
		dialogue += 1
	else:
		stage = "WORKBENCH"
		say("先拿起刻刀，在报纸上框住一段字；也可以从右侧的照片裁一小片夕阳。")
	changed()
	build_ui()

func set_tool(value: String) -> void:
	tool = value
	dragging = false
	cutting_source = -1
	tape_drawing = false
	say({"move":"拖动纸片，松手放好。Q / E 旋转，滚轮缩放，随时重新排列。","rect":"刻刀方框裁切：在纸张上按住左键拖动，松开切下。","free":"刻刀自由裁切：按住左键沿边缘划一圈，松开闭合。","tape":"按住左键拉出胶带，松开截断；胶带可以重新摆放。","pen":"输入自己的话，再点落笔。中文最多 20 字，英文最多 40 字符。"}[tool])
	build_ui()

func pick(point: Vector2) -> Node2D:
	var children := pieces_root.get_children()
	children.reverse()
	for piece in children:
		if piece.hit(point):
			return piece
	return null

func select(piece: Node2D) -> void:
	if selected and is_instance_valid(selected):
		selected.selected = false
		selected.queue_redraw()
	selected = piece
	if selected:
		selected.selected = true
		selected.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not ready_done or help_open or busy or dock_open:
		return
	var mouse := get_global_mouse_position()
	if event is InputEventKey and event.pressed and stage == "WORKBENCH":
		if selected and is_instance_valid(selected):
			match event.keycode:
				KEY_Q: selected.rotation -= 0.075; changed()
				KEY_E: selected.rotation += 0.075; changed()
				KEY_DELETE: delete_selected()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and stage == "WORKBENCH":
			set_tool("move")
			return
		if stage == "WORKBENCH" and selected and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 1.07 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.07
			if absf(selected.scale.x*factor) >= 0.25 and absf(selected.scale.x*factor) <= 3.0:
				selected.scale *= factor
				changed()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if stage != "WORKBENCH":
			stage_input(mouse,event.pressed)
			return
		if event.pressed:
			start = mouse
			last_sound = mouse
			if tool in ["rect","free"]:
				for i in [album_source,3,secondary,primary]:
					if sources[i].has_point(mouse):
						cutting_source = i
						path = PackedVector2Array([mouse])
						audio.play("KNIFE_SLICE")
						break
			elif tool == "tape":
				tape_start = mouse
				tape_drawing = true
				audio.play("TAPE_PULL")
			elif tool == "move":
				select(pick(mouse))
				if selected:
					dragging = true
					drag_offset = selected.position-mouse
					audio.play("PAPER_MOVE")
				build_ui()
		else:
			if cutting_source >= 0:
				finish_cut(mouse)
			if tape_drawing:
				finish_tape(mouse)
			if dragging:
				audio.play("PHOTO_DROP" if selected.source_id==4 else "PAPER_PRESS")
			dragging = false
			changed()
	elif event is InputEventMouseMotion:
		if stage == "WORKBENCH":
			if dragging and selected:
				selected.position = mouse+drag_offset
				selected.position = selected.position.clamp(Vector2(25,130),Vector2(1415,770))
			if cutting_source >= 0:
				var bound: Rect2 = sources[cutting_source]
				var clamped := mouse.clamp(bound.position+Vector2(1,1),bound.end-Vector2(1,1))
				if path[-1].distance_to(clamped)>4:
					path.append(clamped)
			if mouse.distance_to(last_sound)>30:
				if cutting_source>=0:
					audio.play("KNIFE_SLICE",0.65)
				last_sound = mouse
		elif stage == "ENVELOPE" and stage_drag == "letter":
			stage_pos = mouse
	queue_redraw()

func roughen(poly: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i+1)%poly.size()]
		var length := a.distance_to(b)
		var steps := maxi(1,int(length/10))
		var normal := (b-a).normalized().orthogonal()
		for j in steps:
			result.append(a.lerp(b,float(j)/steps)+normal*randf_range(-1.5,1.5))
	if Geometry2D.triangulate_polygon(result).is_empty():
		return poly
	return result

func finish_cut(mouse: Vector2) -> void:
	var source := cutting_source
	cutting_source = -1
	var bound: Rect2 = sources[source]
	var poly := PackedVector2Array()
	if tool == "rect":
		var box := Rect2(start,mouse-start).abs().intersection(bound)
		if box.size.x < 14 or box.size.y < 14:
			say("切口太小了，试着圈住更大一点的纸。")
			return
		poly = PackedVector2Array([box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)])
	else:
		poly = path.duplicate()
		if poly.size()<5 or Geometry2D.triangulate_polygon(poly).is_empty():
			say("这条轮廓没有形成可裁区域。请画一圈不交叉的轮廓。")
			return
	var center := Vector2.ZERO
	for point in poly:
		center += point
	center /= poly.size()
	var piece := Piece.new()
	piece.source_id = source
	piece.font = font
	piece.texture = textures[source]
	for point in roughen(poly):
		piece.polygon.append(point-center)
		piece.uv.append((point-bound.position).clamp(Vector2.ZERO,Vector2(300,240))/Vector2(300,240))
	piece.position = Vector2(680+randf_range(-80,80),430+randf_range(-70,70))
	piece.rotation = randf_range(-0.04,0.04)
	pieces_root.add_child(piece)
	select(piece)
	audio.play("PAPER_CUT")
	set_tool("move")
	say("裁下来了。拖到喜欢的位置，松手就放好；随时可以重新排列。")
	changed()

func finish_tape(mouse: Vector2) -> void:
	tape_drawing = false
	if mouse.distance_to(tape_start)<16:
		return
	var length := minf(mouse.distance_to(tape_start),500)
	var piece := Piece.new()
	piece.source_id = -2
	piece.font = font
	piece.polygon = roughen(PackedVector2Array([Vector2(-length/2,-11),Vector2(length/2,-11),Vector2(length/2,11),Vector2(-length/2,11)]))
	piece.position = (tape_start+mouse)/2
	piece.rotation = (mouse-tape_start).angle()
	piece.is_taped = true
	pieces_root.add_child(piece)
	for other in pieces_root.get_children():
		if other == piece:
			continue
		for i in 20:
			if other.hit(tape_start.lerp(mouse,float(i)/19)):
				other.is_taped = true
				break
	select(piece)
	audio.play("TAPE_TEAR")
	get_tree().create_timer(0.16).timeout.connect(func(): audio.play("TAPE_STICK"))
	set_tool("move")
	say("胶带贴好了。选中它后可旋转或用滚轮改变大小。")

func add_handwriting() -> void:
	var value := entry.text.strip_edges()
	if value.is_empty():
		return
	var chinese := false
	for character in value:
		if character.unicode_at(0)>127:
			chinese = true
	if chinese and value.length()>20:
		say("这一小段最多 20 个字，留一些空白给纸片吧。")
		return
	var piece := Piece.new()
	piece.font = font
	piece.source_id = -1
	piece.handwriting = value
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x+22
	piece.polygon = roughen(PackedVector2Array([Vector2(-width/2,-22),Vector2(width/2,-22),Vector2(width/2,22),Vector2(-width/2,22)]))
	piece.position = Vector2(720,510)
	pieces_root.add_child(piece)
	select(piece)
	set_tool("move")
	audio.play("PAPER_MOVE")
	changed()

func delete_selected() -> void:
	if selected and is_instance_valid(selected):
		pieces_root.remove_child(selected)
		selected.queue_free()
		selected = null
		changed()
		build_ui()

func _process(delta: float) -> void:
	if not ready_done:
		return
	elapsed += delta
	save_clock += delta
	if save_clock > 3:
		save_clock = 0
		save_game()
	if stage == "WAX_SEAL":
		if wax_step == 2 and wax_progress>0 and stage_drag.is_empty():
			wax_progress += delta/3.0
			if wax_progress>=1:
				wax_step = 3
				wax_progress = 0
				changed()
		elif wax_step == 5 and stamp_holding:
			wax_progress += delta
		elif wax_step == 6:
			wax_progress += delta/1.6
			if wax_progress>=1:
				stage = "SEND"
				changed()
				build_ui()
	queue_redraw()

func complete_letter() -> void:
	if busy or stage!="WORKBENCH":
		return
	var count := 0
	for piece in pieces_root.get_children():
		if LETTER.has_point(piece.position):
			count += 1
	if count == 0:
		say("信纸还空着。先裁下一块纸或留下一小段文字吧。")
		return
	select(null)
	busy=true
	tool = "move"
	build_ui()
	await RenderingServer.frame_post_draw
	var viewport_image := get_viewport().get_texture().get_image()
	var ratio := Vector2(viewport_image.get_size())/Vector2(1440,900)
	var crop := Rect2i(LETTER.position*ratio,LETTER.size*ratio)
	var image := viewport_image.get_region(crop)
	if not smoke:
		image.save_png(preview_path)
	letter_preview = ImageTexture.create_from_image(image)
	stage = "FOLDING"
	fold = 0
	fold_visual = 0
	pieces_root.visible = false
	say("用鼠标参与折叠：先把下半部向上拖，再把上半部向下拖。")
	changed()
	busy=false
	build_ui()

func stage_input(mouse: Vector2, down: bool) -> void:
	if busy:
		return
	if down:
		start = mouse
	match stage:
		"FOLDING":
			if not down:
				if fold==0 and Rect2(520,547,400,160).has_point(start) and mouse.y<start.y-65:
					fold=1
					audio.play("PAPER_FOLD")
					animate_property("fold_visual",1.0,0.45)
				elif fold==1 and Rect2(520,227,400,160).has_point(start) and mouse.y>start.y+65:
					fold=2
					audio.play("PAPER_FOLD")
					animate_property("fold_visual",2.0,0.45)
				elif fold==2 and Rect2(520,387,400,160).has_point(mouse):
					stage="ENVELOPE"
					stage_pos=Vector2(720,285)
					audio.play("PAPER_PRESS")
					build_ui()
				changed()
		"ENVELOPE":
			if down and not envelope_inserted and Rect2(stage_pos-Vector2(150,65),Vector2(300,130)).has_point(mouse):
				stage_drag="letter"
			elif not down and stage_drag=="letter":
				stage_drag=""
				if Rect2(490,365,460,285).has_point(mouse):
					envelope_inserted=true
					insert_visual=0.001
					animate_property("insert_visual",1.0,0.65,func(): insert_visual=0; build_ui())
					audio.play("ENVELOPE_INSERT")
					say("信纸已装入。合上翻盖，就可以准备火漆了。")
					changed()
					build_ui()
		"WAX_SEAL":
			wax_input(mouse,down)

func close_envelope() -> void:
	if busy:
		return
	await animate_property("flap_visual",1.0,0.5)
	stage = "WAX_SEAL"
	wax_step = 0
	wax_progress = 0
	generate_seal()
	audio.play("ENVELOPE_CLOSE")
	say("火柴 → 蜡粒入勺 → 勺子移到火焰上 → 倒蜡 → 放下印章 → 按住，再松开。")
	changed()
	build_ui()

func wax_input(mouse: Vector2, down: bool) -> void:
	if busy:
		return
	if down:
		if wax_step==0 and Rect2(86,424,127,243).has_point(mouse):
			wax_step=1
			audio.play("MATCH_STRIKE")
		elif wax_step==1 and Rect2(268,538,86,69).has_point(mouse):
			stage_drag="pellets"
		elif wax_step in [2,3] and (mouse.distance_to(Vector2(328,371))<75 or (wax_progress>0 and mouse.distance_to(Vector2(160,420))<60)):
			stage_drag="spoon"
		elif wax_step==4 and Rect2(1118,354,107,142).has_point(mouse):
			stage_drag="stamp"
		elif wax_step==5 and mouse.distance_to(Vector2(720,474))<64:
			stamp_holding=true
			wax_progress=0
			audio.play("STAMP_PRESS")
	else:
		if stage_drag=="pellets" and mouse.distance_to(Vector2(328,371))<75:
			wax_step=2
			audio.play("PAPER_PRESS")
		elif stage_drag=="spoon":
			if wax_step==2 and mouse.distance_to(Vector2(160,432))<85:
				wax_progress=0.001
				audio.play("FIRE_LOOP")
			elif wax_step==3 and mouse.distance_to(Vector2(720,474))<85:
				wax_step=4
				wax_progress=0
				pour_visual=0.01
				animate_property("pour_visual",1.0,0.8)
				audio.play("WAX_POUR")
		elif stage_drag=="stamp" and mouse.distance_to(Vector2(720,474))<75:
			wax_step=5
			wax_progress=0
		elif stamp_holding:
			stamp_holding=false
			if wax_progress>=1:
				wax_step=6
				wax_progress=0
				stamp_lift=0
				create_tween().tween_property(self,"stamp_lift",1.0,0.6).set_trans(Tween.TRANS_SINE)
				audio.play("STAMP_RELEASE")
			else:
				wax_progress=0
				say("再多按一会儿：按住火漆约 1 秒后松开。")
		stage_drag=""
	changed()

func generate_seal() -> void:
	seal_points.clear()
	for i in 48:
		var angle := i*TAU/48
		var radius := randf_range(29,34)+sin(angle*3)*2
		seal_points.append(Vector2(cos(angle),sin(angle))*radius)

func send_letter() -> void:
	if stage != "SEND" or busy:
		return
	if letter_mode!="npc":
		await send_bottle()
		return
	audio.play("MAIL_DROP")
	await animate_property("mail_visual",1.0,0.8)
	final_feedback = "林舟：谢谢你。\n这封信像是留了一扇没有关上的门。"
	var ticket := false
	var photo := false
	for piece in pieces_root.get_children():
		if LETTER.has_point(piece.position):
			ticket = ticket or piece.source_id==3
			photo = photo or piece.source_id==4
	if ticket:
		final_feedback = "林舟：你把它放进去了……\n她应该会认出那张旧车票。"
	if photo:
		final_feedback += "\n对，就是那个公交站。"
	stage = "END"
	say("你的信件已保存。愿远处的人，在某个下午收到它。")
	changed()
	build_ui()

func restart() -> void:
	for piece in pieces_root.get_children():
		pieces_root.remove_child(piece)
		piece.queue_free()
	selected=null
	stage="DIALOGUE"
	letter_mode="npc"
	reply_parent={}
	bottle_request_id=""
	bottle_published_id=0
	dialogue=0
	fold=0
	envelope_inserted=false
	wax_step=0
	wax_progress=0
	stage_drag=""
	stamp_holding=false
	fold_visual=0
	flap_visual=0
	mail_visual=0
	insert_visual=0
	tool="move"
	pieces_root.visible=false
	say("一封新信，一次新的排列。")
	changed()
	build_ui()

func export_art() -> void:
	if not letter_preview:
		return
	var destination := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join("CollageLetter_"+Time.get_datetime_string_from_system().replace(":","-")+".png")
	var result := letter_preview.get_image().save_png(destination)
	say("作品已导出："+destination if result==OK else "导出失败，请检查图片文件夹权限。")

func changed() -> void:
	pieces_root.visible = stage=="WORKBENCH"
	queue_redraw()
	save_game()

func animate_property(property: String, target: float, duration: float, after: Callable = Callable()) -> void:
	busy=true
	var tween := create_tween()
	tween.tween_property(self,property,target,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	busy=false
	if after.is_valid():
		after.call()

func save_game(force: bool = false) -> void:
	if smoke and not force:
		return
	var all: Array = []
	for piece in pieces_root.get_children():
		all.append(piece.serialize())
	var points: Array = []
	for p in seal_points:
		points.append([p.x,p.y])
	var data := {"version":2,"letter_mode":letter_mode,"reply_parent":reply_parent,"letter_title":letter_title,"bottle_request_id":bottle_request_id,"bottle_published_id":bottle_published_id,"compose_server":compose_server,"category":category,"material_page":material_page,"album_source":album_source,"task":"summer_still_here","stage":stage,"dialogue":dialogue,"pieces":all,"fold":fold,"inserted":envelope_inserted,"wax_step":wax_step,"wax_progress":wax_progress,"seal_style":seal_style,"seal_points":points,"feedback":final_feedback,"muted":audio.muted,"photos":[{"id":"bus_stop_01","visible_text":["LAST","STOP"],"tags":["bus_stop","evening","public_sign"]}],"owned_sources":[0,1,2,3,4]}
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		var result := DirAccess.rename_absolute(save_path+".tmp",save_path)
		if result!=OK:
			say("本次保存失败，请检查存档目录是否可写。")

func load_game(force: bool = false) -> void:
	if not force and ("--smoke-test" in OS.get_cmdline_user_args() or "--network-test" in OS.get_cmdline_user_args() or "--fresh" in OS.get_cmdline_user_args()):
		return
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or int(data.get("version",0)) not in [1,2]:
		say("存档无法读取，已开始新的委托。")
		return
	for piece in pieces_root.get_children():
		pieces_root.remove_child(piece)
		piece.queue_free()
	selected=null
	seal_points.clear()
	letter_mode=data.get("letter_mode","npc")
	reply_parent=data.get("reply_parent",{})
	letter_title=data.get("letter_title","一封来自海边的信")
	bottle_request_id=data.get("bottle_request_id","")
	bottle_published_id=int(data.get("bottle_published_id",0))
	compose_server=data.get("compose_server","")
	category=data.get("category","全部")
	material_page=int(data.get("material_page",0))
	album_source=clampi(int(data.get("album_source",4)),0,materials.size()-1)
	stage = data.get("stage","DIALOGUE")
	if stage not in ["DIALOGUE","WORKBENCH","FOLDING","ENVELOPE","WAX_SEAL","SEND","END"]:
		stage="DIALOGUE"
	dialogue=clampi(int(data.get("dialogue",0)),0,2)
	fold=clampi(int(data.get("fold",0)),0,2)
	envelope_inserted=data.get("inserted",false)
	wax_step=clampi(int(data.get("wax_step",0)),0,6)
	wax_progress=float(data.get("wax_progress",0))
	if wax_step==5:
		wax_progress=0
	seal_style=clampi(int(data.get("seal_style",0)),0,2)
	final_feedback=data.get("feedback","")
	if data.get("muted",false)!=audio.muted:
		audio.toggle()
	for point in data.get("seal_points",[]):
		seal_points.append(Vector2(point[0],point[1]))
	if seal_points.size()<3:
		generate_seal()
	for record in data.get("pieces",[]):
		var piece := Piece.new()
		piece.source_id=int(record.get("source",0))
		piece.font=font
		if piece.source_id>=0 and piece.source_id<textures.size():
			piece.texture=textures[piece.source_id]
		for p in record.get("polygon",[]):
			piece.polygon.append(Vector2(p[0],p[1]))
		for p in record.get("uv",[]):
			piece.uv.append(Vector2(p[0],p[1]))
		if piece.polygon.size()<3:
			piece.free()
			continue
		piece.position=Vector2(record.position[0],record.position[1])
		piece.rotation=float(record.rotation)
		piece.scale=Vector2(record.scale[0],record.scale[1])
		piece.is_taped=record.get("taped",false)
		piece.handwriting=record.get("text","")
		pieces_root.add_child(piece)
	if not smoke and FileAccess.file_exists(preview_path):
		letter_preview=ImageTexture.create_from_image(Image.load_from_file(preview_path))
	pieces_root.visible=stage=="WORKBENCH"
	say("已恢复上次的信件。慢慢来，桌上的纸都还在。")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and ready_done:
		save_game()
		audio.shutdown()

func run_smoke_test() -> void:
	print("SMOKE: starting interactive flow")
	save_path="user://smoke_letter_v1.json"
	advance_dialogue(); advance_dialogue(); advance_dialogue()
	assert(stage=="WORKBENCH")
	tool="rect"
	cutting_source=0
	start=Vector2(80,271)
	finish_cut(Vector2(315,306))
	assert(pieces_root.get_child_count()==1)
	assert(selected.uv.size()==selected.polygon.size())
	selected.position=Vector2(700,390)
	selected.rotation=0.17
	selected.scale=Vector2(-0.8,0.8)
	save_game(true)
	load_game(true)
	assert(pieces_root.get_child_count()==1)
	assert(is_equal_approx(pieces_root.get_child(0).rotation,0.17))
	assert(pieces_root.get_child(0).scale.is_equal_approx(Vector2(-0.8,0.8)))
	print("SMOKE PASS: save/load retains polygon, UV, rotation, flip and scale")
	tool="free"
	cutting_source=4
	path=PackedVector2Array([Vector2(1180,319),Vector2(1260,316),Vector2(1310,357),Vector2(1285,391),Vector2(1180,392)])
	finish_cut(path[-1])
	assert(pieces_root.get_child_count()==2)
	tape_start=Vector2(640,390)
	finish_tape(Vector2(770,390))
	assert(pieces_root.get_child_count()==3)
	assert(pieces_root.get_child(0).is_taped)
	await capture_test("workbench")
	await complete_letter()
	assert(stage=="FOLDING")
	stage_input(Vector2(700,650),true); stage_input(Vector2(700,450),false)
	await get_tree().create_timer(0.55).timeout
	assert(fold==1)
	stage_input(Vector2(700,270),true); stage_input(Vector2(700,450),false)
	await get_tree().create_timer(0.55).timeout
	assert(fold==2)
	stage_input(Vector2(700,450),true); stage_input(Vector2(700,450),false)
	assert(stage=="ENVELOPE")
	save_game(true)
	load_game(true)
	assert(stage=="ENVELOPE" and fold==2)
	stage_input(stage_pos,true); stage_input(Vector2(700,470),false)
	await get_tree().create_timer(0.75).timeout
	assert(envelope_inserted)
	await close_envelope()
	wax_input(Vector2(160,630),true)
	assert(wax_step==1)
	wax_input(Vector2(310,570),true); wax_input(Vector2(328,371),false)
	assert(wax_step==2)
	wax_input(Vector2(328,371),true); wax_input(Vector2(160,420),false)
	_process(3.1)
	assert(wax_step==3)
	save_game(true)
	load_game(true)
	assert(wax_step==3 and envelope_inserted)
	wax_input(Vector2(328,371),true); wax_input(Vector2(720,474),false)
	await get_tree().create_timer(0.9).timeout
	assert(wax_step==4)
	wax_input(Vector2(1170,430),true); wax_input(Vector2(720,474),false)
	assert(wax_step==5)
	wax_input(Vector2(720,474),true); _process(1.1); wax_input(Vector2(720,474),false)
	assert(wax_step==6)
	_process(1.7)
	assert(stage=="SEND")
	await capture_test("seal")
	await send_letter()
	assert(stage=="END")
	assert("公交站" in final_feedback)
	await capture_test("ending")
	DirAccess.remove_absolute(save_path)
	print("SMOKE PASS: crop / free crop / tape / fold / envelope / wax / stamp / send")
	audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func capture_test(filename: String) -> void:
	var output := OS.get_environment("COLLAGE_TEST_OUTPUT")
	if output.is_empty():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(filename+".png"))

func material_ids() -> Array:
	var ids: Array=[]
	for i in materials.size():
		if materials[i].category not in ["影像","私人"] and (category=="全部" or materials[i].category==category):
			ids.append(i)
	return ids

func update_material_slots() -> void:
	var ids:=material_ids()
	if ids.is_empty():
		category="全部"
		ids=material_ids()
	var pages:=ceili(ids.size()/2.0)
	material_page=posmod(material_page,pages)
	primary=ids[material_page*2]
	secondary=ids[mini(material_page*2+1,ids.size()-1)]
	# Every category has at least two sheets, so both table slots remain independent.
	if secondary==primary:
		secondary=ids[0]
	sources[primary]=Rect2(62,190,300,240)
	sources[secondary]=Rect2(70,450,300,240)
	sources[album_source]=Rect2(1070,196,300,240)
	audio.play("PAPER_MOVE",0.5)
	queue_redraw()

func cycle_photo() -> void:
	var ids: Array=[]
	for i in materials.size():
		if materials[i].category=="影像":
			ids.append(i)
	album_source=ids[(ids.find(album_source)+1)%ids.size()]
	update_material_slots()
	changed()
	build_ui()

func open_bottles() -> void:
	if busy or dock_open:
		return
	dragging=false
	tape_drawing=false
	cutting_source=-1
	save_game()
	dock_open=true
	var dock:=BottleDock.new()
	dock.client=bottle
	dock.font=font
	add_child(dock)
	dock.compose_requested.connect(start_bottle)
	dock.closed.connect(func(): dock_open=false)
	dock.open()

func start_bottle(parent: Dictionary) -> void:
	# Keep the collage if the player brings the current open draft to the sea.
	if stage!="WORKBENCH":
		restart()
	letter_mode="bottle" if parent.is_empty() else "reply"
	reply_parent={"id":int(parent.get("id",0)),"title":parent.get("title","")} if not parent.is_empty() else {}
	compose_server=bottle.base_url
	letter_title="一封来自海边的信" if parent.is_empty() else ("回信："+str(parent.title)).left(40)
	bottle_request_id=""
	bottle_published_id=0
	stage="WORKBENCH"
	tool="move"
	pieces_root.visible=true
	say("写给还没有遇见的人。裁下、排列，准备好后折信寄出。" if parent.is_empty() else "正在回复 #"+str(parent.id)+" · "+str(parent.title))
	changed()
	build_ui()

func send_bottle() -> void:
	if not letter_preview:
		say("没有找到信件作品，请重新完成拼贴。")
		return
	if not compose_server.is_empty() and compose_server!=bottle.base_url:
		say("这封草稿属于另一个邮局，请重新连接原邮局后再寄出。")
		return
	if letter_title.strip_edges().is_empty():
		say("请先写一个信件标题。")
		return
	busy=true
	say("正在把信交给海岸邮局……")
	if bottle.player.is_empty():
		var connection: Dictionary=await bottle.connect_service(bottle.base_url,bottle.display_name)
		if not connection.ok:
			busy=false
			say(connection.get("error","连接失败，请重试。"))
			return
	if bottle_request_id.is_empty():
		bottle_request_id=Crypto.new().generate_random_bytes(16).hex_encode()
		save_game()
	if is_instance_valid(title_entry):
		title_entry.editable=false
	var art:=letter_preview.get_image()
	if art.get_width()>700 or art.get_height()>900:
		art.resize(530,582,Image.INTERPOLATE_LANCZOS)
	var payload: Dictionary={"request_id":bottle_request_id,"title":letter_title.strip_edges(),"caption":"","art_png":Marshalls.raw_to_base64(art.save_png_to_buffer())}
	payload["parent_id"]=int(reply_parent.id) if letter_mode=="reply" else null
	var result: Dictionary=await bottle.publish(payload)
	busy=false
	if not result.ok:
		say(result.get("error","寄出失败，信仍在这里，可以重试。"))
		build_ui()
		return
	bottle_published_id=int(result.letter_id)
	final_feedback="漂流瓶 #%d 已留在海上。\n下一步：读一封来信，给另一个人回信。" % bottle_published_id if letter_mode=="bottle" else "回信 #%d 已送到对方的信箱。\n你现在可以投出新的漂流瓶了。" % bottle_published_id
	# Persist the committed result before animation; a lost response can be retried with the same request id.
	stage="END"
	changed()
	audio.play("MAIL_DROP")
	say("信已寄出。后来的人仍然可以读到，并继续回复。")
	build_ui()

func run_network_test() -> void:
	save_path="user://network_test_draft.json"
	bottle.identity_path="user://network_test_identity_a.json"
	bottle.identities={}
	var url:=OS.get_environment("COLLAGE_TEST_URL")
	if url.is_empty():
		url="http://127.0.0.1:8789"
	var result: Dictionary=await bottle.connect_service(url,"测试寄信人甲")
	assert(result.ok)
	var other:=BottleClient.new()
	add_child(other)
	other.identity_path="user://network_test_identity_b.json"
	other.identities={}
	result=await other.connect_service(url,"测试寄信人乙")
	assert(result.ok)
	start_bottle({})
	category="自然"
	material_page=0
	update_material_slots()
	build_ui()
	tool="rect"
	cutting_source=primary
	start=sources[primary].position+Vector2(22,85)
	finish_cut(start+Vector2(235,38))
	assert(selected.source_id>=5)
	album_source=30
	update_material_slots()
	tool="rect"
	cutting_source=album_source
	start=sources[album_source].position+Vector2(20,20)
	finish_cut(start+Vector2(130,170))
	selected.position=Vector2(750,530)
	await capture_test("v2-workbench")
	await complete_letter()
	generate_seal()
	stage="SEND"
	await send_bottle()
	assert(stage=="END")
	assert(bottle.player.reply_required)
	var original:=bottle_published_id
	var second: Dictionary={"title":"不应发出","caption":"test","request_id":Crypto.new().generate_random_bytes(16).hex_encode()}
	result=await bottle.publish(second)
	assert(not result.ok)
	result=await other.publish({"title":"来自乙的回声","caption":"我听见了。","parent_id":original,"request_id":Crypto.new().generate_random_bytes(16).hex_encode()})
	assert(result.ok)
	result=await bottle.request("/v1/letters?view=inbox")
	assert(result.ok and result.letters.size()==1)
	var reply: Dictionary=result.letters[0]
	start_bottle(reply)
	save_game(true)
	load_game(true)
	assert(letter_mode=="reply" and int(reply_parent.id)==int(reply.id))
	tool="rect"
	cutting_source=primary
	start=sources[primary].position+Vector2(22,85)
	finish_cut(start+Vector2(230,40))
	await complete_letter()
	stage="SEND"
	await send_bottle()
	assert(stage=="END" and not bottle.player.reply_required)
	open_bottles()
	await get_tree().create_timer(1).timeout
	var dock: Node=get_child(get_child_count()-1)
	assert(dock is CanvasLayer)
	await dock.show_letter(original)
	await capture_test("v2-bottle-dock")
	print("NETWORK PASS: Godot A sends artwork / debt blocks send / B replies / A inbox / reply draft survives reload / A replies / debt clears / UI displays original artwork")
	for file in [save_path,bottle.identity_path,other.identity_path]:
		DirAccess.remove_absolute(file)
	audio.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
